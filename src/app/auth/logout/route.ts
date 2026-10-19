import {db,origin,failure} from '@/lib/server';
export async function POST(request:Request){try{origin(request);await (await db()).auth.signOut();return Response.json({ok:true});}catch(e){return failure(e);}}
