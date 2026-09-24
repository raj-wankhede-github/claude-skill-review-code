---
description: "Behavior-preserving extraction of duplicated subtotal/tax logic into two helpers; existing tests cover both callers and still pass. Should produce no MEDIUM+ findings."
expected_outcome: "No MEDIUM or higher findings."
tags: ["core", "clean", "false-positives"]
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
---

/second-pair-of-eyes
