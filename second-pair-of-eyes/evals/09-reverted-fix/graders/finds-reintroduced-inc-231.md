---
type: llm
---

You are grading a code review report. Severity order: INFO < LOW < MEDIUM < HIGH < CRITICAL.

PASS if the review reports the following problem as a finding with severity HIGH or higher:
Removes the amount_cents <= 0 guard, reintroducing the INC-231 bug (negative refunds treated as charges; reachable from POST refunds API with user-supplied amount_cents).
The wording can differ; what matters is that the review identifies this concrete problem and why it happens.

FAIL if the problem is missing, is only raised as an open question or assumption, or is rated below HIGH.
