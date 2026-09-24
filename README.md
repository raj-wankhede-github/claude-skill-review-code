# second-pair-of-eyes — a Claude Code skill

`/second-pair-of-eyes` reviews your changes right before you commit, merge or release, as if
another engineer had written them. It doesn't ask "is this code good?" — it looks for what the
author missed: bugs, hidden assumptions, edge cases, regressions, security holes, data-integrity
and concurrency problems, production risks, contract breaks and missing tests.

It works with any language, framework or project type, with or without git, and it is
**read-only**: it never edits, fixes or rewrites your code unless you ask for that afterwards.

## How it works

1. **Resolves what to review:** uncommitted changes (including untracked files), staged changes,
   a branch, a commit range, a PR, or paths.
2. **Collects the stated intent:** your request, the PR description, commit messages, the branch
   name, and linked tickets (GitHub issues, Trello cards, and others when a read tool for that
   tracker is available).
3. **Hands the review to an independent reviewer:** a fresh subagent that has never seen the
   author's reasoning. That matters most when Claude wrote the code in the same conversation. The
   reviewer gets *what the change should do*, never *why it was built this way*.
4. **The reviewer:**
   - checks the change against the stated intent: what's missing, and what changed without
     being mentioned;
   - applies the team's own review rules (`REVIEW.md`, PR template, `CONTRIBUTING.md`, ADRs);
   - checks git history for fixes the change undoes;
   - scans diff hygiene: secrets, debug leftovers, focused or skipped tests, stray files;
   - traces callers and data paths, goes through 12 review dimensions and a set of adversarial
     scenarios, and tries to disprove every finding before reporting it.
5. **The coordinator spot-checks** every HIGH and CRITICAL citation against the code, delivers
   the report, and saves a copy for a later recheck.

## Install

This is a plain Claude Code skill, not a plugin. Clone the repository and copy the skill folder,
evals included, into your user skills directory (available in every repository):

```sh
git clone https://github.com/raj-wankhede-github/claude-skill-review-code.git
cp -r claude-skill-review-code/second-pair-of-eyes ~/.claude/skills/
```

Or copy it into one repository's `.claude/skills/` to share it with that project's team. To
update, `git pull` in the clone and run the `cp` command again. The evals are never loaded
during a review.

## Usage

```text
/second-pair-of-eyes                          # all uncommitted changes (incl. untracked), deep mode
/second-pair-of-eyes staged                   # only what's staged for commit
/second-pair-of-eyes quick                    # high-impact correctness/security/reliability only
/second-pair-of-eyes security                 # authz, injection, secrets, data exposure, ...
/second-pair-of-eyes production main..HEAD    # reliability, scale, observability, deploy risks
/second-pair-of-eyes tests src/billing/       # missing test scenarios and regression risk
/second-pair-of-eyes ai                       # prompt injection, tool execution, RAG, agent loops, cost
/second-pair-of-eyes PR 42                    # a GitHub PR (needs gh)
/second-pair-of-eyes recheck                  # after fixing: status of each earlier finding + new issues
/second-pair-of-eyes --visual                 # also an HTML report (private Artifact when available)
/second-pair-of-eyes --save docs/review.md    # also write the Markdown report to a path
/second-pair-of-eyes --inline                 # skip the independent reviewer (cheaper, less independent)
```

Plain language works too: "give this a second pair of eyes before I merge", "what did I miss in
my changes?", "I fixed the findings, check again".

## What you get

```text
# Second Pair of Eyes Review
Reviewed / Mode / Commit / Reviewer / finding counts
## Summary
## Intent vs. Implementation     # each stated requirement: implemented / partially / missing
## Findings                      # [CRITICAL|HIGH|MEDIUM|LOW|INFO], typed, file:line, problem,
                                 # impact, trigger, suggested direction (+ rule / history refs)
## Diff Hygiene
## Things I Specifically Checked # incl. which team rules applied and what history was checked
## Test Gaps
## Questions / Assumptions       # what couldn't be verified, kept apart from defects
## What Looks Solid
```

A recheck produces a status table for every earlier finding (resolved, partially resolved,
still open, no longer applicable). Its new findings are marked as either *introduced by the fix*
or *missed previously*.

## Saved reports

Every review is saved to `~/.second-pair-of-eyes/reviews/<repo>/<timestamp>-<target>.md`,
outside your repository. The file starts with a metadata header: the reviewed HEAD, plus a
working-tree snapshot for uncommitted changes, made with `git stash create`. That command stores
a commit object without touching your working tree, index or stash list. The header lets
`recheck` show exactly what changed since the review, even in a new session.

## Evals

`second-pair-of-eyes/evals/` holds 12 test cases. Each one builds a small fixture repo with a
planted problem, or a clean change. They run with Claude Code's built-in eval runner, which
works on a plain skill folder; despite the command name `claude plugin eval`, no plugin is
involved.

| Case | Tests |
| ---- | ----- |
| 01 webhook double credit | idempotency / duplicate delivery |
| 02 IDOR invoice | missing ownership check (security mode) |
| 03 swallowed sync error | failure reported as success (natural-language trigger) |
| 04 pagination skip | off-by-one on 1-based pages |
| 05 renamed response field | contract break with an in-repo consumer |
| 06 clean refactor · 07 clean validation | **false positives**: must stay quiet |
| 08 diff hygiene | leaked token in debug print, un-ignored `.env`; the secret must not be echoed |
| 09 reverted fix | git history: removes an incident fix |
| 10 intent mismatch | branch misses half of its ticket and weakens the password policy (natural-language trigger) |
| 11 team rules | violates `REVIEW.md` rules |
| 12 recheck after fix | recheck statuses + a bug introduced by the fix |

Run the evals from the repository root:

```sh
claude plugin eval ./second-pair-of-eyes --scaffold --allow-tools "Bash(git *)" --judge-model sonnet
# one case, one run, no baseline — cheap iteration:
claude plugin eval ./second-pair-of-eyes --scaffold --allow-tools "Bash(git *)" --case 09-reverted-fix --runs 1 --ablation none
```

- **Scaffold scripts:** `--scaffold` runs each case's `scaffold.sh` (plain bash + git) to build
  the fixture repo.
- **Sandbox:** because the skill needs Bash (for git), eval runs use Claude Code's OS sandbox.
  That means macOS, Linux (with `bubblewrap` and `socat`), or WSL2. Native Windows can't run
  them.
- **Baseline:** by default every case also runs without the skill. The `Δ` column shows what the
  skill adds over a plain review.
- **Judge model:** use `--judge-model sonnet`. The reports are long, and the default small judge
  is noisier.

## Layout

```text
second-pair-of-eyes/                  # the skill folder — this is what gets installed
├── SKILL.md                          # coordinator: target, intent brief, independent reviewer, delivery
├── references/
│   ├── review-procedure.md           # what the reviewer does: rules, history, hygiene, intent check, tracing
│   ├── review-dimensions.md          # 12 review dimensions, AI/LLM checks, adversarial scenarios
│   ├── output-format.md              # report structure, finding template, severity + type definitions
│   ├── recheck.md                    # saved-report metadata, finding the previous review, recheck format
│   └── reports.md                    # --save / --visual file handling
├── assets/
│   └── report-template.html          # template for --visual
└── evals/                            # test suite, never loaded during a review (results/ is git-ignored)
```

## Permissions

These are pre-approved:
- read-only `git` commands, `git stash create`, and `gh pr view/diff` / `gh issue view`;
- writes to `~/.second-pair-of-eyes/reviews/`.

If the reviewer wants to run your tests, linter or type checker, Claude Code asks you first. The
skill never deploys, migrates, installs, commits, pushes, or writes to tickets or PRs.

## License

[MIT](LICENSE) © 2026 Raj Wankhede
