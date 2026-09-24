---
type: llm
---

You are grading a code review report.

PASS if the review lists the following as a test gap (in a Test Gaps section) or as a finding: No regression test for zero/negative refund amounts (which is why the removal went unnoticed).
The wording can differ; the review must name this specific missing scenario, not just "add more tests".

FAIL if this specific scenario is not mentioned as missing.
