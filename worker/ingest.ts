import {createClient} from '@supabase/supabase-js';
import {extractDocument} from '../src/lib/extraction.ts';
import {embed} from '../src/lib/provider.ts';
const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url||!key||!process.env.OPENAI_API_KEY)throw new Error('Set Supabase and OpenAI worker environment variables.');
const client=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
function checked<T>(r:{data:T;error:unknown}){if(r.error)throw new Error('Worker database operation failed.');return r.data;}
let running=true;process.on('SIGTERM',()=>{running=false;});process.on('SIGINT',()=>{running=false;});
async function run(){
 checked(await client.rpc('recover_revoked_jobs'));
 const obsolete=checked(await client.rpc('cleanup_candidates'))||[];
 for(const version of obsolete){const removed=await client.storage.from('orbit-knowledge').remove([version.path]);if(!removed.error)checked(await client.rpc('confirm_cleanup',{vid:version.id}));}
 const job=checked(await client.rpc('claim_ingestion'));if(!job)return false;
 try{
 const file=checked(await client.storage.from('orbit-knowledge').download(job.path));if(!file)throw new Error('Original file unavailable. Replace the document.');const bytes=new Uint8Array(await file.arrayBuffer());if(bytes.length>10485760)throw new Error('File exceeds 10 MB.');
 const chunks=await extractDocument(bytes,job.mime);const pieces=[];
 for(let i=0;i<chunks.length;i+=32){
   // Fence each embedding batch, and confirm requester still belongs to the workspace.
   const member=checked(await client.from('memberships').select('user_id').eq('workspace_id',job.workspace_id).eq('user_id',job.requested_by).maybeSingle());if(!member)throw new Error('Uploader access revoked.');
   const lease=checked(await client.from('ingestion_jobs').update({lease_until:new Date(Date.now()+300000).toISOString()}).eq('id',job.id).eq('lease_token',job.lease_token).eq('status','processing').select('id').maybeSingle());if(!lease)throw new Error('Job lease lost.');
   const batch=chunks.slice(i,i+32),vectors=await embed(batch.map(c=>c.content));pieces.push(...batch.map((c,n)=>({...c,embedding:JSON.stringify(vectors[n])})));
 }
 checked(await client.rpc('finish_ingestion',{job:job.id,token:job.lease_token,pieces}));console.log(JSON.stringify({event:'ingestion.finished',job:job.id,chunks:chunks.length}));
 }catch(error){const known=error instanceof Error&&/exceeds|extractable|unavailable|revoked|UTF|AI provider|lease|Configure/.test(error.message)?error.message:'Document parsing or indexing failed. Replace the original or check worker configuration.';await client.rpc('finish_ingestion',{job:job.id,token:job.lease_token,pieces:[],problem:known});console.error(JSON.stringify({event:'ingestion.failed',job:job.id}));}
 return true;
}
while(running){try{if(!await run())await new Promise(resolve=>setTimeout(resolve,4000));}catch{console.error(JSON.stringify({event:'worker.database_unavailable'}));await new Promise(resolve=>setTimeout(resolve,10000));}}
