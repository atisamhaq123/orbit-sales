import Workspace from '@/components/workspace';
import {Suspense} from 'react';
import Loading from '../loading';
import {notFound} from 'next/navigation';
import {identity,AppError} from '@/lib/server';
import AuthGate from '@/components/auth-gate';
export default async function Page({params,searchParams}:{params:Promise<{slug?:string[]}>;searchParams:Promise<Record<string,string|undefined>>}){const slug=(await params).slug||[];if(slug.length>2||slug.length===2&&slug[0]!=='leads'||slug.length>0&&!['leads','pipeline','follow-ups','knowledge','assistant','notifications','team','billing','settings'].includes(slug[0]))notFound();const query=await searchParams;if(query.demo!=='1'){try{await identity();}catch(e){const suffix=query.workspace?'?workspace='+encodeURIComponent(query.workspace):'';return <AuthGate message={e instanceof AppError?e.message:'Sign in again to continue.'} next={'/app'+(slug.length?'/'+slug.join('/'):'')+suffix}/>;}}return <Suspense fallback={<Loading/>}><Workspace/></Suspense>;}
