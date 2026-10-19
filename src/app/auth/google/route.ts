import {db,env,failure} from '@/lib/server';
import {safeNext} from '@/lib/validation';
export async function GET(request:Request){try{const next=safeNext(new URL(request.url).searchParams.get('next'));const client=await db();const {data,error}=await client.auth.signInWithOAuth({provider:'google',options:{redirectTo:`${env('NEXT_PUBLIC_APP_URL')}/auth/callback?next=${encodeURIComponent(next)}`,scopes:'openid email profile'}});if(error||!data.url)throw error;return Response.redirect(data.url);}catch(e){return failure(e);}}
