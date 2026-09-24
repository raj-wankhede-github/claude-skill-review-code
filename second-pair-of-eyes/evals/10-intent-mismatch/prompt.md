---
description: "Branch review. The commit message (ticket PROJ-7) says emails are normalized on signup AND login; only signup is. The branch also silently lowers MIN_PASSWORD_LENGTH from 8 to 6, which the stated intent never mentions."
expected_outcome: "login() does not normalize the email, so the exact bug from PROJ-7 remains (and gets worse: a user who signs up as Ada@Example.com is now stored lowercase and can no longer log in with the original casing).; MIN_PASSWORD_LENGTH lowered from 8 to 6 \u2014 a security-relevant change unrelated to and not mentioned by the stated intent.; Existing accounts stored with mixed-case keys are not migrated; after normalization they can't be found / duplicates become possible."
tags: ["core", "intent"]
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
---

Before I merge this branch, give it a second pair of eyes.
