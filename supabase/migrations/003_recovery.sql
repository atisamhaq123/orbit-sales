-- Stale worker cleanup and storage release. Server-only operations.
create function public.cleanup_candidates() returns table(id uuid,path text) language sql security definer set search_path='' as $$
 select v.id,v.path from public.document_versions v join public.documents d on d.id=v.document_id
 where d.deleted_at is not null or (v.id is distinct from d.active_version_id and v.version<d.version and not exists(select 1 from public.ingestion_jobs j where j.version_id=v.id and j.status in ('queued','processing','uploading'))) limit 50
$$;
create function public.confirm_cleanup(vid uuid) returns void language plpgsql security definer set search_path='' as $$declare v public.document_versions;d public.documents;begin
 select * into v from public.document_versions where id=vid for update;if v.id is null then return;end if;select * into d from public.documents where id=v.document_id for update;
 if d.deleted_at is null and (v.id=d.active_version_id or v.version>=d.version or exists(select 1 from public.ingestion_jobs where version_id=vid and status in ('queued','processing','uploading'))) then raise exception 'Version still in use';end if;
 delete from public.ingestion_jobs where version_id=vid;delete from public.document_versions where id=vid;
end$$;
create function public.recover_revoked_jobs() returns void language plpgsql security definer set search_path='' as $$begin
 update public.documents d set status='failed',error='Uploader access was revoked or subscription ended. An authorized member can retry after restoring access.' where d.deleted_at is null and d.id in(select j.document_id from public.ingestion_jobs j join public.workspaces w on w.id=j.workspace_id where j.status in ('queued','processing','uploading') and (not exists(select 1 from public.memberships m where m.workspace_id=j.workspace_id and m.user_id=j.requested_by) or w.subscription_status not in ('active','trialing') or w.period_end<=now()));
 update public.ingestion_jobs j set status='failed',lease_token=null,lease_until=null,error='Access or subscription revoked' from public.workspaces w where w.id=j.workspace_id and j.status in ('queued','processing','uploading') and (not exists(select 1 from public.memberships m where m.workspace_id=j.workspace_id and m.user_id=j.requested_by) or w.subscription_status not in ('active','trialing') or w.period_end<=now());
end$$;
revoke execute on function public.cleanup_candidates(),public.confirm_cleanup(uuid),public.recover_revoked_jobs() from public,anon,authenticated;
grant execute on function public.cleanup_candidates(),public.confirm_cleanup(uuid),public.recover_revoked_jobs() to service_role;
