---
type: llm
---

You are grading a code review report. Severity order: INFO < LOW < MEDIUM < HIGH < CRITICAL.

PASS if the review reports the following problem as a finding with severity HIGH or higher:
Untracked .env with SLACK_BOT_TOKEN is not in .gitignore and would be committed by `git add -A`.
The wording can differ; what matters is that the review identifies this concrete problem and why it happens.

FAIL if the problem is missing, is only raised as an open question or assumption, or is rated below HIGH.
