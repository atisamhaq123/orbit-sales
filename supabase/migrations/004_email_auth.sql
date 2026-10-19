-- Accept verified email accounts while retaining existing workspace permissions.
create or replace function public.identity_email() returns text language sql stable security definer set search_path='' as $$select lower(email) from auth.users where id=auth.uid() and email_confirmed_at is not null$$;

create or replace function public.mutate(m jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a text:=m->>'action'; w uuid:=nullif(m->>'workspace','')::uuid; target uuid:=coalesce(nullif(m->>'id','')::uuid,gen_random_uuid()); uid uuid:=auth.uid(); v_email text:=public.identity_email(); f jsonb:=m->'fields'; lim jsonb; l public.leads; t public.tasks; inv public.invitations; doc public.documents; raw text; ver integer; c integer; result jsonb:='{}';
begin
 if uid is null or v_email is null then raise exception 'Sign in with a verified email account';end if;
 perform public.throttle('mutation:'||uid,90);
 insert into public.profiles(id,name,email) select uid,left(coalesce(raw_user_meta_data->>'full_name','Team member'),100),v_email from auth.users where id=uid on conflict(id) do update set email=excluded.email;
 if a='profile.sync' then return result;end if;
 if a='profile.save' then
   if not exists(select 1 from pg_timezone_names where name=m->>'timezone') then raise exception 'Choose a valid timezone';end if;
   update public.profiles set timezone=m->>'timezone' where id=uid;return result;
 end if;
 if a='workspace.create' then
   perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
   insert into public.workspaces(owner_id,name,creation_key) values(uid,m->>'name',(m->>'creation_key')::uuid) on conflict(owner_id,creation_key) do update set name=workspaces.name returning id into w;
   insert into public.memberships values(w,uid,'owner') on conflict do nothing;return jsonb_build_object('workspace',w);
 end if;
 if a in ('invitation.accept','invitation.decline') then
   select * into inv from public.invitations where id=target for update;
   if inv.email is distinct from v_email then raise exception 'This invitation belongs to another email account';end if;
   if inv.status='accepted' and inv.accepted_by=uid then return jsonb_build_object('workspace',inv.workspace_id);end if;
   if inv.status<>'pending' or inv.expires_at<=now() then raise exception 'Invitation expired, used or revoked';end if;
   if m ? 'token' and inv.token_hash<>encode(extensions.digest(m->>'token','sha256'),'hex') then raise exception 'Invalid invitation link';end if;
   if a='invitation.decline' then update public.invitations set status='declined' where id=target;return result;end if;
   -- Serialize seat consumption; accepting does not require the invitee to own a subscription.
   select limits into lim from public.plan_limits p join public.workspaces ws on ws.plan=p.id where ws.id=inv.workspace_id and ws.subscription_status in ('active','trialing') and ws.period_end>now() for update of ws;
   if lim is null then raise exception 'The workspace owner needs an active subscription';end if;
   if not exists(select 1 from public.memberships where workspace_id=inv.workspace_id and user_id=uid) then
     select count(*) into c from public.memberships where workspace_id=inv.workspace_id;if c>=(lim->>'members')::int then raise exception 'Workspace seat limit reached';end if;
     insert into public.memberships values(inv.workspace_id,uid,'member');
   end if;
   update public.invitations set status='accepted',accepted_by=uid where id=target;
   insert into public.audit(workspace_id,actor_id,event) values(inv.workspace_id,uid,'invitation.accepted');return jsonb_build_object('workspace',inv.workspace_id);
 end if;
 if a='notification.read' then update public.notifications set read_at=case when (m->>'unread')::boolean then null else now() end where (id=target or coalesce((m->>'all')::boolean,false)) and (recipient_id=uid or recipient_email=v_email) and (workspace_id is null or public.member_of(workspace_id));return result;end if;
 if not public.member_of(w) then raise exception 'Workspace access denied';end if;
 -- Lock workspace before all quota-sensitive writes and membership changes.
 perform 1 from public.workspaces where id=w for update;
 if a in ('workspace.save','member.remove','member.leave','invitation.create','invitation.rotate','invitation.revoke') then
   if a<>'member.leave' and not public.owner_of(w) then raise exception 'Only the workspace owner can manage team settings';end if;
   if a='workspace.save' then update public.workspaces set name=m->>'name' where id=w;
   elsif a in ('member.remove','member.leave') then
     if a='member.leave' then target:=uid;end if;
     if exists(select 1 from public.workspaces where id=w and owner_id=target) then raise exception 'Owners cannot leave or remove themselves. Workspace deletion is deferred.';end if;
     update public.leads set assignee_id=null,version=version+1,updated_at=now() where workspace_id=w and assignee_id=target;
     update public.tasks set assignee_id=null,version=version+1 where workspace_id=w and assignee_id=target;
     delete from public.memberships where workspace_id=w and user_id=target;
   elsif a='invitation.revoke' then update public.invitations set status='revoked' where id=target and workspace_id=w and status='pending';
   else
     lim:=public.require_paid(w);perform public.throttle('invite:'||uid,10);raw:=encode(extensions.gen_random_bytes(32),'hex');
     if a='invitation.create' then
       if exists(select 1 from public.memberships mm join public.profiles p on p.id=mm.user_id where mm.workspace_id=w and p.email=lower(trim(m->>'email'))) then raise exception 'This person is already a member';end if;
       insert into public.invitations(id,workspace_id,email,token_hash) values(target,w,lower(trim(m->>'email')),encode(extensions.digest(raw,'sha256'),'hex'));
       insert into public.notifications(recipient_email,invitation_id,title,body,href) values(lower(trim(m->>'email')),target,'Workspace invitation','You have a pending workspace invitation.','/notifications');
     else
       update public.invitations set token_hash=encode(extensions.digest(raw,'sha256'),'hex'),expires_at=now()+interval '7 days' where id=target and workspace_id=w and status='pending';if not found then raise exception 'Invitation unavailable';end if;
     end if;
     result:=jsonb_build_object('id',target,'token',raw);
   end if;
   insert into public.audit(workspace_id,actor_id,event) values(w,uid,a);return result;
 end if;
 if a='lead.save' then
   select * into l from public.leads where id=target and workspace_id=w for update;
   if l.id is not null and l.version is distinct from (m->>'version')::int then raise exception 'Conflict: lead changed. Refresh before saving.';end if;
   if l.id is not null and coalesce((f->>'archived')::boolean,false) and (select subscription_status not in ('active','trialing') or period_end is null or period_end<=now() from public.workspaces where id=w) and (f - 'archived' - 'id' - 'workspace_id' - 'version' - 'created_at' - 'updated_at') is distinct from (to_jsonb(l) - 'archived' - 'id' - 'workspace_id' - 'version' - 'created_at' - 'updated_at') then raise exception 'An inactive workspace can only archive existing leads without other edits';end if;
   if l.id is null or not coalesce((f->>'archived')::boolean,false) then lim:=public.require_paid(w);end if;
   if l.id is null or (l.archived and not coalesce((f->>'archived')::boolean,false)) then select count(*) into c from public.leads where workspace_id=w and not archived;if c>=(lim->>'leads')::int then raise exception 'Active lead limit reached';end if;end if;
   insert into public.leads(id,workspace_id,name,company,email,phone,source,stage,assignee_id,value,notes,archived)
   values(target,w,f->>'name',coalesce(f->>'company',''),coalesce(f->>'email',''),coalesce(f->>'phone',''),coalesce(f->>'source',''),coalesce(f->>'stage','New'),nullif(f->>'assignee_id','')::uuid,coalesce((f->>'value')::numeric,0),coalesce(f->>'notes',''),coalesce((f->>'archived')::boolean,false))
   on conflict(id) do update set name=excluded.name,company=excluded.company,email=excluded.email,phone=excluded.phone,source=excluded.source,stage=excluded.stage,assignee_id=excluded.assignee_id,value=excluded.value,notes=excluded.notes,archived=excluded.archived,version=leads.version+1,updated_at=now() where leads.workspace_id=w;
   insert into public.activity(workspace_id,lead_id,actor_id,message) values(w,target,uid,case when l.id is null then 'Created lead' else 'Updated lead · stage: '||coalesce(f->>'stage',l.stage)||' · assignment, notes and details saved' end);
   if nullif(f->>'assignee_id','')::uuid is distinct from l.assignee_id and nullif(f->>'assignee_id','') is not null then insert into public.notifications(workspace_id,recipient_id,title,body,href) values(w,(f->>'assignee_id')::uuid,'Lead assigned to you',f->>'name','/leads/'||target);end if;
 elsif a='task.save' then
   lim:=public.require_paid(w);select * into t from public.tasks where id=target and workspace_id=w for update;
   if t.id is not null and t.version is distinct from (m->>'version')::int then raise exception 'Conflict: task changed. Refresh before saving.';end if;
   insert into public.tasks(id,workspace_id,lead_id,title,assignee_id,due_at,priority,completed) values(target,w,(f->>'lead_id')::uuid,f->>'title',nullif(f->>'assignee_id','')::uuid,(f->>'due_at')::timestamptz,coalesce(f->>'priority','Normal'),coalesce((f->>'completed')::boolean,false)) on conflict(id) do update set title=excluded.title,lead_id=excluded.lead_id,assignee_id=excluded.assignee_id,due_at=excluded.due_at,priority=excluded.priority,completed=excluded.completed,version=tasks.version+1 where tasks.workspace_id=w;
   insert into public.activity(workspace_id,lead_id,actor_id,message) values(w,(f->>'lead_id')::uuid,uid,case when (f->>'completed')::boolean then 'Completed follow-up: ' else 'Saved follow-up: ' end ||(f->>'title'));
   if nullif(f->>'assignee_id','') is not null and nullif(f->>'assignee_id','')::uuid is distinct from t.assignee_id then insert into public.notifications(workspace_id,recipient_id,title,body,href) values(w,(f->>'assignee_id')::uuid,'Follow-up assigned to you',f->>'title','/follow-ups');end if;
 elsif a='task.delete' then delete from public.tasks where id=target and workspace_id=w;
 elsif a='note' then
   lim:=public.require_paid(w);insert into public.activity(workspace_id,lead_id,actor_id,message) values(w,(m->>'lead_id')::uuid,uid,m->>'message');
 elsif a='conversation.create' then lim:=public.require_paid(w);insert into public.conversations(id,workspace_id,user_id,title) values(target,w,uid,left(m->>'title',100));result:=jsonb_build_object('id',target);
 elsif a='draft.save' then lim:=public.require_paid(w);if length(m->>'output')>16000 then raise exception 'Draft too long';end if;update public.generations set output=m->>'output' where id=target and workspace_id=w and user_id=uid and operation='draft' and public.source_visible(w,citations);
 elsif a in ('document.delete','document.retry') then
   select * into doc from public.documents where id=target and workspace_id=w for update;
   if doc.id is null or (not public.owner_of(w) and doc.uploader_id<>uid) then raise exception 'Only the owner or uploader can change this document';end if;
   if a='document.delete' then update public.documents set deleted_at=now(),status='deleted' where id=target;update public.ingestion_jobs set status='cancelled',lease_token=null where document_id=target;insert into public.audit(workspace_id,actor_id,event) values(w,uid,'document.deleted');
   else lim:=public.require_paid(w);perform public.throttle('reindex:'||uid,5);if doc.status<>'failed' or doc.deleted_at is not null then raise exception 'Only failed documents can be retried';end if;update public.ingestion_jobs set status='queued',attempts=0,error=null,available_at=now(),lease_until=null,lease_token=null where document_id=target and version_id=(select id from public.document_versions where document_id=target order by version desc limit 1);update public.documents set status='queued',error=null where id=target;end if;
 else raise exception 'Unsupported action';end if;
 if a='document.retry' then update public.ingestion_jobs set requested_by=uid where document_id=target and status='queued';end if;
 return result;
end$$;
