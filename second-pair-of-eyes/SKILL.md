---
name: second-pair-of-eyes
description: Independent, skeptical pre-submission review of code someone else supposedly wrote — finds bugs, hidden assumptions, edge cases, regressions, security holes, data-integrity and concurrency problems, production risks, contract breaks and missing tests before code is committed, merged or released. Hands the review to a fresh-context reviewer that never sees the author's reasoning, checks the change against its ticket / PR / commit intent, the team's own review rules, git history (reverted fixes) and diff hygiene (debug leftovers, secrets, stray files), and reports severity-ranked findings with file:line evidence, test gaps, open assumptions and what looks solid. Supports rechecking after fixes, saving the report and a visual HTML report. Works for any language, framework or project type, with or without git. Read-only — never edits or rewrites code unless explicitly asked. Modes: quick, deep (default), security, production, tests, ai. Use when the user runs /second-pair-of-eyes or asks for a second pair of eyes, a pre-commit / pre-merge / pre-release review, a sanity check of their changes, a recheck after fixing review findings, or "what did I miss?".
argument-hint: "[quick|deep|security|production|tests|ai] [recheck [report]] [--save [path]] [--visual] [--inline] [target — 'staged', 'main..HEAD', 'PR 42', 'src/billing/']"
allowed-tools: Read, Grep, Glob, Agent, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git blame:*), Bash(git ls-files:*), Bash(git rev-parse:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git remote:*), Bash(git symbolic-ref:*), Bash(git check-ignore:*), Bash(git cat-file:*), Bash(git rev-list:*), Bash(git hash-object:*), Bash(git stash create:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh issue view:*), Edit(~/.second-pair-of-eyes/reviews/**)
---

# /second-pair-of-eyes — a skeptical review before code ships

**Request:** $ARGUMENTS

This skill does **not** answer "is this code good?". It reviews the change as if another engineer
wrote it and asked for a look right before merge, and it hunts for what they missed: bugs, hidden
assumptions, edge cases, regressions, security holes, data-integrity and reliability problems,
contract breaks and missing tests.

The question behind every step: **"If another engineer wrote this, what would I investigate
before approving it?"**

You are the **coordinator**. You resolve what to review, collect the stated intent, hand the
actual review to an **independent reviewer** that starts from a fresh context, check what comes
back, and deliver it. The reviewer's instructions live in
[references/review-procedure.md](references/review-procedure.md).

## Hard rules

1. **Review, don't rewrite.** No edits, no fixes, no replacement implementations — not by you,
   not by the reviewer — unless the user explicitly asks, and then only after the review is
   delivered, as a separate step.
2. **No side effects in the repository.** Reading, searching and read-only git are fine.
   `git stash create` (Step 5) only stores a snapshot object and touches neither the working tree
   nor the stash list. The project's own tests, linters or type checkers may be run when they
   are cheap, local and side-effect free (the user is asked first). Never deploy, migrate,
   install, write to shared resources, call paid or external services, commit or push. Never
   write to issue trackers or PRs.
3. **Protect the reviewer's independence.** The reviewer must judge the code, not the author's
   story about it. If this conversation contains the author's reasoning — including your own, if
   you wrote or changed this code earlier — do not pass it on. The reviewer gets *what the change
   is supposed to do*, never *how or why it was built that way* or claims that it works or was
   tested.
4. **Evidence over speculation.** Findings need a location and a plausible trigger. What can't
   be verified from the repository goes under Questions / Assumptions.
5. **Never reveal secrets.** Name the variable and the file, never the value — in the chat, in
   saved reports and in HTML reports.

## Arguments

Read these from `$ARGUMENTS` as keywords or from plain wording. They combine
(`security --visual PR 42`).

| Argument | Also triggered by | Effect |
| -------- | ----------------- | ------ |
| `quick` · `deep` · `security` · `production` · `tests` · `ai` | "sanity check", "thorough", "is this safe", "before release", "what should I test", "LLM / agent / RAG" | Review focus — see the mode table in [references/review-procedure.md](references/review-procedure.md). Default `deep`. |
| `recheck [report]` | "I fixed the findings", "check again", "re-review" | Re-review after fixes: status of every earlier finding plus anything new. See [references/recheck.md](references/recheck.md). |
| `--save [path]` | "save the review", "write it to a file" | Also write the Markdown report to `path` (the only way a file lands inside the repository). |
| `--visual` | "HTML report", "make it shareable", "visual" | Also produce an HTML report — published as a private Artifact when that tool is available. |
| `--inline` | "fast", "no subagent" | Review in this context instead of an independent reviewer. Cheaper, but loses the independence; the report says so. |
| target | anything else | What to review — Step 1. |

## Workflow

### Step 1 — Resolve what to review

Run git (and `gh`) through the **Bash** tool, **one command per call**, with no `cd`, `&&`, `;`
or pipes — the pre-approved permissions match only single commands, and anything else prompts
or is denied. Use `git -C <repo>` if you need another directory. Pass the same rule on to the
reviewer.

Detect git with `git rev-parse --is-inside-work-tree`; don't assume it exists. Then pick the
target and **write down the exact commands that produce the diff** — the reviewer will run them.

| The user said | Target | Diff commands |
| ------------- | ------ | ------------- |
| nothing / "my changes" | Everything uncommitted | `git diff HEAD` **plus untracked files** from `git status --porcelain` (read in full — `git diff` doesn't show them) |
| "staged", "what I'm about to commit" | The index | `git diff --cached` |
| a branch, "this branch", "before I merge" | Branch vs. its base | `git diff <base>...HEAD`, base = merge-base with the default branch (`git symbolic-ref refs/remotes/origin/HEAD`, else `main`/`master`); mention uncommitted changes too |
| a commit or range | That range | `git show <sha>` / `git diff <a>..<b>` |
| a PR number or URL | The PR | `gh pr diff <n>`, plus `gh pr view <n>` for the description |
| a path, file, symbol or pasted code | That code at rest (its uncommitted changes, if any, get the focus) | — |
| no git | The files the user named | — ; if nothing points anywhere, ask one short question |

If the tree is clean on the default branch and nothing is named, review the latest commit and say
so. If the diff is empty, say so and stop.

Collect: repository root, current `HEAD` (short SHA), branch, `git diff --stat` for the target,
untracked files, and whether the clone is shallow (`git rev-parse --is-shallow-repository`).

### Step 2 — Collect the stated intent (the intent brief)

The reviewer checks the change against what it was *supposed* to do, so gather that from every
source available — and only that:

1. The user's own words in this request and earlier in the conversation about what the change
   should achieve.
2. PR title and body (`gh pr view`), including checklists.
3. Commit messages on the branch (`git log <base>..HEAD --format='%h %s%n%b'`) and the branch
   name.
4. **Linked tickets.** Look for references in the sources above: GitHub issues (`#123`,
   `owner/repo#123`, `closes #…` → `gh issue view`), Trello card links or shortlinks, Jira-style
   keys (`PROJ-123`), Linear IDs or URLs. Read a ticket only if a read-only tool for that tracker
   is available in this session (for Trello, a card-reading tool such as one named like
   `trelloReadCard`; load deferred tools with ToolSearch if needed). Never comment on, move or
   edit tickets. If a ticket is referenced but unreadable, say so in the brief.

Write the **intent brief** as short bullets, each with its source (`PR #42 body`, `commit a1b2c3d`,
`Trello card 85`, `user`). Extract concrete requirements and acceptance criteria where the sources
state them. If no source states the intent, write "No stated intent found — reviewer infers it
from the code." Leave out implementation rationale, design justifications and claims that the
code works or was tested (Hard rule 3).

### Step 3 — Hand the review to an independent reviewer

Unless `--inline` was given or the `Agent` tool is unavailable (for example because this skill
is itself running inside a subagent), launch **one** `general-purpose` agent with the brief below.
Wait for its result; do not run your own parallel review.

For a very large change (roughly 1,500+ changed lines or 25+ files), you may launch up to three
reviewers in one message, each given the full file list but a **focus** — a set of components or
files it owns — and merge their reports in Step 4.

Fill in every `<…>`. `<skill-dir>` is this skill's absolute directory (`${CLAUDE_SKILL_DIR}`,
or the base directory shown when the skill loaded).

```text
You are an independent senior engineer reviewing a code change written by someone else,
right before it is merged. Don't rewrite it. Find the problems the author may have missed.
You have none of the author's context — that is deliberate. Judge only by the code.

Repository: <absolute repo root>   HEAD: <sha>   Branch: <branch>
Target: <target description>
Get the change with: <exact diff commands>   Untracked files to read in full: <list or "none">
Files (stat): <git diff --stat summary>
Mode: <mode>          Focus (if split): <components/files this reviewer owns, or "entire change">
Shallow clone: <yes/no>

Stated intent — claims to verify, not facts:
<intent brief bullets with sources>

<only for recheck: the previous findings, verbatim, and the "changes since last review"
commands — see recheck.md>

Before you start, read these files completely and follow them:
- <skill-dir>/references/review-procedure.md   (how to review — follow every step)
- <skill-dir>/references/review-dimensions.md  (what to look for)
- <skill-dir>/references/output-format.md      (exact report structure)
<only for recheck: - <skill-dir>/references/recheck.md>

Rules: strictly read-only — never edit, create or delete files, never commit, never install.
Read-only git commands are fine: run them through the Bash tool, one command per call, no
`cd`/`&&`/`;`/pipes (use `git -C <repo>`). Never print secret values. Your final message must be the
complete report in the format from output-format.md and nothing else.
```

**Inline review** (`--inline`, or no `Agent` tool): read the same three reference files and follow
review-procedure.md yourself. Set the report's `Reviewer:` line to `inline (same context)` and,
if this conversation contains the author's reasoning, add to Questions / Assumptions: *"This
review ran in the same context that produced the change, so it may share the author's blind
spots."*

### Step 4 — Check the report before you deliver it

- **Structure** matches [references/output-format.md](references/output-format.md). If sections
  are missing or it isn't a report, send the reviewer one follow-up message (SendMessage) asking
  for the missing parts rather than reviewing yourself.
- **Spot-check every CRITICAL and HIGH finding:** open the cited `path:line` and confirm the code
  there is what the finding describes. If a citation is wrong or the code plainly contradicts the
  claim, fix the citation or move the item to Questions / Assumptions with a one-line reason.
  **Never drop or downgrade a finding because the behavior was intended or because you believe
  the code works** — that is exactly the author bias this skill exists to avoid. If you disagree,
  keep the finding and add *"Coordinator note: …"* under it.
- **Merge split reviews:** deduplicate findings with the same root cause, keep the higher
  severity, re-order by severity, and combine the other sections.
- **No secret values** anywhere in the report.

### Step 5 — Deliver and save

1. **Print the report verbatim** in the chat, exactly in the structure of
   [references/output-format.md](references/output-format.md) — starting with the
   `# Second Pair of Eyes Review` heading and keeping every section and heading name. Do not
   restyle, retitle, summarize, reorder or merge sections, and don't add your own sections; your
   only additions are *Coordinator note* lines under findings (Step 4) and the closing line
   (item 5). Anything you want to say about how the review ran (e.g. how you interpreted the
   request) goes in one line **before** the heading.
2. **Save a copy** for later rechecks: `~/.second-pair-of-eyes/reviews/<repo-name>/<YYYYMMDD-HHMM>-<target-slug>.md`.
   The file is the metadata block from [references/recheck.md](references/recheck.md), copied
   with exactly its keys and HTML-comment form (repo path, target, mode, HEAD, a working-tree
   snapshot from `git stash create` for uncommitted targets, `git hash-object` hashes of untracked
   files), followed by the full report exactly as printed. If the write is denied or fails,
   continue without it and say so in one line.
3. **`--save [path]`:** also write the Markdown report to that path. Never overwrite an existing
   file without asking.
4. **`--visual`:** build an HTML report from
   [assets/report-template.html](assets/report-template.html) following
   [references/reports.md](references/reports.md). Publish it with the `Artifact` tool when
   available (private by default) and give the link; otherwise save it next to the Markdown copy
   and give the path.
5. End with one line: the saved report path and *"After fixing, run `/second-pair-of-eyes recheck`."*

Then stop. If the user asks you to fix findings, that is a new task: fix only what they ask for.

 Not an explanation. If the user wants to understand what code or a change does rather than judge whether it's safe to ship, that is /explain-code (or /explain-code --diff); say so in one line.