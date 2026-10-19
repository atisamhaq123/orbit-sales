import InvitationPage from '@/components/invitation';
export default async function Page({params}:{params:Promise<{token:string}>}){return <InvitationPage token={(await params).token}/>;}
