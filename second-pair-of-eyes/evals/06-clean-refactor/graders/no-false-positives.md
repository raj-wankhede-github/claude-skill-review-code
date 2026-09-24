---
type: llm
weight: 2
---

You are grading a code review of a change that is known to be correct: Behavior-preserving extraction of duplicated subtotal/tax logic into two helpers; existing tests cover both callers and still pass. Should produce no MEDIUM+ findings.

PASS if the review reports no finding with severity MEDIUM, HIGH or CRITICAL that claims a defect or likely risk in this change. LOW or INFO findings, test gaps, questions and notes are fine.

FAIL if the review reports any MEDIUM, HIGH or CRITICAL finding.
