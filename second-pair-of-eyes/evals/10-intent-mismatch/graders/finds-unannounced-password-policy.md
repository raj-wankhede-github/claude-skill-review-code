---
type: llm
---

You are grading a code review report. Severity order: INFO < LOW < MEDIUM < HIGH < CRITICAL.

PASS if the review reports the following problem as a finding with severity MEDIUM or higher:
MIN_PASSWORD_LENGTH lowered from 8 to 6 — a security-relevant change unrelated to and not mentioned by the stated intent.
The wording can differ; what matters is that the review identifies this concrete problem and why it happens.

FAIL if the problem is missing, is only raised as an open question or assumption, or is rated below MEDIUM.
