import {AppError} from './server';
export async function readBody(request:Request,limit:number){
 if(Number(request.headers.get('content-length')||0)>limit)throw new AppError('Request exceeds the allowed size.',413);
 const reader=request.body?.getReader();if(!reader)return new Uint8Array();const parts:Uint8Array[]=[];let size=0;
 try{while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>limit){await reader.cancel();throw new AppError('Request exceeds the allowed size.',413);}parts.push(value);}}finally{reader.releaseLock();}
 const result=new Uint8Array(size);let offset=0;for(const part of parts){result.set(part,offset);offset+=part.byteLength;}return result;
}
