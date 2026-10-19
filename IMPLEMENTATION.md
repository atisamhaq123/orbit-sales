# Orbit Sales implementation checklist

- [x] Inspect ClientNest, framework documentation, screenshots, and empty destination. Reference remains read-only.
- [x] Create original responsive interface, landing, real application routes, accessible dialogs, isolated persistent demo.
- [x] Implement email/password authentication, verified identity, workspace onboarding and current membership authorization.
- [x] Implement persistent CRM, tasks, activity, notifications, invitations, private assistant history and settings.
- [x] Add PostgreSQL schema, RLS, transactional quotas, optimistic concurrency and security checks.
- [x] Implement private uploads, durable leased ingestion worker, version activation and hybrid retrieval.
- [x] Implement bounded AI operations, reservation/refund/recovery, grounded citations and source revocation.
- [x] Implement Stripe Checkout, confirmation portal, authoritative reconciliation and idempotent webhooks.
- [x] Run typecheck, automated security/workflow tests, production build, browser checks and retrieval evaluation.
- [x] Capture desktop/mobile screenshots; write setup and verification documentation with external configuration limits.

Signup confirmation emails are sent by Supabase Auth. Application sales email transport, mailto controls, automated outreach and external calendar integration are outside the current scope.

Local verification: 34 automated tests, production build, typecheck, 55 responsive application views and six retrieval cases pass. See VERIFICATION.md for mocked/local scope and unconfigured external integrations.
