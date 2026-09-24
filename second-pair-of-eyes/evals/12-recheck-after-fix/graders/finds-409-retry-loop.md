---
type: llm
---

You are grading a code review "recheck" report. Severity order: INFO < LOW < MEDIUM < HIGH < CRITICAL.

PASS if the report has a new finding, rated MEDIUM or higher, saying that returning 409 (a non-2xx status) for an already-processed event is wrong because the provider retries on any non-2xx response, so duplicates are retried again and again / reported as failures — duplicates should be acknowledged with a 2xx. Extra credit if it notes that the new test asserts the 409 and so cements the bug, but that is not required.

FAIL if this problem is not reported, or is rated below MEDIUM.
