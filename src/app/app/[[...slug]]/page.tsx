import {notFound} from 'next/navigation';
// The shared layout retains the workspace across section changes. Live data and
// mutations remain authenticated by their API handlers and database policies.
export default async function Page({params}:{params:Promise<{slug?:string[]}>}){const slug=(await params).slug||[];if(slug.length>2||slug.length===2&&slug[0]!=='leads'||slug.length>0&&!['leads','pipeline','follow-ups','knowledge','assistant','notifications','team','billing','settings'].includes(slug[0]))notFound();return null;}
