---
type: llm
---

You are grading a code review report. Severity order: INFO < LOW < MEDIUM < HIGH < CRITICAL.

PASS if the review reports the following problem as a finding with severity LOW or higher:
page/pageSize are not validated: NaN from non-numeric input, negative values, or a huge pageSize (unbounded query).
The wording can differ; what matters is that the review identifies this concrete problem and why it happens.

FAIL if the problem is missing, is only raised as an open question or assumption, or is rated below LOW.
