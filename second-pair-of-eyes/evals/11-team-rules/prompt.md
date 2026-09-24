---
description: "Repo has a REVIEW.md with team rules. The change parses price as float (rule 1) and adds an endpoint without documenting it in docs/api.md (rule 2). Also: the price comes from the client at all."
expected_outcome: "price parsed with float(), violating REVIEW.md rule 1; mixing float into Decimal arithmetic makes get_cart raise TypeError (Decimal * float / sum) or lose precision.; POST /cart/items not added to docs/api.md, violating REVIEW.md rule 2.; The review attributes the rule findings to REVIEW.md.; Price is taken from the request body instead of the catalog, so clients can set their own price."
tags: ["core", "team-rules"]
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
---

/second-pair-of-eyes
