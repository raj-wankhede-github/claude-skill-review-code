---
description: "New pagination treats page as 0-based (offset = page * pageSize) while the default and the storefront use 1-based pages, so the first 20 products are never shown. pageSize is unbounded and unvalidated."
expected_outcome: "offset = page * pageSize with 1-based pages (default 1, storefront sends page=1) skips the first page of products.; page/pageSize are not validated: NaN from non-numeric input, negative values, or a huge pageSize (unbounded query).; No tests for page 1 / page boundaries."
tags: ["core"]
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
---

/second-pair-of-eyes
