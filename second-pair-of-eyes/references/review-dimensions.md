# Review dimensions

Go through the dimensions that apply to the change. Skip the ones that don't (a pure-function
refactor has no distributed-systems section). Each dimension lists what to look for and the
question that usually finds the bug. Everything found here still has to pass Step 5 (try to
disprove it) before it goes in the report.

Mode emphasis:

| Mode | Dimensions to go through fully | The rest |
| ---- | ------------------------------ | -------- |
| `quick` | 1, 2, 3, 4 (HIGH/CRITICAL only) | skip unless something jumps out |
| `deep` | all that apply | — |
| `security` | 4 fully, plus 2, 3, 5, 9, 12 as they touch security | skim |
| `production` | 3, 6, 7, 8, 9, 12 | skim |
| `tests` | 10 fully; use 1–9 to decide *what* needs a test | skim |
| `ai` | 12 (AI section) fully, plus 4, 7, 8 | skim |

---

## 1. Correctness

- Incorrect logic or conditions; inverted or missing checks; wrong operator precedence.
- Wrong return values, including on early-return and error paths.
- Incorrect state transitions; states that can be skipped or entered twice.
- Broken control flow: fall-through, `break`/`continue` in the wrong loop, missing `await`,
  unhandled promise, generator never consumed, `finally` that overrides a return.
- Incorrect calculations: integer division, rounding, float money, overflow, units, time zones,
  DST, off-by-one on ranges and pagination.
- Incorrect data transformations: lost fields, wrong mapping, mutated shared input, shallow vs.
  deep copy, sort stability, encoding.
- Ordering problems; relying on dict/set/map or database row order without `ORDER BY`.
- Incorrect API/library usage: wrong argument order, default that differs from what the author
  assumed, deprecated behavior, method that returns a new value instead of mutating.
- Inconsistent behavior between code paths that should agree (create vs. update, sync vs. async,
  single vs. bulk, API vs. UI vs. job).

> Can this produce the wrong result even though it works for the normal case?

## 2. Edge cases

Empty input; `null`/`None`/`undefined`; missing or extra fields; malformed input; unexpected
types; duplicates; very large and very small input; boundary values (0, 1, max, negative);
Unicode and whitespace; timeouts; retries; partial failures; concurrent requests; repeated
execution; first run (empty tables, no cache, no prior state); already-existing state; missing
configuration; expired credentials; deleted or renamed resources.

> What input or state did the author probably not try?

## 3. Error handling

- Swallowed exceptions; `catch`-all that hides bugs; errors logged and then execution continues
  as if it succeeded.
- Overly broad or wrong exception types; catching the error the caller needed to see.
- Missing validation at trust boundaries.
- Misleading error messages or status codes; failures that look like success (returning `[]`,
  `false`, `200` on error).
- Retry behavior: retrying non-idempotent operations, retrying non-retryable errors, no backoff,
  no cap.
- Timeouts: none set, or longer than the caller's own timeout.
- Fallbacks that silently serve wrong or stale data.
- Cleanup after failure: transactions rolled back, files/handles/connections/locks released,
  temp state removed, compensating actions run.

> What happens when this operation fails halfway through?

## 4. Security

Report only what the code reasonably supports; mark the rest *Likely risk* or put it in Questions.

- Authentication bypass; new endpoints or handlers without the auth the neighbors have.
- Authorization: missing ownership/tenant checks, IDOR (object ID taken from the request without
  checking it belongs to the caller), role checks on the client only, privilege widened.
- Injection: SQL/NoSQL, shell/command, template, LDAP, XPath, header, log injection; string
  building instead of parameterization.
- Path traversal and unsafe file handling (user-controlled paths, archive extraction, uploads,
  content-type trust).
- SSRF: outbound requests to user-controlled URLs.
- Unsafe deserialization (`pickle`, YAML `load`, Java/.NET serializers, `eval`).
- Sensitive data exposure: secrets or PII in logs, errors, responses, analytics, URLs; verbose
  stack traces to clients.
- Hardcoded secrets or credentials in code or config.
- Insecure configuration: CORS `*` with credentials, disabled TLS verification, debug mode, weak
  crypto, predictable tokens, missing CSRF protection where the framework expects it.
- Excessive permissions (IAM, DB roles, OAuth scopes, file modes).
- Tenant/data isolation: queries missing the tenant filter, caches keyed without the tenant.

> What happens if the caller is malicious?

## 5. Data integrity

- Incorrect updates; lost updates (read-modify-write without a lock or version check).
- Duplicate records; missing unique constraints the code relies on.
- Missing transactions or wrong transaction boundaries; external calls inside a transaction;
  writes to two stores with no way to reconcile.
- Partial writes; stale data; cache not invalidated or invalidated before the write commits.
- Idempotency of handlers, webhooks, jobs and migrations.
- Migrations: locking large tables, non-reversible changes, backfills that time out, new
  `NOT NULL` column without default, data migrated in the wrong order relative to code deploy.
- Backwards compatibility of stored data (old rows, old messages still in queues, old cache
  entries).

> Could this leave the system in a state that should never happen?

## 6. Concurrency and distributed systems

- Race conditions; check-then-act; shared mutable state (globals, module-level caches,
  singletons, class attributes).
- Duplicate processing; at-least-once delivery handled as exactly-once.
- Concurrent writes; missing or wrong locking; lock held across slow I/O; deadlock order.
- Event ordering assumptions; eventual consistency read right after write; stale reads from
  replicas.
- Distributed transaction problems (DB write + publish event, no outbox).
- Queue visibility timeout vs. processing time; ack before processing; poison messages; DLQ.
- Timeout/retry interactions across layers (client retries × server retries × queue redelivery).
- Serverless: state kept in memory between invocations, cold-start assumptions, concurrency
  limits, execution time limits.

> What happens if this runs twice, or twice at the same time?

## 7. Performance

Report only with a reasonable technical basis — expected data size, a loop over a query, a hot
path. Don't optimize prematurely.

- N+1 queries; queries or API calls inside loops.
- Unbounded retrieval: no pagination, no `LIMIT`, loading whole tables/files/buckets into memory.
- Missing indexes for new query patterns (check migrations/schema).
- Blocking I/O on an async event loop or request thread.
- Expensive computation or serialization repeated per item or per request.
- Large payloads; chatty network calls.
- LLM calls: calls in loops, oversized context, no caching of stable prompts, no token limits.

> What happens with 100× the current volume?

## 8. Reliability and production behavior

- Timeouts, retries, rate limits and backoff on every external dependency.
- Behavior during a dependency outage; graceful degradation vs. total failure.
- Resource exhaustion: connection pools, file descriptors, memory, threads, disk, queue depth.
- Connection handling: clients created per request, not closed, not reused.
- Observability: is a failure of the new path visible (logs with enough context, metrics,
  traces, alerts)? Are errors logged once, not zero or five times?
- Health checks and readiness still meaningful.
- Configuration: new env vars/flags documented, present in every environment, with safe
  defaults; behavior when missing.
- Deployment: order of deploy vs. migration, mixed old/new versions running together,
  rollback safety, feature-flag default.

> What happens immediately after deployment, and during an outage of each dependency?

## 9. API and contract compatibility

- Request/response shape changes; renamed, removed or retyped fields.
- Optional became required (or the reverse, with consumers that assume presence).
- Status codes and error contract changes.
- Serialization format changes (dates, enums, number precision, casing, null vs. missing).
- Versioning: breaking change in a versioned API without a new version.
- Downstream consumers: other services, mobile apps (old versions stay installed), frontend,
  queues, webhooks, exported files, SDKs, public libraries' semver.
- Frontend/backend assumptions that no longer match.

> Could an existing consumer break because of this change?

## 10. Tests

- Do tests exist for the changed behavior? Would they fail if the change were wrong (mutate the
  key condition mentally — does any test notice)?
- Are the assertions meaningful, or do they only assert "no exception" / a mock was called?
- Are mocks hiding the real behavior (mocked DB that can't enforce constraints, mocked HTTP that
  never times out)?
- Missing scenarios: edge cases, failure paths, authorization (the *denied* case), regression of
  the bug being fixed, concurrency/duplicates, data integrity, backward compatibility.
- Tests changed to match new behavior — was the old expectation actually wrong?

Every test gap names a specific scenario and why it matters. "Add more tests" is not a gap.

## 11. Maintainability

Only where it could realistically cause defects or slow future work — not style.

- Hidden coupling; logic duplicated in a place that will drift from the original.
- Fragile assumptions encoded implicitly (magic numbers, positional tuples, string matching on
  error messages).
- Misleading names or abstractions that invite misuse; functions that do something other than
  their name says.
- Code that is hard to test in its current shape where that already hid a bug.
- Inconsistency with an established project pattern that future engineers will trip over.

## 12. Dependencies and external services

- SDK/API assumptions: response shape, pagination, error types, rate limits, API version.
- Authentication and credential handling (rotation, expiry, scope, where stored).
- Timeouts, retries, response validation.
- New dependencies: maintained? license? pulling in something heavy for a small need? pinned?
- Lockfile changes that upgrade more than intended (major versions, transitive changes).

### AI / LLM applications (only if the repository actually uses them)

- **Prompt injection:** untrusted content (user input, retrieved documents, web pages, tool
  results, emails) concatenated into prompts that also carry instructions or tool access.
- **Untrusted model output:** model output used in SQL, shell, file paths, URLs, HTML, code
  execution or authorization decisions without validation.
- **Tools:** tool authorization checked against the *end user*, not the agent; destructive tools
  without confirmation; tool arguments not validated; scope wider than needed.
- **Agent loops:** no max iterations, no budget, no timeout, no detection of repeated calls.
- **Structured output:** parsing that assumes valid JSON/schema; no retry or fallback on
  malformed output; refusals and truncation (`max_tokens`/stop reason) not handled.
- **Grounding and RAG:** empty retrieval handled? stale or cross-tenant documents retrievable?
  chunking/embedding model mismatch between index and query? citations actually tied to sources?
- **Hallucination handling:** is the answer checked against sources where correctness matters?
- **Context handling:** context window overflow, history truncation dropping the system prompt,
  wrong role ordering, PII sent to the model or logged with prompts.
- **Cost:** tokens per request, calls in loops, missing caching, no per-user limits.
- **Model/version:** hardcoded or deprecated model IDs, parameters the model doesn't support.

---

# Adversarial scenarios

Run each relevant scenario against every important code path in the change. For each one, trace
the code and decide what actually happens — don't guess.

| Scenario | Question |
| -------- | -------- |
| Normal | What happens when everything works? Does it do what it is supposed to do? |
| Empty | What happens when there is nothing to process? |
| Invalid | What happens when input is malformed, the wrong type, or out of range? |
| Failure | What happens when a dependency fails (error, exception, non-2xx)? |
| Timeout | What happens when the dependency is slow — or succeeds after the caller gave up? |
| Duplicate | What happens if this executes twice with the same input? |
| Concurrent | What happens if two requests execute this simultaneously? |
| Scale | What happens with 100× the current volume? |
| Recovery | What state is left after a partial failure, and does a retry fix it or make it worse? |
| Security | What happens if the caller is malicious or is a different tenant/user? |
| Compatibility | What happens to existing consumers, stored data and in-flight messages? |
| Deployment | What happens in the minutes after deploy — old and new versions side by side, migration half done, config not yet set, caches full of old entries? |
