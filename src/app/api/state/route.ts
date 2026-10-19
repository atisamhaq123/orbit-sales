import {identity,check,failure,AppError} from '@/lib/server';
export const dynamic='force-dynamic';
export async function GET(request:Request){try{
 const {client,user}=await identity();check(await client.rpc('mutate',{m:{action:'profile.sync'}}));
 const membership=check(await client.from('memberships').select('workspace_id,role'))||[];
 const workspaces=(check(await client.from('workspaces').select('*'))||[]).map(w=>({...w,role:membership.find(m=>m.workspace_id===w.id)?.role}));
 const selected=new URL(request.url).searchParams.get('workspace');const workspace=selected?workspaces.find(w=>w.id===selected):workspaces[0];
 if(selected&&!workspace)throw new AppError('Workspace access denied. Your membership may have changed.',403);
 const profile=check(await client.from('profiles').select('*').eq('id',user.id).single());
 const notifications=check(await client.from('notifications').select('*').order('created_at',{ascending:false}).limit(100))||[];
 const invitations=check(await client.from('invitations').select('id,workspace_id,email,status,expires_at').order('created_at',{ascending:false}).limit(100))||[];
 const base={user:{id:user.id,email:user.email,name:profile?.name||user.user_metadata.full_name||'Team member',timezone:profile?.timezone||'UTC'},workspace:workspace||null,workspaces,notifications,invitations,members:[],leads:[],tasks:[],documents:[],generations:[],activity:[],conversations:[],ai_used:0,storage_used:0};
 if(!workspace)return Response.json(base,{headers:{'Cache-Control':'no-store'}});
 async function all(table:string,columns='*'){let result:Record<string,unknown>[]=[];for(let page=0;page<25;page++){const rows=check(await client.from(table).select(columns).eq('workspace_id',workspace!.id).order('id').range(page*500,page*500+499))||[];result=result.concat(rows as unknown as Record<string,unknown>[]);if(rows.length<500)break;}return result;}
 const [leads,tasks,documents,activity,conversations,generations,members,versions]=await Promise.all([all('leads'),all('tasks'),all('documents'),client.from('activity').select('*').eq('workspace_id',workspace.id).order('created_at',{ascending:false}).limit(200).then(check),all('conversations'),client.from('generations').select('*').eq('workspace_id',workspace.id).eq('status','succeeded').order('created_at',{ascending:false}).limit(100).then(check),all('memberships'),all('document_versions','id,size')]);
 const profiles=check(await client.from('profiles').select('*').in('id',members.map(m=>String(m.user_id))))||[];
 // Usage is a workspace aggregate exposed through an identity-checked RPC (private operations stay private).
 const usage=check(await client.rpc('workspace_usage',{w:workspace.id}));
 return Response.json({...base,leads,tasks,documents:documents.filter(d=>!d.deleted_at),activity,conversations,generations,members:members.map(m=>({...m,...profiles.find(p=>p.id===m.user_id)})),ai_used:usage?.ai||0,storage_used:usage?.storage||versions.reduce((n,v)=>n+Number(v.size),0)},{headers:{'Cache-Control':'no-store'}});
}catch(e){return failure(e);}}
