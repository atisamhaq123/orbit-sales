import EmailAuth from '@/components/email-auth';
import {safeNext} from '@/lib/validation';

export default async function Login({searchParams}: {searchParams: Promise<Record<string, string | undefined>>}) {
  const params = await searchParams;
  return <EmailAuth mode="login" next={safeNext(params.next || null)} initialError={params.error}/>;
}
