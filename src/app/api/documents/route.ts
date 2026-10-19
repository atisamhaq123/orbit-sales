import {context,admin,origin,check,failure,AppError} from '@/lib/server';
import {validateUpload} from '@/lib/validation';
import {readBody} from '@/lib/request';
export async function POST(request:Request){try{
 origin(request);if(Number(request.headers.get('content-length')||0)>11*1024*1024)throw new AppError('Maximum file size is 10 MB.',413);
 const body=await readBody(request,11*1024*1024);const form=await new Response(body,{headers:{'Content-Type':request.headers.get('content-type')||''}}).formData(),file=form.get('file');if(!(file instanceof File))throw new AppError('Select a file.');if(file.size>10*1024*1024)throw new AppError('Maximum file size is 10 MB.');
 const w=String(form.get('workspace'));const {client}=await context(w);const bytes=new Uint8Array(await file.arrayBuffer());let mime:string;try{mime=validateUpload(file.name,bytes);}catch(e){throw new AppError((e as Error).message);}
 const reservation=check(await client.rpc('reserve_upload',{w,title:file.name,bytes:file.size,mime,replace_id:form.get('replace')||null}));const svc=admin();
 const upload=await svc.storage.from('orbit-knowledge').upload(reservation.path,bytes,{contentType:mime,upsert:false});
 if(upload.error){check(await svc.from('ingestion_jobs').update({status:'failed',error:'Original upload failed. Replace the file to retry.'}).eq('version_id',reservation.version));check(await svc.from('documents').update({status:'failed',error:'Original upload failed. Replace the file to retry.'}).eq('id',reservation.document));throw new AppError('Upload failed. Replace this file to retry.');}
 check(await svc.from('ingestion_jobs').update({status:'queued'}).eq('version_id',reservation.version).eq('status','uploading'));
 return Response.json({ok:true});
}catch(e){return failure(e);}}
