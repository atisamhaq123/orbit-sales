# Orbit Sales

A focused sales CRM for founders and small teams: shared leads, a fixed pipeline, manual follow-ups, private AI conversations, retrieval-augmented generation (RAG) with cited answers and drafts, private knowledge ingestion, in-app invitations, and Stripe subscriptions. Next.js App Router 16.4.2, React 19.3.1, TypeScript, Supabase, pgvector, Stripe.

ClientNest was inspected as a read-only reference. No reference branding, credentials, environment files, customers, or subscriptions were copied. Authentication uses email and password through Supabase Auth. Supabase sends signup confirmation emails; the application does not send sales or invitation emails.

## Run locally

Use Node.js 24 and npm. On Windows PowerShell, use `npm.cmd` if execution policy blocks `npm.ps1`.

```sh
npm ci
npm run dev
```

Open http://localhost:3100 and choose **Take a look around**, or open http://localhost:3100/app?demo=1. Demo edits persist in this browser under `orbit-sales-demo-v1`; Settings → Reset demo restores fictional records. Demo AI, ingestion, invitations and billing are explicitly simulated and make no live API requests. Live sessions never fall back to demo.

### Development and production commands

| Command | Purpose |
|---|---|
| `npm run dev` | Start the development server on port 3100 with automatic updates while editing. |
| `npm run build` | Create an optimized production build. |
| `npm start` | Serve the last production build on port 3100. Build first; rebuild and restart after code changes. |
| `npm run worker` | Process knowledge uploads and cleanup jobs in a separate terminal. Reads `.env.local`. |

Run one web server at a time because development and production both use port 3100. For live knowledge uploads, keep **two terminals** running: `npm run dev` (or `npm start`) and `npm run worker`. Starting the web server does not start the worker.

### Interface and navigation

The shared `/app` layout retains the sidebar and workspace data when switching sections. Navigation does not reload the full workspace snapshot; initial loading and changing workspaces can show the loading skeleton. Background refreshes and successful mutations keep data current. Live data and mutation APIs enforce authentication and membership independently of the layout.

Desktop text has a minimum size of **14px at viewport widths of 1024px and above**, controlled by `--minimum-font-size` in `src/app/globals.css`. Larger text retains its intended size; smaller viewports retain their existing typography. The root body suppresses hydration attribute warnings to accommodate attributes injected by browser extensions, such as `cz-shortcut-listen`.

## Configure live services

Copy `.env.example` to `.env.local`, then replace placeholders with NEW Orbit Sales credentials. Restart Next.js after changing public environment variables. Do not commit `.env.local` or pass secrets in URLs.

### Supabase and email authentication

1. Create an independent Supabase project. Enable pgvector. Execute migrations in the Supabase SQL Editor or your migration deployment tool in order: `001_orbit.sql`, `002_access.sql`, `003_recovery.sql`, and `004_email_auth.sql`. Installations with migrations 001–003 already applied need only `004_email_auth.sql`. It removes the Google-only identity requirement and retains verified-email checks and workspace permissions. Opening or editing a migration locally does not apply it to the hosted database.
2. In Supabase Authentication > Sign In / Providers, enable **Email** and email/password signup. Disable Google if it was enabled. Keep **Confirm email** enabled for production.
3. In Authentication > URL Configuration, set Site URL to `http://localhost:3100` during local development. Allow `http://localhost:3100/auth/callback` and the production callback URL.
4. Signup uses Supabase's confirmation email and a PKCE callback. For confirmation links that also work in a different browser, set the **Confirm signup** email template link to `{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email`. The supplied RedirectTo already contains the validated destination in its next query parameter. The callback supports both token hashes and the standard PKCE code exchange. Configure Supabase SMTP for delivery to real users; the built-in sender has development restrictions and rate limits.
5. Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and the server-only `SUPABASE_SERVICE_ROLE_KEY`. Keep `NEXT_PUBLIC_APP_URL` equal to the canonical browser origin, with no trailing slash. Restart Next.js after environment changes.
6. Open `/signup`, create an account, and confirm the email. Use `/login` for subsequent sessions. If email confirmation is disabled for development, signup logs in immediately. Existing Google-only users need an email/password credential configured in Supabase before password login.
7. Onboarding offers workspace creation or pending invitations. Invitation links retain their destination through login/signup and require the intended verified email account. The owner subscribes in Plans & billing before creating CRM data.

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

The worker requires `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` and `OPENAI_API_KEY`, plus network access to Supabase and OpenAI. Answer generation additionally requires `OPENAI_CHAT_MODEL` in the web app. Restart the relevant processes after changing their environment configuration. Indexing uses the configured OpenAI account for embedding requests.

Private original upload is reserved transactionally before upload. The database records uploading/queued/processing/ready/failed states. The worker extracts UTF-8 text or PDF text, limits to 10 MB / 200 pages / 500,000 characters / 400 chunks, chunks at approximately 1,800 characters with 180-character overlap, embeds bounded batches and activates the version atomically. Empty/scanned PDFs fail with an OCR explanation. Three attempts use 30/60-second backoff before visible terminal failure. Authorized manual retry creates fresh attempts. Old ready versions remain searchable during replacement; deleted/superseded jobs cannot reactivate evidence.

The worker also removes obsolete/deleted storage objects, then confirms metadata deletion to release reserved bytes. All stored versions count until this cleanup succeeds. Cleanup retries naturally after interruption; it never removes a current ready version. Revoked uploader/subscription jobs become actionable failures. Old grounded outputs are hidden if any cited document/version is no longer available. Short-lived source links reauthorize membership and expire after 60 seconds. An already issued signed URL can remain valid until that short expiry.

Hybrid retrieval runs tenant-scoped vector similarity and PostgreSQL English full-text queries before ranking or limiting. Reciprocal rank fusion uses `k=60`, 20 candidates per modality, eight final sources, similarity floor 0.22, and 12,000 context characters. Overlap prefixes are deduplicated. An answer without evidence takes an explicit insufficient-evidence path. Uploaded text cannot grant access or override system instructions. The initial retrieval fixture is intentionally small; production relevance should be tuned using real labeled, authorized documents.

### Retrieval-augmented generation (RAG)

RAG grounds AI responses in the current workspace's uploaded documents. Instead of relying only on the model's general knowledge, Orbit retrieves relevant passages and supplies them as evidence when generating an answer or a sales draft.

1. **Upload:** Store a TXT, Markdown or text-based PDF original in private Supabase Storage.
2. **Index:** The separate ingestion worker extracts text, splits it into overlapping chunks, generates OpenAI embeddings and stores the chunks and vectors in PostgreSQL with pgvector. The document becomes searchable when indexing finishes and its status is **Ready**.
3. **Retrieve:** For a knowledge question or a draft that needs supporting context, combine vector similarity search with PostgreSQL full-text search. Reciprocal rank fusion merges the results, scoped to the authorized workspace and current document versions.
4. **Generate:** Supply a bounded selection of relevant passages to the configured chat model, alongside the question or drafting instructions. Lead summaries can also use structured CRM records; not every AI operation requires document retrieval.
5. **Cite:** Validate generated citations against the retrieved sources and show source references with the response. Source links recheck current access before opening the private original. Citations help users inspect evidence; users still review answers and drafts for accuracy.

When retrieval finds insufficient evidence for a knowledge answer, the application returns an explicit insufficient-evidence response. Queued uploads cannot support an answer. Deleted, superseded or inaccessible document versions are excluded from future retrieval. Adding documents updates the retrieval index; it does not fine-tune the chat model.

### Try the sample knowledge base

1. Start the web app and worker, log in, and open a workspace with an active subscription.
2. Open **Knowledge base → Upload knowledge** and select [`sample-knowledge-base.txt`](sample-knowledge-base.txt).
3. Wait for the document to change from **Queued** through processing to **Ready**. Upload completion alone does not make it searchable.
4. Open **AI assistant** and ask a new question, such as “What's included in the Pro plan?”, “Which plan fits five people?”, or “Draft an onboarding follow-up for Olivia.” Review the returned citations.

The sample includes pricing, onboarding, follow-up guidelines, fictional customer scenarios, upload requirements, security information and fictional support policies. It is explicitly labeled test content; its support address is a non-working `.example` address. A local live worker run successfully indexed this file into six chunks. That confirms this upload's ingestion, not every retrieval or generated-answer scenario. Earlier answers are not regenerated automatically after indexing; ask again once the file is ready.

## Troubleshooting

| Symptom | What to check |
|---|---|
| An old “Sign in with Google” message appears | Restart the web server. With `npm start`, rebuild first. Confirm migration 004 was applied to the same Supabase project configured in `.env.local`. Google OAuth credentials are no longer needed by the app. |
| Login succeeds but email verification is required | Confirm the signup email. Verify the Email provider, callback allowlist and confirmation template settings above. |
| `column memberships.id does not exist` | Update to the current application code. The workspace loader now orders membership rows by `user_id`; other paged tables use `id`. Rebuild/restart a production server. No additional schema column is needed. |
| A document stays **Queued** | Keep `npm run worker` running separately. Check its Supabase/OpenAI configuration, connectivity and terminal output. The web app alone does not index uploads. |
| Worker reports `worker.database_unavailable` | Check network access to Supabase, the configured project URL and service role key, and that all required migrations were applied. This message can also result from a connection failure. |
| Worker reports `ingestion.failed`, or a document shows **Failed** | Check the document error and worker configuration. Confirm embedding model access and API credits, or replace an unsupported/empty/scanned file. Retry after correcting the cause. |
| AI reports insufficient evidence | Wait for the relevant document to show **Ready**, check that you are in the correct workspace, then ask again. Queued documents are not searchable. A ready file still needs relevant content to support the question. |
| Full-screen loading appears on every section change | Use the current shared-layout implementation. Restart development or rebuild/restart production so the running server uses the updated routes. |

## Plans

`src/lib/plans.json` is the plan source. UI reads it directly; migrations seed the matching database enforcement values and an automated parity test prevents drift. A plan change needs a migration generated from that file. Starter: 250 leads, 2 members, 50 AI actions, 25 documents, 100 MB. Pro: 2,500 leads, 5 members, 300 AI actions, 250 documents, 1 GB. Limits include the owner. Inactive accounts retain authorized read access, invitation accept/decline and owner billing; writes requiring paid service are denied. Cleanup remains available. Downgrades preserve records/members and block excess new usage.

## Deploy, operate, restore

Deploy the web app to a Next.js-compatible Node host with Node 24 (`npm ci`, `npm run build`, `npm run start`; set the host port via your start command as needed). Vercel requires the project root to be `orbit-sales`, the environment values above, a canonical origin, and function runtime limits that permit the 60-second AI handler. The worker is a separate long-running container; do not run it in a request function or in-memory queue. A reverse proxy must support the maximum upload size. Verify production email callback allowlists and HTTPS cookie behavior before customer access.

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

With a web server running, focused browser checks are also available:

```sh
node tests/email-auth.browser.mjs
node --experimental-strip-types tests/navigation.browser.mjs
```

The email checks cover password login success and session cookies, login errors, signup confirmation feedback, password matching and safe return destinations. The navigation checks cover seven sections, a persistent sidebar, no repeated snapshot fetches or loading flashes on section changes, browser Back, workspace switching, demo isolation and the logged-out gate. Both focused suites use mocked Supabase responses; they do not create live accounts or prove hosted email delivery.

Browser tests use installed Chrome (`CHROME_PATH` override) and `TEST_URL` defaults to `http://localhost:3100`. They capture screenshots into `artifacts/`. Tests use actual PostgreSQL/pgvector in PGlite with fixture Supabase infrastructure, and deterministic test embeddings. Provider HTTP tests are mocked; the demo tests are simulated workflows. They do not certify email authentication, hosted Supabase Storage/Realtime, Stripe payments, live embeddings or LLM factual quality. See `VERIFICATION.md` and the JSON reports for actual results and remaining external checks.

The most recent application changes passed the production build and TypeScript checks. All 34 automated tests passed after the email-authentication migration and membership-query fix; the focused navigation suite passed after the shared-layout change. The successful live sample ingestion described above is separate from these automated results. Historical full demo browser results in `VERIFICATION.md` predate the latest authentication/navigation changes.

The MVP uses capped paged reads for its shared workspace snapshot (500 rows per page, up to 12,500 per table) and UI pagination for leads. Larger archival/task histories should move to server-driven per-view pagination/aggregates before exceeding this deliberately bounded snapshot. Google Fonts are an optional styling request with system font fallback; authentication and customer data never depend on them.
