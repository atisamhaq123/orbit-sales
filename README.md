# Orbit Sales

A focused sales CRM for founders and small teams: shared leads, a fixed pipeline, manual follow-ups, private AI conversations, source-grounded drafts, private knowledge ingestion, in-app invitations, and Stripe subscriptions. Next.js App Router 16.4.2, React 19.3.1, TypeScript, Supabase, pgvector, Stripe.

ClientNest was inspected as a read-only reference. No reference branding, credentials, environment files, customers, or subscriptions were copied. No application email-sending mechanism is included. Google OAuth is the only authentication method.

## Run locally

Use Node.js 24 and npm. On Windows PowerShell, use `npm.cmd` if execution policy blocks `npm.ps1`.

```sh
npm ci
npm run dev
```

Open http://localhost:3100 and choose **Take a look around**, or open http://localhost:3100/app?demo=1. Demo edits persist in this browser under `orbit-sales-demo-v1`; Settings → Reset demo restores fictional records. Demo AI, ingestion, invitations and billing are explicitly simulated and make no live API requests. Live sessions never fall back to demo.

## Configure live services

Copy `.env.example` to `.env.local`, then replace placeholders with NEW Orbit Sales credentials. Restart Next.js after changing public environment variables. Do not commit `.env.local` or pass secrets in URLs.

### Supabase and Google

1. Create an independent Supabase project. Enable pgvector. Apply, in order, `supabase/migrations/001_orbit.sql`, `002_access.sql`, and `003_recovery.sql` as the project database owner. The migrations expect Supabase's `auth`, `storage`, `extensions`, and `supabase_realtime` infrastructure. The local tests provide fixtures for this infrastructure.
2. In Google Cloud, create a Web OAuth client with consent screen. Use Supabase's provider callback URL, `https://YOUR-ORBIT-PROJECT.supabase.co/auth/v1/callback`, as an authorized Google redirect URI. Set the Google client ID and secret in Supabase Auth → Providers → Google. Enable only identity scopes; no mailbox access.
3. In Supabase Auth URL configuration, set the application site URL and allow `http://localhost:3100/auth/callback` and your production `/auth/callback`. Supabase handles the PKCE provider flow; the application exchanges the code into a cookie session. Redirect destinations are constrained to local application/invitation routes. The Next.js Proxy refreshes sessions.
4. Disable email/password and any email-based signup/sign-in flows in Supabase Auth. This application never calls an email authentication API, mail transport, SMTP, magic link, reset email, or mailto action.
5. Set `NEXT_PUBLIC_SUPABASE_URL`, the anon/publishable project key compatible with `@supabase/ssr`, and the server-only service role key. Keep `NEXT_PUBLIC_APP_URL` equal to the canonical browser origin, with no trailing slash. Mutations reject other origins.
6. Sign in with Google. Onboarding explicitly offers workspace creation or pending invitations. Workspace creation uses a client creation key and a database uniqueness constraint; invitation acceptance never creates a personal workspace. The owner then subscribes in Plans & billing before creating CRM data.

Workspace owners manage billing, membership, invitations and name. Members manage shared CRM/tasks/knowledge. Only a document uploader or workspace owner can replace/delete/retry it. Conversations and generations are private to their creator. Current membership is checked in server operations and RLS, including retrieval, signed downloads, queue activation and notification links. All raw table mutations are denied to browser roles except notification read state; authorized mutations go through constrained transactional RPCs.

### Stripe

Create two Orbit Sales-specific monthly USD prices: **Starter $19** and **Pro $49**. Set their price IDs and the Orbit Stripe test secret key. Never use ClientNest customers, products, keys, or subscriptions.

Enable the Stripe Billing Portal with payment method management, invoices, cancellation, and subscription updates between the two prices. Enable prorations and use Stripe's confirmation flow for updates. An existing active subscription is changed through `subscription_update_confirm`; a delinquent subscription opens the portal instead of creating a duplicate. Open Checkout sessions are reused or expired before switching plan. Customer creation uses a workspace idempotency key; a distributed database lease serializes billing requests and reconciliation.

Forward local webhooks:

```sh
stripe listen --forward-to localhost:3100/api/stripe/webhook
```

Set the returned signing secret as `STRIPE_WEBHOOK_SECRET`. Register these events for production: `checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`, `invoice.payment_failed`.

Webhook signatures are verified against the raw body. Processing retrieves authoritative subscriptions for the mapped customer, validates the `orbit_workspace` metadata and configured price, and commits with event deduplication. Out-of-order events reconcile current provider state; a stale accounting period cannot overwrite a newer one. Failed processing returns a retryable non-2xx response. Opening billing and returning from Checkout both reconcile. Browser flags never grant a plan.

In Stripe test mode verify: initial Checkout → pending until reconciliation; valid test card activation; portal upgrade/downgrade with proration confirmation; renewal; failed payment; payment recovery; cancellation at period end; immediate cancellation; replayed/delayed events; rejected signature; and a retry after a forced database outage. Run two browser requests concurrently and confirm there is one customer and no duplicate active subscription. These external lifecycle checks require your configured Stripe/Supabase accounts and were **not performed against live services** here.

### AI and embeddings

Set a server-only `OPENAI_API_KEY` and `OPENAI_CHAT_MODEL` available to your account with Chat Completions structured JSON-schema support. No default chat model is silently selected. The application uses the official OpenAI HTTPS endpoints. Model requests have a 45-second timeout, bounded input/context, 1,600 maximum output tokens, citation validation and no automatic generation retries. Provider errors are actionable and never replaced by simulated output in live mode. Generation content is rendered as text; no HTML or model tools run.

Embedding model is deliberately fixed to `text-embedding-3-small`, **1536 dimensions**, matching the migration. Batches contain at most 32 chunks. Changing model/dimension requires a deliberate vector-column migration and full reindex, not just an environment edit.

Each summary, draft, next action or knowledge answer reserves one workspace allowance atomically before generation. Reservations count alongside successes, failures are released, duplicate request IDs do not call the provider twice, and settlement is idempotent. Expired reservations are recovered by subsequent AI requests and worker ticks. All accounting uses Stripe's current billing period; changing a plan does not reset usage. Indexing does not consume AI actions.

References used for implementation: [Supabase SSR](https://supabase.com/docs/guides/auth/server-side/creating-a-client?framework=nextjs), [OpenAI structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=chat), [OpenAI embeddings](https://developers.openai.com/api/docs/guides/embeddings), [Stripe portal sessions](https://docs.stripe.com/api/customer_portal/sessions/create). Framework guides were read from the installed Next.js `dist/docs` directory.

### Ingestion worker

Run a durable Node.js worker alongside the web app:

```sh
npm run worker
```

The local command reads `.env.local`. In a deployed worker with environment variables injected by the host, run `node --experimental-strip-types worker/ingest.ts`. Use `Dockerfile.worker` on a container host (for example a dedicated worker service); inject the three worker secrets through the host. Use at least 512 MB memory. Run one instance initially; queue claims use `FOR UPDATE SKIP LOCKED` and fenced lease tokens to support multiple workers. Graceful termination stops after the current job; abrupt termination is recovered when its five-minute lease expires.

Private original upload is reserved transactionally before upload. The database records uploading/queued/processing/ready/failed states. The worker extracts UTF-8 text or PDF text, limits to 10 MB / 200 pages / 500,000 characters / 400 chunks, chunks at approximately 1,800 characters with 180-character overlap, embeds bounded batches and activates the version atomically. Empty/scanned PDFs fail with an OCR explanation. Three attempts use 30/60-second backoff before visible terminal failure. Authorized manual retry creates fresh attempts. Old ready versions remain searchable during replacement; deleted/superseded jobs cannot reactivate evidence.

The worker also removes obsolete/deleted storage objects, then confirms metadata deletion to release reserved bytes. All stored versions count until this cleanup succeeds. Cleanup retries naturally after interruption; it never removes a current ready version. Revoked uploader/subscription jobs become actionable failures. Old grounded outputs are hidden if any cited document/version is no longer available. Short-lived source links reauthorize membership and expire after 60 seconds. An already issued signed URL can remain valid until that short expiry.

Hybrid retrieval runs tenant-scoped vector similarity and PostgreSQL English full-text queries before ranking or limiting. Reciprocal rank fusion uses `k=60`, 20 candidates per modality, eight final sources, similarity floor 0.22, and 12,000 context characters. Overlap prefixes are deduplicated. An answer without evidence takes an explicit insufficient-evidence path. Uploaded text cannot grant access or override system instructions. The initial retrieval fixture is intentionally small; production relevance should be tuned using real labeled, authorized documents.

## Plans

`src/lib/plans.json` is the plan source. UI reads it directly; migrations seed the matching database enforcement values and an automated parity test prevents drift. A plan change needs a migration generated from that file. Starter: 250 leads, 2 members, 50 AI actions, 25 documents, 100 MB. Pro: 2,500 leads, 5 members, 300 AI actions, 250 documents, 1 GB. Limits include the owner. Inactive accounts retain authorized read access, invitation accept/decline and owner billing; writes requiring paid service are denied. Cleanup remains available. Downgrades preserve records/members and block excess new usage.

## Deploy, operate, restore

Deploy the web app to a Next.js-compatible Node host with Node 24 (`npm ci`, `npm run build`, `npm run start`; set the host port via your start command as needed). Vercel requires the project root to be `orbit-sales`, the environment values above, a canonical origin, and function runtime limits that permit the 60-second AI handler. The worker is a separate long-running container; do not run it in a request function or in-memory queue. A reverse proxy must support the maximum upload size. Verify production Google redirect allowlists and HTTPS cookie behavior before customer access.

Use separate development and production Supabase/Stripe/OpenAI projects. Apply migrations through a reviewed database migration process. Back up PostgreSQL with Supabase managed backups/PITR or encrypted `pg_dump` backups, and back up private Storage originals separately: database backups alone do not include their bytes. Test a restore in a separate project, restore originals to the same private paths, reapply provider settings/secrets, and reindex missing vectors. Keep billing writes disabled during a recovery until customer mappings and authoritative Stripe subscriptions reconcile. Never replay Stripe event payloads as entitlements without retrieving provider state.

`/api/health` reports only process health, never secrets or database/customer details. Logs contain event names, job IDs, statuses and counts rather than customer content, tokens or credentials. Monitor job failures/lease age, worker liveness, failed webhooks, expired reservations, storage cleanup backlog and provider errors. Review and purge old rate-limit rows and event/audit history according to your retention policy. Owners cannot leave; ownership transfer and workspace deletion are deliberately deferred.

## Verification

```sh
npm run typecheck
npm test
npm run build
npm run start
npm run test:browser
```

Browser tests use installed Chrome (`CHROME_PATH` override) and `TEST_URL` defaults to `http://localhost:3100`. They capture screenshots into `artifacts/`. Tests use actual PostgreSQL/pgvector in PGlite with fixture Supabase infrastructure, and deterministic test embeddings. Provider HTTP tests are mocked; the demo tests are simulated workflows. They do not certify Google OAuth, hosted Supabase Storage/Realtime, Stripe payments, live embeddings or LLM factual quality. See `VERIFICATION.md` and the JSON reports for actual results and remaining external checks.

The MVP uses capped paged reads for its shared workspace snapshot (500 rows per page, up to 12,500 per table) and UI pagination for leads. Larger archival/task histories should move to server-driven per-view pagination/aggregates before exceeding this deliberately bounded snapshot. Google Fonts are an optional styling request with system font fallback; authentication and customer data never depend on them.
