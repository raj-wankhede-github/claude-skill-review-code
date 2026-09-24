# Saved reports and rechecks

## Saved report metadata (coordinator, Step 5)

Every saved review starts with this block, so a later recheck knows exactly what was reviewed.
Fill what applies; write `-` for the rest.

```markdown
<!-- second-pair-of-eyes
repo: <absolute repo root>
target: <uncommitted | staged | branch <name> vs <base> | range <a>..<b> | PR <n> | paths <…>>
diff: <the exact diff commands the reviewer ran>
mode: <mode>
date: <YYYY-MM-DD HH:MM>
head: <full HEAD SHA>
snapshot: <SHA from `git stash create` for uncommitted/staged targets — tracked files only; "-" if the tree was clean or no git>
untracked: <path=<git hash-object path>, … — or "-">
-->
```

`git stash create` writes a commit object of the current working tree into `.git` and prints its
SHA; it does not change the working tree, the index or the stash list. It returns nothing when
there are no tracked changes (write `-`). The object is unreferenced, so it survives until git
garbage-collects it (usually weeks) — long enough for a recheck.

## Finding the previous report (coordinator)

In this order:
1. A path the user gave (`recheck reviews/old.md`).
2. The previous review in **this conversation**, if there is one.
3. The newest file in `~/.second-pair-of-eyes/reviews/<repo-name>/` whose `repo:` matches
   this repository (and whose `target:` matches, when the user named a target).

If nothing is found, say so and run a normal review instead.

## What changed since the last review (coordinator → reviewer brief)

Compute these commands and pass them to the reviewer with the previous findings (verbatim):

| Previous target | Changes since the last review |
| --------------- | ----------------------------- |
| uncommitted / staged, with a snapshot | `git diff <snapshot>` (working tree vs. then; includes anything committed since). For untracked files, compare `git hash-object <path>` now with the saved hash. |
| uncommitted / staged, no snapshot | `git diff <head>` — and say the baseline is approximate. |
| branch / range / PR | `git diff <old head>..HEAD` (or the PR's new commits via `gh pr view --json commits`). |
| no git, or no metadata | No reliable delta — the reviewer re-reads the cited locations and the target in full. |

The **target** of the recheck is the same as the previous review's target, now (for example: all
uncommitted changes as they are today). The reviewer still reviews the whole current target, but
spends extra attention on the changes since the last review — fixes often introduce new bugs.

## Recheck report (reviewer)

```markdown
# Second Pair of Eyes Review — Recheck

**Reviewed:** <target> · **Previous review:** <date, file or "this conversation"> · **Mode:** <mode>
**Commit:** <short SHA> · **Reviewer:** <independent (fresh context) | inline (same context)>
**Status:** <n resolved · n partially resolved · n still open · n no longer applicable · n can't verify> · <n new findings>

## Summary

<2–4 sentences: what was fixed, what remains, and whether the fixes introduced anything.>

## Previous Findings

| # | Previous finding | Severity | Status | Evidence |
| - | ---------------- | -------- | ------ | -------- |
| 1 | <title> | HIGH | Resolved / Partially resolved / Still open / No longer applicable / Can't verify | `path:line` — what changed, one line |

<For Partially resolved and Still open: a short paragraph each on what is still wrong and under
which condition. "Resolved" requires evidence in the code — a changed line, a new guard, a new
test — not a commit message saying so. "No longer applicable" means the code the finding was
about is gone and nothing replaced it with the same problem.>

## New Findings

<Full finding template from output-format.md. Mark each **Introduced by the fix** (the problem
is in code changed since the last review) or **Missed previously** (it was already there). Same
severity rules. "None." if none.>

## Test Gaps

<Remaining and new gaps only. Note gaps from the previous review that are now covered, in one line.>

## Questions / Assumptions

<Carry over the still-relevant ones and add new ones.>
```

Rules for rechecks:
- Judge each previous finding against the **current code**, not against the author's commit
  messages or claims that it was fixed.
- A fix that works for the reported scenario but not a close variant (the second duplicate
  delivery path, the other caller) is **Partially resolved**.
- Don't re-litigate a previous finding's severity unless the fix changed its impact; if you
  disagree with it, add a one-line note.
