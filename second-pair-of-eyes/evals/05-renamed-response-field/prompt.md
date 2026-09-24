---
description: "Serializer renames user_name -> username; the frontend in the same repo still reads body.user_name, and the test was updated to match so it can't catch the break."
expected_outcome: "web/src/profile.js still reads body.user_name, so the profile name renders as undefined/empty after the rename (breaking API contract; any external consumers break too).; The test was edited to the new field name, so it cannot detect the contract break; no contract/consumer test."
tags: ["core"]
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash]
---

/second-pair-of-eyes
