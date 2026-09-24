---
description: "Express route returns any invoice by id to any logged-in user (no ownership check), unlike the list route which filters by req.user.id."
expected_outcome: "GET /invoices/:id does not check invoice.userId === req.user.id, so any authenticated user can read other users' invoices (IDOR / broken object-level authorization).; No test that a user is denied another user's invoice."
tags: ["core"]
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
---

/second-pair-of-eyes security
