---
description: "Python webhook handler starts crediting accounts on payment.succeeded without checking whether the event was already processed."
expected_outcome: "Redelivered/duplicate payment.succeeded events credit the account again: processed_events is never checked before crediting (and the dedupe INSERT happens after the credit, so a duplicate raises an IntegrityError -> non-2xx -> provider retries -> credits again).; credit_account commits before processed_events is written, and the balance update is a read-modify-write without a lock/transaction, so concurrent deliveries or a crash between the two writes leave inconsistent state.; No test for delivering the same event twice."
tags: ["core"]
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
---

/second-pair-of-eyes
