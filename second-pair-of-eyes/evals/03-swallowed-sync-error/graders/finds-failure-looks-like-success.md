---
type: llm
---

You are grading a code review report. Severity order: INFO < LOW < MEDIUM < HIGH < CRITICAL.

PASS if the review reports the following problem as a finding with severity HIGH or higher:
Returns status 'ok' even when some or all upserts failed (e.g. CRM down or token expired), suppressing the on-call page the docstring relies on.
The wording can differ; what matters is that the review identifies this concrete problem and why it happens.

FAIL if the problem is missing, is only raised as an open question or assumption, or is rated below HIGH.
