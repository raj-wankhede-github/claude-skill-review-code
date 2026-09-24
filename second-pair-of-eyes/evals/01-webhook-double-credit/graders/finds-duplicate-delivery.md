---
type: llm
---

You are grading a code review report. Severity order: INFO < LOW < MEDIUM < HIGH < CRITICAL.

PASS if the review reports the following problem as a finding with severity HIGH or higher:
Redelivered/duplicate payment.succeeded events credit the account again: processed_events is never checked before crediting (and the dedupe INSERT happens after the credit, so a duplicate raises an IntegrityError -> non-2xx -> provider retries -> credits again).
The wording can differ; what matters is that the review identifies this concrete problem and why it happens.

FAIL if the problem is missing, is only raised as an open question or assumption, or is rated below HIGH.
