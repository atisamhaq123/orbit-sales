import {identity,origin,check,failure,AppError} from '@/lib/server';
import {readBody} from '@/lib/request';
export async function POST(request:Request){try{origin(request);const raw=new TextDecoder().decode(await readBody(request,35000));const m=JSON.parse(raw);if(typeof m.action!=='string')throw new AppError('Choose an action.');const {client}=await identity();const result=check(await client.rpc('mutate',{m}));return Response.json(result);}catch(e){return failure(e);}}
