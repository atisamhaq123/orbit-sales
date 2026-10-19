-- Revoke raw deleted/superseded evidence even if a client bypasses the application API.
drop policy member_read on public.chunks;
create policy chunks_read on public.chunks for select to authenticated using(public.member_of(workspace_id) and exists(select 1 from public.documents d where d.id=chunks.document_id and d.workspace_id=chunks.workspace_id and d.deleted_at is null and d.active_version_id=chunks.version_id));
drop policy member_read on public.document_versions;
create policy version_read on public.document_versions for select to authenticated using(public.member_of(workspace_id) and exists(select 1 from public.documents d where d.id=document_versions.document_id and d.deleted_at is null));
create function public.workspace_usage(w uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare start_at timestamptz;n integer;bytes bigint;begin
 if not public.member_of(w) then raise exception 'Workspace access denied';end if;
 select period_start into start_at from public.workspaces where id=w;
 select count(*) into n from public.generations where workspace_id=w and period_start=start_at and (status='succeeded' or status='reserved' and expires_at>now());
 select coalesce(sum(size),0) into bytes from public.document_versions where workspace_id=w;
 return jsonb_build_object('ai',n,'storage',bytes);
end$$;
revoke execute on function public.workspace_usage(uuid) from public,anon;
grant execute on function public.workspace_usage(uuid) to authenticated,service_role;
