# Orbit Sales verification

Verified locally on 19 October 2026. Source: `orbit-sales/`. ClientNest remained read-only. No credentials, environment files, billing records or customer data were copied. There is no application email transport or email authentication flow.

## Completed implementation

- Original graphite/cyan/violet landing page and responsive application: expanded desktop sidebar, compact tablet navigation, trapped mobile drawer, native accessible dialogs, focus restoration and reduced motion.
- Real routes for overview, leads/details, pipeline, follow-ups, knowledge, assistant, inbox/invitations, team, billing, settings, and secure invitation acceptance. Invalid application routes return 404.
- Explicit browser-local demo with fictional data and persistent edits/reset. Demo simulations are labeled. Sign-in uses normal anchors to prevent prefetching OAuth endpoints.
- Google PKCE OAuth, cookie sessions, session refresh, protected live routes, verified identity checks and logout. Explicit onboarding and idempotent workspace creation; invitation acceptance never bootstraps an extra workspace.
- PostgreSQL persistent leads, tasks, activity, workspace settings, memberships, notifications, private conversations and generated drafts. Fixed six-stage pipeline, estimated USD deal values, stage/assignee/search/archive filters, lead pagination, UTC task storage and timezone display.
- Three Supabase migrations, RLS and column grants, generated database row types, private original storage, composite tenant foreign keys, transactional writes/quotas, optimistic edit versions, and server origin checks.
- Hashed seven-day invitations, verified-email binding, token rotation/revocation, atomic acceptance, duplicate prevention, seat checks and immediate server/database access revocation.
- Durable ingestion queue with leases, fencing, backoff, terminal errors, retry, replacement activation, extraction bounds, success/failure notifications, and storage cleanup. Deployable worker container included.
- Real pgvector + PostgreSQL full-text hybrid retrieval with RRF; current-source checks, bounded/deduplicated evidence, readable citations and short-lived downloads. Revoked/deleted/superseded evidence cannot justify persisted answers.
- Server-side structured AI draft/summary/next-action/knowledge operations, editable outputs, copy/save, prompt-injection boundaries, citation validation, timeouts, usage reservations, idempotent settlement, refunds and abandoned-reservation recovery.
- Owner-only Stripe Checkout/portal, plan-change confirmation, reconciliation, customer/price/workspace association checks, distributed billing lease, raw-body signatures, event deduplication, stale-period guards and server entitlements.
- `.env.example`, setup/Google/Stripe/AI/worker/deployment/backup instructions and fictional seed documentation.

## Actual local results

| Check | Result | Scope |
|---|---|---|
| `npm run typecheck` | Pass | Application, API and worker TypeScript |
| `npm test` | **34 passed, 0 failed** | Real local PostgreSQL/pgvector, PDF parsing, logic and mocked provider HTTP |
| `npm run build` | Pass | Next.js 16.4.2 optimized production build |
| `npm run test:browser` | Pass | Chrome against the production server |
| Responsive application views | **55 passed** | 11 routes × 360, 390, 768, 1024, 1440 px; no page overflow |
| Responsive landing views | **5 passed** | Same widths |
| Demo network isolation | Pass | No `/api/` or `/auth/` requests during demo/landing browsing |
| Browser runtime exceptions | **0** | Tested workflows |
| Keyboard/reduced motion | Pass | Dialog Escape/restoration; mobile drawer focus containment/Escape; animation suppression |

Database checks exercise cross-workspace reads/writes, owner/member boundaries, browser entitlement-write rejection, invitation rotation/expiry/revocation/replay/wrong identity, idempotent onboarding, seat limits, competing acceptance transactions, task/activity persistence, optimistic conflicts, notification ownership, private conversations, source revocation, quota failures, AI refunds/recovery, worker interruption and stale-token rejection, document replacement/deletion/cleanup, billing lock/deduplication/customer mapping/stale periods and preserved within-period usage. The competing requests run on PGlite's serialized engine; this is not a multi-process hosted PostgreSQL contention benchmark.

Provider tests use mocked HTTP to exercise timeout/error handling and embedding-dimension checks. Stripe signature tests use the real SDK with a generated local test signature; no Stripe account/payment is contacted. PDF tests parse actual generated PDF bytes and reject an empty/image-only equivalent with the OCR message. Hosted original uploads and their private bucket were not contacted.

Browser checks cover creation and persistence of a lead, pipeline changes, task creation/completion, editable/saved demo drafts and cited answers, insufficient-evidence demo behavior, upload/indexing simulation, invitation creation, billing simulation, navigation/back and configuration errors. Live provider failures never become a demo session.

## Retrieval evaluation

See `artifacts/retrieval-evaluation.json` and `tests/retrieval-fixtures.json`.

- Six labeled questions over fictional pricing, onboarding and security evidence.
- Actual migration retrieval SQL, pgvector similarity, PostgreSQL English full-text ranking and reciprocal rank fusion execute in PGlite.
- Deterministic orthogonal **test vectors** are used. Live embeddings were not generated.
- Five answerable questions return the expected document in the first three results; one unanswerable question returns no evidence. All six cases pass.
- Retrieved citation-reference validity: **100%**. Cross-workspace result count: **0**.
- This small fixture validates mechanics and isolation, not live semantic quality, factual grounding accuracy, or recall on customer documents. Live model insufficient-evidence behavior still needs a configured integration evaluation.

## Screenshots

`artifacts/` contains landing desktop/mobile, dashboard desktop/mobile, leads and detail/draft citations, pipeline desktop/mobile, follow-ups, cited assistant answer, knowledge ingestion states, invitation/inbox controls, team, billing, settings and the invitation route's unconfigured live state. Screenshots show fictional demo data except the explicitly labeled configuration-error screen. `browser-results.json` records the browser run.

## Remaining external setup and live checks

No Orbit Sales credentials were provided or borrowed. The following remain **unconfigured and unverified live**:

1. New Supabase project, migration deployment, Google OAuth credentials/redirect allowlists and a real verified Google session.
2. Hosted Supabase Storage and Realtime behavior, production RLS under the actual gateway, multi-process invitation/worker contention, and cross-account revocation through real sessions.
3. Orbit-specific Stripe prices, portal settings, webhook forwarding/endpoint, Checkout payments and full subscription lifecycle tests.
4. OpenAI key/chat model access, live embedding relevance, generated-answer/citation quality, provider failure recovery across the deployed infrastructure.
5. Worker container hosting, production deployment, operational monitoring and an actual backup/restore drill.

Follow the corresponding procedures in `README.md`. The local results above must not be interpreted as verification of these external services.

## Known boundaries

- Ownership transfer and workspace deletion are deferred and called out in the interface. Owners cannot leave.
- No email sending, SMTP, magic links, password resets, automated outreach, calendar integration, custom stages, CSV, OCR or autonomous AI actions.
- The workspace snapshot uses 500-row database pages with a 12,500-row/table cap; larger archival/task histories need server-driven per-view pagination and aggregates. Normal paid active-lead limits are 250/2,500.
- Database authorization takes effect immediately. Already rendered data can remain in a browser until the next authorized refresh; the inbox/data fallback polls every 20 seconds. Already issued signed downloads expire within 60 seconds. Neither old browser content nor old citations are accepted as authorization for a new operation.
- Storage remains reserved until the worker successfully removes bytes and confirms cleanup. The worker must remain running for ingestion, abandoned-upload recovery and storage reclamation.
- Retrieval currently uses exact tenant-scoped vector search, appropriate for the bounded MVP corpus. Large deployments should benchmark scoped ANN search and rerun labeled relevance evaluations.
