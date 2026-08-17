# Feedback Flow

A multi-tenant API for ingesting customer feedback. Feedback goes through an async
pipeline: sentiment analysis, then aggregation, then a webhook. Built with Rails 8.1,
PostgreSQL, Redis, and Sidekiq.

Write-ups for the discussion-only sections of the assessment (no code deliverable):

- [Production incident / debugging](docs/07-production-incident.md)
- [System design: scalable feedback ingestion](docs/08-system-design.md)
- [Code review](docs/09-code-review.md)

## Running it

```bash
docker compose build
docker compose up -d
docker compose exec web bin/rails db:create db:migrate
docker compose exec web bin/rails db:seed   # creates a demo tenant, prints its API key + a sample curl
```

The API runs at `http://localhost:3000`. Sidekiq runs in a separate `worker` container
from the same image, using the same Postgres/Redis.

## Running the tests

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgresql://postgres:postgres@db:5432/feedback_flow_test web bin/rails db:create db:schema:load
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgresql://postgres:postgres@db:5432/feedback_flow_test web bundle exec rspec
```

`DATABASE_URL` needs to be set explicitly for the test run because docker-compose points
`web`/`worker` at the dev database by default; `RAILS_ENV=test` alone doesn't change that.

## API

### `POST /api/v1/feedbacks`

Headers: `X-Api-Key: <tenant api key>`, `Content-Type: application/json`

```json
{
  "external_id": "evt-93821",
  "survey_id": 421,
  "customer_id": "C-10042",
  "score": 8,
  "comment": "Fast delivery, but packaging was damaged.",
  "occurred_at": "2026-08-11T10:22:00Z"
}
```

`customer_id` is stored as-is on the feedback row.

- `201 Created` - new feedback created, pipeline kicked off.
- `200 OK` - same `(tenant, external_id)` seen before; returns the existing feedback.
- `401 Unauthorized` - missing/invalid `X-Api-Key`.
- `422 Unprocessable Content` - validation errors, e.g. `{"errors":{"customer_id":["can't be blank"]}}`.

## Architecture

```
POST /api/v1/feedbacks
        |
        v
Feedbacks::IngestService   (create feedback + OutboxEvent, one transaction)
        |
        v
OutboxEvent#enqueue!  ->  SentimentJob  ->  AggregationJob  ->  WebhookJob
```

`Api::V1::FeedbacksController` just parses params and calls the service - the logic
lives in `Feedbacks::IngestService`. `SentimentAnalyzer` is a stand-in for a real NLP
provider (keyword/score based, no external dependency). `WebhookClient` wraps
`Net::HTTP` so `WebhookJob` never talks to the network directly, which makes it easy to
stub in tests.

## Design notes

**Tenant isolation.** The tenant is never taken from request params. Each tenant has a
server-generated `api_key`; `ApplicationController#authenticate_tenant!` resolves it
from the `X-Api-Key` header and every query is scoped through `Current.tenant`
(`tenant.feedbacks.find_by(...)`, never a raw `Feedback.find`).

**Idempotency.** `(tenant_id, external_id)` is unique at the DB level on `feedbacks`.
`Feedbacks::IngestService` checks for an existing record first, then falls back to
catching `ActiveRecord::RecordNotUnique` for the case where two requests race each
other.

**Dashboard query / indexing.** The dashboard use case (daily feedback count + average
score per tenant, last 30 days) filters and sorts by `tenant_id` then `created_at`.
`feedbacks` currently only has single-column indexes on `tenant_id` and the
`(tenant_id, external_id)` uniqueness constraint - neither supports that range scan
efficiently at 100M+ rows. A composite `(tenant_id, created_at)` index (tenant first,
since every query is tenant-scoped; `created_at` second so the 30-day range scan stays
within one tenant's index slice) is missing and should be added before this table gets
large.

`TenantAggregate` is an all-time running total (positive/negative/neutral counts),
updated incrementally by `AggregationJob` - cheap to read, but it doesn't give the
dashboard's actual shape (daily buckets, average score). A real implementation needs
either a `(tenant_id, date)`-keyed daily aggregate table maintained the same
incremental way, or a materialized view refreshed on a schedule, so the dashboard never
scans raw `feedbacks` rows. At 100M+ rows I'd also range-partition `feedbacks` by
`created_at` (monthly) - it bounds index size per partition and makes retention
(dropping old partitions) cheap, but doesn't remove the need for pre-aggregation since
the dashboard still spans a rolling 30-day window across partitions.

For N+1s, long transactions, lock contention, and pool exhaustion I'd rely on
`pg_stat_statements` for query frequency/latency, `pg_stat_activity` for long-running
or blocked queries and their lock waits, and Sidekiq/Puma connection pool metrics
(checkouts vs pool size) rather than waiting for a timeout to notice. In
`EXPLAIN ANALYZE` output the signals that matter: `Seq Scan` where an index scan was
expected, a large gap between planner row estimate and actual rows (stale stats), and a
low `shared hit` vs `read` buffer ratio (working set not fitting in cache).

**Outbox pattern.** The `OutboxEvent` row is written in the same transaction as the
`Feedback`, so a feedback can't be saved without a way to kick off its pipeline. After
commit, the service tries to enqueue the first job right away; if that fails (e.g.
Redis is down, or the process crashes right after commit) the event just stays
`pending` instead of getting lost.

`rake outbox:process` is the fallback that picks up anything still `pending` (or stuck
`enqueuing` past its lock) and retries it. Nothing currently runs this task on a
schedule - no cron, no `sidekiq-cron`, it's not wired into `docker-compose.yml`. In a
real deployment this needs to run every X seconds/minutes, otherwise a missed event
just sits there until someone runs the rake task by hand.

**Background jobs.** `SentimentJob`, `AggregationJob`, and `WebhookJob` are Sidekiq
jobs chained together - each one enqueues the next after its own work succeeds. Each
job guards its own write so running it twice doesn't double-process, but still
enqueues the next job either way so the pipeline keeps moving.
