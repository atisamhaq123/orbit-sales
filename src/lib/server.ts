import 'server-only';
import {createServerClient} from '@supabase/ssr';
import {createClient} from '@supabase/supabase-js';
import {cookies} from 'next/headers';
export class AppError extends Error { constructor(message:string,public status=400){super(message);} }
export function env(name:string){const value=process.env[name];if(!value)throw new AppError(`Configure ${name} to enable this live feature.`,503);return value;}
export async function db(){const jar=await cookies();return createServerClient(env('NEXT_PUBLIC_SUPABASE_URL'),env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),{cookies:{getAll:()=>jar.getAll(),setAll:(values)=>{try{for(const {name,value,options} of values)jar.set(name,value,options);}catch{/* Server component: API requests refresh cookies. */}}}});}
export function admin(){return createClient(env('NEXT_PUBLIC_SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});}
export async function identity(){const client=await db();const {data:{user},error}=await client.auth.getUser();if(error||!user||!user.email_confirmed_at)throw new AppError('Log in with a verified email address to continue.',401);return {client,user};}
export async function context(workspace:string,owner=false){const {client,user}=await identity();const {data:member}=await client.from('memberships').select('role').eq('workspace_id',workspace).eq('user_id',user.id).single();if(!member||owner&&member.role!=='owner')throw new AppError(owner?'Only the workspace owner can do this.':'Workspace access denied.',403);const {data:ws,error}=await client.from('workspaces').select('*').eq('id',workspace).single();if(error||!ws)throw new AppError('Workspace unavailable.',403);return {client,user,workspace:ws,role:member.role};}
export function origin(request:Request){if(request.headers.get('origin')!==new URL(env('NEXT_PUBLIC_APP_URL')).origin)throw new AppError('Request origin rejected.',403);}
export function check<T extends {error:unknown;data:unknown}>(result:T):T['data'] {if(result.error)throw new AppError(typeof result.error==='object'&&result.error&&'message' in result.error?String(result.error.message):'Database operation failed.');return result.data;}
export function failure(error:unknown){const status=error instanceof AppError?error.status:500;const message=error instanceof AppError?error.message:'This operation could not finish. Retry or check server configuration.';console.error(JSON.stringify({event:'request.failed',status}));return Response.json({error:message},{status,headers:{'Cache-Control':'no-store'}});}
