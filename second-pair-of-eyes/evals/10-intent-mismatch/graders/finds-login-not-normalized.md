---
type: llm
---

You are grading a code review report. Severity order: INFO < LOW < MEDIUM < HIGH < CRITICAL.

PASS if the review reports the following problem as a finding with severity HIGH or higher:
login() does not normalize the email, so the exact bug from PROJ-7 remains (and gets worse: a user who signs up as Ada@Example.com is now stored lowercase and can no longer log in with the original casing).
The wording can differ; what matters is that the review identifies this concrete problem and why it happens.

FAIL if the problem is missing, is only raised as an open question or assumption, or is rated below HIGH.
