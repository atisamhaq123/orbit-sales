# Fictional seed data

The deterministic starter dataset lives in `src/lib/demo.ts`. It includes eight fictional leads across all six stages, three follow-ups, three sample team members, four knowledge ingestion states, activity, notifications, and a pending invitation. `demoData()` generates due dates relative to the current time. It is browser-local and never inserted into a live workspace automatically.

The labeled retrieval fixture lives in `tests/retrieval-fixtures.json`. `npm test` creates an ephemeral PostgreSQL database, seeds verified test identities and fictional documents, indexes deterministic vectors, executes real hybrid search and RLS, writes the measured report, then discards the database.

Live CRM data should begin empty. To evaluate live retrieval, sign into an independently configured test workspace, subscribe using Stripe test mode, upload the fixture text as Markdown, run the ingestion worker, and ask the labeled questions. Record live retrieval metrics separately from the deterministic local report.
