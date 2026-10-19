'use client';

import Link from 'next/link';
import {useState, type FormEvent} from 'react';
import {Brand} from './ui';
import {browserDb, configured} from '@/lib/supabase';

export default function EmailAuth({mode, next, initialError = ''}: {mode: 'login' | 'signup'; next: string; initialError?: string}) {
  const signup = mode === 'signup';
  const [error, setError] = useState(initialError);
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setError('');
    setMessage('');
    if (!configured) { setError('Email sign-in is not configured yet. Please try again later.'); return; }
    const fields = new FormData(event.currentTarget);
    const email = String(fields.get('email') || '').trim();
    const password = String(fields.get('password') || '');
    if (signup && password !== fields.get('confirmPassword')) { setError('Passwords do not match.'); return; }
    setBusy(true);
    try {
      const client = browserDb();
      if (signup) {
        const {data, error} = await client.auth.signUp({email, password, options: {
          data: {full_name: String(fields.get('name') || '').trim()},
          emailRedirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`,
        }});
        if (error) throw error;
        if (data.session) { window.location.assign(next); return; }
        setMessage('Check your inbox for a confirmation link. Confirm your email, then log in.');
      } else {
        const {error} = await client.auth.signInWithPassword({email, password});
        if (error) throw error;
        window.location.assign(next);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to sign in. Please try again.');
    } finally { setBusy(false); }
  }

  return <main className="auth-screen">
    <Link href="/" aria-label="Orbit Sales home"><Brand/></Link>
    <section className="panel">
      <span className="eyebrow">YOUR WORKSPACE AWAITS</span>
      <h1>{signup ? 'Create your account.' : 'Welcome back.'}</h1>
      <p>{signup ? 'Sign up with your email and a password to get started.' : 'Log in with your email and password.'}</p>
      <form onSubmit={submit} aria-busy={busy}>
        {signup && <label>Full name<input name="name" autoComplete="name" maxLength={100} required disabled={busy}/></label>}
        <label>Email address<input name="email" type="email" autoComplete="email" required maxLength={254} disabled={busy}/></label>
        <label>Password<input name="password" type="password" autoComplete={signup ? 'new-password' : 'current-password'} minLength={signup ? 8 : undefined} required disabled={busy}/></label>
        {signup && <><small>Use at least 8 characters.</small><label>Confirm password<input name="confirmPassword" type="password" autoComplete="new-password" minLength={8} required disabled={busy}/></label></>}
        {error && <p className="error" role="alert">{error}</p>}
        {message && <p role="status">{message}</p>}
        <button className="primary" disabled={busy}>{busy ? (signup ? 'Creating account…' : 'Logging in…') : (signup ? 'Create account' : 'Log in')}</button>
      </form>
      <p>{signup ? 'Already have an account? ' : 'New to Orbit Sales? '}<Link href={`/${signup ? 'login' : 'signup'}?next=${encodeURIComponent(next)}`}>{signup ? 'Log in' : 'Create an account'}</Link></p>
      <Link className="button" href="/app?demo=1">Explore the demo</Link>
    </section>
  </main>;
}
