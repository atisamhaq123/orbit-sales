import EmailAuth from '@/components/email-auth';
import {safeNext} from '@/lib/validation';

export default async function Signup({searchParams}: {searchParams: Promise<Record<string, string | undefined>>}) {
  const params = await searchParams;
  return <EmailAuth mode="signup" next={safeNext(params.next || null)}/>;
}
