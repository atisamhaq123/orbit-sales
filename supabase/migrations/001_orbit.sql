-- Orbit Sales only. Apply to a NEW Supabase project. No application email transport.
create extension if not exists pgcrypto with schema extensions;
create extension if not exists vector with schema extensions;
create table public.plan_limits (id text primary key, limits jsonb not null);
-- Generated from src/lib/plans.json; run scripts/check-plans.mjs to verify parity.
insert into public.plan_limits values ('starter','{"name":"Starter","price":19,"leads":250,"members":2,"ai":50,"documents":25,"storage":104857600}'),('pro','{"name":"Pro","price":49,"leads":2500,"members":5,"ai":300,"documents":250,"storage":1073741824}');
create table public.profiles (id uuid primary key references auth.users on delete cascade, name text not null, email text not null, timezone text not null default 'UTC');
create table public.workspaces (id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users, name text not null check(length(trim(name)) between 1 and 80), creation_key uuid not null, plan text references public.plan_limits, subscription_status text not null default 'inactive', stripe_customer_id text unique, stripe_subscription_id text unique, period_start timestamptz, period_end timestamptz, cancel_at_period_end boolean not null default false, billing_synced_at timestamptz, unique(owner_id,creation_key));
create table public.memberships(workspace_id uuid references public.workspaces on delete cascade,user_id uuid references auth.users on delete cascade, role text not null check(role in ('owner','member')),primary key(workspace_id,user_id));
create unique index one_owner on public.memberships(workspace_id) where role='owner';
create index on public.memberships(user_id);
create table public.leads(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces on delete cascade,name text not null check(length(trim(name)) between 1 and 120),company text not null default '' check(length(company)<=120),email text not null default '' check(length(email)<=254),phone text not null default '' check(length(phone)<=40),source text not null default '' check(length(source)<=100),stage text not null default 'New' check(stage in ('New','Qualified','Proposal','Negotiation','Won','Lost')),assignee_id uuid,value numeric(14,2) not null default 0 check(value>=0),notes text not null default '' check(length(notes)<=20000),archived boolean not null default false,version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(), unique(workspace_id,id),foreign key(workspace_id,assignee_id) references public.memberships(workspace_id,user_id));
create index on public.leads(workspace_id,archived,stage,created_at desc);
create table public.tasks(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces on delete cascade,lead_id uuid not null,title text not null check(length(trim(title)) between 1 and 200),assignee_id uuid,due_at timestamptz not null,priority text not null default 'Normal' check(priority in ('Low','Normal','High')),completed boolean not null default false,version integer not null default 1,foreign key(workspace_id,lead_id) references public.leads(workspace_id,id),foreign key(workspace_id,assignee_id) references public.memberships(workspace_id,user_id));
create index on public.tasks(workspace_id,completed,due_at);
create table public.activity(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces on delete cascade,lead_id uuid,actor_id uuid references auth.users,message text not null check(length(message)<=3000),created_at timestamptz not null default now(),foreign key(workspace_id,lead_id) references public.leads(workspace_id,id));
create index on public.activity(workspace_id,created_at desc);
create table public.invitations(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces on delete cascade,email text not null check(length(email)<=254 and email=lower(trim(email)) and email like '%@%'),token_hash text not null unique,status text not null default 'pending' check(status in ('pending','accepted','declined','revoked')),expires_at timestamptz not null default now()+interval '7 days',accepted_by uuid references auth.users,created_at timestamptz not null default now());
create unique index invitation_pending on public.invitations(workspace_id,email) where status='pending';
create table public.notifications(id uuid primary key default gen_random_uuid(),workspace_id uuid references public.workspaces on delete cascade,recipient_id uuid references auth.users,recipient_email text,invitation_id uuid references public.invitations on delete cascade,title text not null,body text not null,href text not null,read_at timestamptz,created_at timestamptz not null default now(),check((recipient_id is null)<>(recipient_email is null)),check(workspace_id is not null or invitation_id is not null));
create index on public.notifications(recipient_id,created_at desc);
create index on public.notifications(recipient_email);
create table public.documents(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces on delete cascade,title text not null check(length(title) between 1 and 255),size bigint not null check(size between 1 and 10485760),version integer not null default 1,status text not null default 'queued' check(status in ('queued','processing','ready','failed','deleted')),error text,uploader_id uuid not null references auth.users,active_version_id uuid,indexed_at timestamptz,deleted_at timestamptz,unique(workspace_id,id));
create index on public.documents(workspace_id,status);
create table public.document_versions(id uuid primary key default gen_random_uuid(),workspace_id uuid not null,document_id uuid not null,path text not null unique,size bigint not null check(size between 1 and 10485760),mime text not null check(mime in ('text/plain','application/pdf')),version integer not null,created_at timestamptz not null default now(),foreign key(workspace_id,document_id) references public.documents(workspace_id,id),unique(document_id,version),unique(workspace_id,id));
create table public.ingestion_jobs(id uuid primary key default gen_random_uuid(),workspace_id uuid not null,document_id uuid not null,version_id uuid not null unique,requested_by uuid not null references auth.users,status text not null default 'queued',attempts integer not null default 0,available_at timestamptz not null default now(),lease_until timestamptz,lease_token uuid,error text,foreign key(workspace_id,document_id) references public.documents(workspace_id,id),foreign key(workspace_id,version_id) references public.document_versions(workspace_id,id));
create index on public.ingestion_jobs(status,available_at,lease_until);
create table public.chunks(id uuid primary key default gen_random_uuid(),workspace_id uuid not null,document_id uuid not null,version_id uuid not null,ordinal integer not null,content text not null check(length(content)<=2000),location text not null,embedding extensions.vector(1536) not null,embedding_model text not null default 'text-embedding-3-small',search tsvector generated always as (to_tsvector('english',content)) stored,foreign key(workspace_id,document_id) references public.documents(workspace_id,id),foreign key(workspace_id,version_id) references public.document_versions(workspace_id,id) on delete cascade,unique(version_id,ordinal));
create index on public.chunks(workspace_id,document_id,version_id);
create index on public.chunks using gin(search);
create table public.conversations(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces on delete cascade,user_id uuid not null references auth.users,title text not null check(length(title)<=100),created_at timestamptz not null default now(),unique(workspace_id,id));
create table public.generations(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces on delete cascade,user_id uuid not null references auth.users,lead_id uuid,conversation_id uuid,operation text not null check(operation in ('draft','summary','next','answer')),question text not null default '',output text not null default '',citations jsonb not null default '[]',provider text not null default 'openai',model text not null,prompt_version text not null default 'orbit-v1',status text not null default 'reserved' check(status in ('reserved','succeeded','failed')),latency integer,usage jsonb,period_start timestamptz not null,expires_at timestamptz not null default now()+interval '2 minutes',created_at timestamptz not null default now(),foreign key(workspace_id,lead_id) references public.leads(workspace_id,id),foreign key(workspace_id,conversation_id) references public.conversations(workspace_id,id));
create index on public.generations(workspace_id,period_start,status);
create index on public.generations(user_id,conversation_id);
create table public.audit(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces on delete cascade,actor_id uuid,event text not null,created_at timestamptz not null default now());
create table public.stripe_events(id text primary key,created_at timestamptz not null default now());
create table public.rate_limits(key text primary key,bucket timestamptz not null,count integer not null);

create function public.member_of(w uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.memberships where workspace_id=w and user_id=auth.uid())$$;
create function public.owner_of(w uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.workspaces where id=w and owner_id=auth.uid())$$;
create function public.identity_email() returns text language sql stable security definer set search_path='' as $$select lower(email) from auth.users where id=auth.uid() and email_confirmed_at is not null and (raw_app_meta_data->>'provider'='google' or raw_app_meta_data->'providers' ? 'google')$$;
create function public.source_visible(w uuid, refs jsonb) returns boolean language sql stable security definer set search_path='' as $$select public.member_of(w) and not exists(select 1 from jsonb_array_elements(refs) ref where not exists(select 1 from public.documents d where d.id=(ref->>'document_id')::uuid and d.workspace_id=w and d.deleted_at is null and d.active_version_id::text=ref->>'version_id'))$$;
do $$declare t text;begin
 foreach t in array array['profiles','workspaces','memberships','leads','tasks','activity','invitations','notifications','documents','document_versions','ingestion_jobs','chunks','conversations','generations','audit','stripe_events','rate_limits','plan_limits'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from anon,authenticated',t);execute format('grant all on public.%I to service_role',t);end loop;
 foreach t in array array['leads','tasks','activity','documents','document_versions','chunks'] loop execute format('create policy member_read on public.%I for select to authenticated using(public.member_of(workspace_id))',t);execute format('grant select on public.%I to authenticated',t);end loop;
end$$;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid() or exists(select 1 from public.memberships m where m.user_id=profiles.id and public.member_of(m.workspace_id)));
create policy workspaces_read on public.workspaces for select to authenticated using(public.member_of(id));
create policy memberships_read on public.memberships for select to authenticated using(public.member_of(workspace_id));
create policy invitations_read on public.invitations for select to authenticated using(public.owner_of(workspace_id) or email=public.identity_email());
create policy notifications_read on public.notifications for select to authenticated using((recipient_id=auth.uid() or recipient_email=public.identity_email()) and (workspace_id is null or public.member_of(workspace_id)));
create policy notifications_update on public.notifications for update to authenticated using((recipient_id=auth.uid() or recipient_email=public.identity_email()) and (workspace_id is null or public.member_of(workspace_id))) with check((recipient_id=auth.uid() or recipient_email=public.identity_email()) and (workspace_id is null or public.member_of(workspace_id)));
create policy conversation_read on public.conversations for select to authenticated using(user_id=auth.uid() and public.member_of(workspace_id));
create policy generation_read on public.generations for select to authenticated using(user_id=auth.uid() and public.source_visible(workspace_id,citations));
grant select on public.profiles,public.workspaces,public.memberships,public.invitations,public.notifications,public.conversations,public.generations,public.plan_limits to authenticated;
grant update(read_at) on public.notifications to authenticated;
create policy plans_read on public.plan_limits for select to authenticated using(true);

create function public.require_paid(w uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare r public.workspaces; l jsonb;begin
 select * into r from public.workspaces where id=w for update;
 if not public.member_of(w) then raise exception 'Workspace access denied';end if;
 if r.subscription_status not in ('active','trialing') or r.period_end is null or r.period_end<=now() then raise exception 'An active subscription is required. Open Plans & billing.';end if;
 select limits into l from public.plan_limits where id=r.plan;if l is null then raise exception 'Plan is unavailable';end if;return l;
end$$;
create function public.throttle(k text, maximum integer) returns void language plpgsql security definer set search_path='' as $$declare hits integer;begin
 insert into public.rate_limits values(k,date_trunc('minute',now()),1) on conflict(key) do update set bucket=excluded.bucket,count=case when rate_limits.bucket=excluded.bucket then rate_limits.count+1 else 1 end returning count into hits;
 if hits>maximum then raise exception 'Too many requests. Try again in a minute.';end if;
end$$;

-- All browser writes go through this bounded, authenticated transaction.
create function public.mutate(m jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a text:=m->>'action'; w uuid:=nullif(m->>'workspace','')::uuid; target uuid:=coalesce(nullif(m->>'id','')::uuid,gen_random_uuid()); uid uuid:=auth.uid(); v_email text:=public.identity_email(); f jsonb:=m->'fields'; lim jsonb; l public.leads; t public.tasks; inv public.invitations; doc public.documents; raw text; ver integer; c integer; result jsonb:='{}';
begin
 if uid is null or v_email is null then raise exception 'Sign in with a verified Google account';end if;
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
   if inv.email is distinct from v_email then raise exception 'This invitation belongs to another Google account';end if;
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

-- Upload metadata and storage reservation are committed together, before the server uploads bytes.
create function public.reserve_upload(w uuid, title text, bytes bigint, mime text, replace_id uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$declare lim jsonb;d public.documents;vid uuid:=gen_random_uuid();n integer;used bigint;begin
 lim:=public.require_paid(w);perform public.throttle('upload:'||auth.uid(),8);
 if bytes<1 or bytes>10485760 then raise exception 'Maximum file size is 10 MB';end if;
 select coalesce(sum(v.size),0) into used from public.document_versions v where v.workspace_id=w;
 if used+bytes>(lim->>'storage')::bigint then raise exception 'Knowledge storage limit reached. Cleanup old versions first.';end if;
 if replace_id is null then
   select count(*) into n from public.documents where workspace_id=w and deleted_at is null;if n>=(lim->>'documents')::int then raise exception 'Document limit reached';end if;
   insert into public.documents(workspace_id,title,size,uploader_id) values(w,title,bytes,auth.uid()) returning * into d;
 else
   select * into d from public.documents where id=replace_id and workspace_id=w for update;
   if d.id is null or d.deleted_at is not null or (d.uploader_id<>auth.uid() and not public.owner_of(w)) then raise exception 'Document access denied';end if;
   if d.status in ('queued','processing') then raise exception 'Wait for current ingestion before replacing';end if;
   update public.documents set version=version+1,title=reserve_upload.title,size=bytes,status='queued',error=null where id=d.id returning * into d;
 end if;
 insert into public.document_versions(id,workspace_id,document_id,path,size,mime,version) values(vid,w,d.id,w||'/'||d.id||'/'||vid,bytes,mime,d.version);
 insert into public.ingestion_jobs(workspace_id,document_id,version_id,requested_by,status) values(w,d.id,vid,auth.uid(),'uploading');
 return jsonb_build_object('document',d.id,'version',vid,'path',w||'/'||d.id||'/'||vid);
end$$;

-- Both ranking lists are scoped BEFORE ranking/limit. RRF k=60. Exact vector scan is deliberate for small MVP corpora.
create function public.hybrid_search(w uuid,query text,vector extensions.vector(1536)) returns table(id uuid,document_id uuid,version_id uuid,title text,location text,content text,score double precision) language sql stable security definer set search_path='' as $$
 with visible as materialized(select c.*,d.title from public.chunks c join public.documents d on d.id=c.document_id and d.workspace_id=c.workspace_id and d.active_version_id=c.version_id where c.workspace_id=w and public.member_of(w) and d.deleted_at is null),
 semantic as(select v.id,row_number() over(order by v.embedding OPERATOR(extensions.<=>) vector) r from visible v where 1-(v.embedding OPERATOR(extensions.<=>) vector)>0.22 order by v.embedding OPERATOR(extensions.<=>) vector limit 20),
 lexical as(select v.id,row_number() over(order by ts_rank_cd(v.search,websearch_to_tsquery('english',query)) desc) r from visible v where v.search@@websearch_to_tsquery('english',query) order by ts_rank_cd(v.search,websearch_to_tsquery('english',query)) desc limit 20),
 ranked as(select x.id,sum(1.0/(60+x.r))::float8 score from(select * from semantic union all select * from lexical)x group by x.id)
 select v.id,v.document_id,v.version_id,v.title,v.location,v.content,r.score from ranked r join visible v on v.id=r.id order by r.score desc limit 8
$$;

create function public.reserve_ai(w uuid,request_id uuid,operation text,model text,lead uuid default null,conversation uuid default null,question text default '') returns jsonb language plpgsql security definer set search_path='' as $$declare lim jsonb;start_at timestamptz;g public.generations;n integer;begin
 lim:=public.require_paid(w);perform public.throttle('ai:'||auth.uid(),12);
 update public.generations set status='failed' where workspace_id=w and status='reserved' and expires_at<now();
 select * into g from public.generations where id=request_id;
 if g.id is not null then if g.user_id<>auth.uid() or g.workspace_id<>w or not public.source_visible(w,g.citations) then raise exception 'Request unavailable or source access revoked';end if;return to_jsonb(g)||jsonb_build_object('new_reservation',false);end if;
 if conversation is not null and not exists(select 1 from public.conversations where id=conversation and workspace_id=w and user_id=auth.uid()) then raise exception 'Conversation access denied';end if;
 select period_start into start_at from public.workspaces where id=w;
 select count(*) into n from public.generations where workspace_id=w and period_start=start_at and status in ('reserved','succeeded');if n>=(lim->>'ai')::int then raise exception 'Monthly AI allowance reached';end if;
 insert into public.generations(id,workspace_id,user_id,operation,model,lead_id,conversation_id,question,period_start) values(request_id,w,auth.uid(),operation,model,lead,conversation,left(question,4000),start_at) returning * into g;return to_jsonb(g)||jsonb_build_object('new_reservation',true);
end$$;
create function public.settle_ai(request_id uuid,success boolean,answer text default '',refs jsonb default '[]',elapsed integer default null,usage jsonb default null) returns void language plpgsql security definer set search_path='' as $$declare g public.generations;begin
 select * into g from public.generations where id=request_id for update;
 if g.user_id is distinct from auth.uid() then raise exception 'Generation access denied';end if;
 if g.status<>'reserved' then return;end if;
 if not public.member_of(g.workspace_id) or not public.source_visible(g.workspace_id,refs) or g.expires_at<now() then success:=false;end if;
 if exists(select 1 from jsonb_array_elements(refs) r where not exists(select 1 from public.chunks c where c.id=(r->>'id')::uuid and c.workspace_id=g.workspace_id and c.document_id=(r->>'document_id')::uuid and c.version_id=(r->>'version_id')::uuid)) then success:=false;end if;
 if success and (length(answer)>16000 or jsonb_array_length(refs)>8) then raise exception 'AI output too large';end if;
 update public.generations set status=case when success then 'succeeded' else 'failed' end,output=case when success then answer else '' end,citations=case when success then refs else '[]' end,latency=elapsed,usage=settle_ai.usage where id=request_id;
end$$;

-- Leased queue: token fencing prevents a stale worker from publishing after interruption.
create function public.claim_ingestion() returns jsonb language plpgsql security definer set search_path='' as $$declare j public.ingestion_jobs;v public.document_versions;begin
 update public.generations set status='failed' where status='reserved' and expires_at<now();
 update public.documents d set status='failed',error='Upload interrupted. Replace this file to retry.' where d.id in(select document_id from public.ingestion_jobs where status='uploading' and available_at<now()-interval '10 minutes');
 update public.ingestion_jobs set status='failed',error='Upload interrupted' where status='uploading' and available_at<now()-interval '10 minutes';
 update public.documents d set status='failed',error='Worker interrupted after maximum attempts. Retry ingestion.' where d.id in(select document_id from public.ingestion_jobs where status='processing' and lease_until<now() and attempts>=3);
 update public.ingestion_jobs set status='failed',lease_token=null,error='Worker interrupted after maximum attempts' where status='processing' and lease_until<now() and attempts>=3;
 select q.* into j from public.ingestion_jobs q join public.documents d on d.id=q.document_id join public.memberships m on m.workspace_id=q.workspace_id and m.user_id=q.requested_by join public.workspaces w on w.id=q.workspace_id where d.deleted_at is null and w.subscription_status in ('active','trialing') and w.period_end>now() and q.attempts<3 and ((q.status='queued' and q.available_at<=now()) or(q.status='processing' and q.lease_until<now())) order by q.available_at for update of q skip locked limit 1;
 if j.id is null then return null;end if;
 update public.ingestion_jobs set status='processing',attempts=attempts+1,lease_token=gen_random_uuid(),lease_until=now()+interval '5 minutes' where id=j.id returning * into j;
 update public.documents set status='processing' where id=j.document_id;
 select * into v from public.document_versions where id=j.version_id;
 return to_jsonb(j)||jsonb_build_object('path',v.path,'mime',v.mime);
end$$;
create function public.finish_ingestion(job uuid,token uuid,pieces jsonb,problem text default null) returns void language plpgsql security definer set search_path='' as $$declare j public.ingestion_jobs;d public.documents;p jsonb;begin
 select * into j from public.ingestion_jobs where id=job and lease_token=token and status='processing' and lease_until>now() for update;
 if j.id is null then raise exception 'Job lease expired';end if;
 select * into d from public.documents where id=j.document_id for update;
 if d.deleted_at is not null or not exists(select 1 from public.memberships where workspace_id=j.workspace_id and user_id=j.requested_by) or not exists(select 1 from public.workspaces where id=j.workspace_id and subscription_status in ('active','trialing') and period_end>now()) or (select version from public.document_versions where id=j.version_id)<>d.version then update public.ingestion_jobs set status='cancelled',lease_token=null where id=job;return;end if;
 if problem is not null then
   update public.ingestion_jobs set status=case when attempts<3 then 'queued' else 'failed' end,error=left(problem,300),available_at=now()+make_interval(secs=>30*j.attempts),lease_token=null,lease_until=null where id=job;
   update public.documents set status=case when j.attempts<3 then 'queued' else 'failed' end,error=left(problem,300) where id=d.id;
 else
   if jsonb_array_length(pieces) not between 1 and 400 then raise exception 'Invalid chunk count';end if;
   delete from public.chunks where version_id=j.version_id;
   for p in select * from jsonb_array_elements(pieces) loop
     insert into public.chunks(workspace_id,document_id,version_id,ordinal,content,location,embedding) values(j.workspace_id,j.document_id,j.version_id,(p->>'ordinal')::integer,p->>'content',p->>'location',(p->>'embedding')::extensions.vector(1536));
   end loop;
   update public.documents set status='ready',active_version_id=j.version_id,indexed_at=now(),error=null where id=d.id;
   update public.ingestion_jobs set status='ready',lease_token=null,lease_until=null,error=null where id=job;
 end if;
 if problem is null or j.attempts>=3 then insert into public.notifications(workspace_id,recipient_id,title,body,href) values(j.workspace_id,j.requested_by,case when problem is null then 'Knowledge indexed' else 'Ingestion failed' end,d.title,'/knowledge');end if;
end$$;

-- Stripe reconciliation is server-only and guarded by a short distributed lease.
create table public.billing_locks(workspace_id uuid primary key references public.workspaces on delete cascade,token uuid not null,expires_at timestamptz not null);
alter table public.billing_locks enable row level security;
revoke all on public.billing_locks from anon,authenticated;
grant all on public.billing_locks to service_role;
create function public.billing_lease(w uuid,token uuid) returns boolean language plpgsql security definer set search_path='' as $$declare n integer;begin insert into public.billing_locks values(w,token,now()+interval '90 seconds') on conflict(workspace_id) do update set token=excluded.token,expires_at=excluded.expires_at where billing_locks.expires_at<now();get diagnostics n=row_count;return n=1;end$$;
create function public.sync_billing(w uuid,token uuid,event text,customer text,subscription text,new_plan text,new_status text,start_at timestamptz,end_at timestamptz,cancel_pending boolean) returns void language plpgsql security definer set search_path='' as $$declare ws public.workspaces;begin
 perform 1 from public.billing_locks where workspace_id=w and billing_locks.token=sync_billing.token and expires_at>now() for update;if not found then raise exception 'Billing lease expired';end if;
 select * into ws from public.workspaces where id=w for update;
 if ws.stripe_customer_id is distinct from customer then raise exception 'Stripe customer mapping mismatch';end if;
 if exists(select 1 from public.stripe_events where id=event) then return;end if;
 if ws.period_start is not null and start_at<ws.period_start then raise exception 'Stale billing period';end if;
 -- Preserve the accounting period across within-cycle plan changes.
 update public.workspaces set stripe_subscription_id=subscription,plan=new_plan,subscription_status=new_status,period_start=start_at,period_end=end_at,cancel_at_period_end=cancel_pending,billing_synced_at=now() where id=w;
 insert into public.stripe_events values(event,now());insert into public.audit(workspace_id,event) values(w,'billing.reconciled');
end$$;

-- Private originals: clients never receive storage write permissions.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('orbit-knowledge','orbit-knowledge',false,10485760,array['text/plain','application/pdf']) on conflict(id) do nothing;
create policy orbit_original_read on storage.objects for select to authenticated using(bucket_id='orbit-knowledge' and exists(select 1 from public.document_versions v join public.documents d on d.id=v.document_id where v.path=storage.objects.name and d.deleted_at is null and public.member_of(d.workspace_id)));
alter publication supabase_realtime add table public.notifications;

-- Default deny for new functions; explicitly expose only identity-checked entry points.
revoke execute on all functions in schema public from public,anon,authenticated;
grant execute on function public.member_of(uuid),public.owner_of(uuid),public.identity_email(),public.source_visible(uuid,jsonb),public.mutate(jsonb),public.reserve_upload(uuid,text,bigint,text,uuid),public.hybrid_search(uuid,text,extensions.vector),public.reserve_ai(uuid,uuid,text,text,uuid,uuid,text),public.settle_ai(uuid,boolean,text,jsonb,integer,jsonb) to authenticated;
grant execute on all functions in schema public to service_role;
