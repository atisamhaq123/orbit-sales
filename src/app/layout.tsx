import type {Metadata} from 'next';
import './globals.css';
export const metadata:Metadata={title:'Orbit Sales — Every lead. A little closer.',description:'A focused sales workspace for your leads, follow-ups and knowledge-grounded AI.'};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="en"><body suppressHydrationWarning>{children}</body></html>;}
