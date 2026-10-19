import Link from 'next/link';
import {ArrowUpRight,ArrowRight} from 'lucide-react';
import {Brand} from './ui';
export default function AuthGate({message,next}:{message:string;next:string}){return <main className="auth-screen"><Link href="/"><Brand/></Link><section className="panel"><span className="eyebrow">YOUR WORKSPACE AWAITS</span><h1>Good things ahead.</h1><p>Sign in with Google to open your workspace or accept a pending invitation.</p><p className="error" role="alert">{message}</p><a className="button primary" href={`/auth/google?next=${encodeURIComponent(next)}`}>Continue with Google <ArrowUpRight size={17}/></a><Link className="button" href="/app?demo=1">Explore the isolated demo <ArrowRight size={17}/></Link></section></main>;}
