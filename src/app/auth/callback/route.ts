import {db,env} from '@/lib/server';
import {safeNext} from '@/lib/validation';
export async function GET(request:Request){const url=new URL(request.url);try{const client=await db();const {error}=await client.auth.exchangeCodeForSession(url.searchParams.get('code')||'');if(error)throw error;return Response.redirect(new URL(safeNext(url.searchParams.get('next')),env('NEXT_PUBLIC_APP_URL')));}catch{return Response.redirect(new URL('/?auth_error=Google%20sign-in%20failed.%20Please%20try%20again.',process.env.NEXT_PUBLIC_APP_URL||url.origin));}}
