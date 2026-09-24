# Output format

Write the review in the chat, in Markdown, with exactly this structure. Do not add a score, a
grade, or a generic "looks good" / "LGTM". Keep prose tight — the reader is about to merge.

```markdown
# Second Pair of Eyes Review

**Reviewed:** <target — e.g. "uncommitted changes (4 files, +212/−38)", "branch feat/refunds vs main (7 commits)", "PR #42", "src/billing/">
**Mode:** <deep | quick | security | production | tests | ai> · **Commit:** <short HEAD SHA, or "no git"> · **Reviewer:** <independent (fresh context) | inline (same context)>
**Findings:** <n CRITICAL · n HIGH · n MEDIUM · n LOW · n INFO>

## Summary

<2–5 sentences: what the change appears to do and why (say if the intent is inferred), which
components it touches, and the main risk areas found. If there are no findings above LOW, say
plainly that you found no significant problems and point to what was checked.>

## Intent vs. Implementation

**Stated intent:** <one line, with sources — "PR #42 body, commit a1b2c3d, Trello card 85" — or "none found; inferred from the code">

| Requirement | Status | Evidence |
| ----------- | ------ | -------- |
| <requirement from the intent> | Implemented / Partially / Missing / Can't verify | `path:line` — one line |

**Not mentioned in the stated intent:** <changes the intent doesn't explain, one line each with location — or "nothing significant">

<Keep this to the table and one list. Missing/partial core requirements and risky unannounced
changes also appear as Findings. For an inferred intent, one or two lines instead of the table.>

## Findings

<ordered CRITICAL → HIGH → MEDIUM → LOW → INFO; see finding template below.
If none: "No findings." — then the rest of the report still shows what was checked.>

## Diff Hygiene

<compact bullets for minor leftovers that aren't worth a full finding, e.g.
- `notify/slack.py:17-19` — commented-out old request code.
- `api/views.py:42` — `print()` debug statement.
Items that are serious (secrets, leaking debug output, disabled tests) are Findings instead.
"Clean." if nothing.>

## Things I Specifically Checked

<bullets: area — what you did and concluded, e.g.
- Authorization — every new route in `api/refunds.py` goes through `require_role("finance")`, same as existing routes.
- Retry duplication — traced `RefundWorker.handle` from SQS delivery to the DB write; idempotency key is checked before the Stripe call.
Always include:
- Team rules — which rules files were applied (`REVIEW.md`, PR template, …), or "none found".
- History — what was checked in git history for removed/rewritten logic, or why it was skipped.
Also note what got only a light pass or was out of scope.>

## Test Gaps

<bullets: a concrete scenario + why it matters + where the test would go, e.g.
- Refund requested twice for the same payment (duplicate SQS delivery) — the idempotency guard in `worker.py:88` is the only thing preventing a double refund and nothing tests it. `tests/test_worker.py`.
Only relevant gaps. Omit the section body with "None significant." if there are none.>

## Questions / Assumptions

<bullets, each marked as a question or an assumption, e.g.
- Assumption: `/internal/*` routes are only reachable from inside the VPC — I could not verify this from the repository; if they are public, finding 2 becomes CRITICAL.
- Question: is `amount` allowed to be null for legacy orders? `Order.amount` is nullable in the schema (`models.py:41`) but the new code dereferences it unconditionally.>

## What Looks Solid

<2–5 short bullets, only with evidence. Skip the section if there is nothing specific to say.>
```

## Finding template

```markdown
### [SEVERITY] Short, specific title

**Type:** Confirmed defect | Likely risk | Missing test | Design concern | Optional improvement  <append "· pre-existing" if not introduced by this change>
**Location:** `path/to/file.ext:line` <more locations if the same root cause spans several>
<optional: **Rule:** `REVIEW.md:3` — when a team rule is violated · **History:** `a1b2c3d fix: …` — when the change undoes an earlier fix>

**Problem:**
The concrete issue, in terms of this code.

**Why it matters:**
The impact — who or what is affected, and how badly.

**How it can happen:**
The input, state or sequence of events that triggers it. Concrete enough that the author can
reproduce or disprove it.

**Suggested direction:**
What to investigate or change, in a sentence or two. Not a rewrite.
```

For a *Likely risk*, end **How it can happen** with *"To confirm: <one concrete check>"* — a test
to write, a query to run, a config value to look up, a doc page to read.

## Severity

| Severity | Use when |
| -------- | -------- |
| **CRITICAL** | A serious issue that could cause a security breach, data loss or corruption, broken system integrity, or major production impact — and the triggering conditions are realistic. |
| **HIGH** | A likely or significant defect that should be fixed before submission/release: wrong results on reachable paths, failures that corrupt state, broken contracts with real consumers, security issues with limited reach. |
| **MEDIUM** | A meaningful correctness, reliability, maintainability or test-gap issue that should be fixed or consciously accepted: narrow-trigger bugs, missing handling of plausible failures, missing tests for risky behavior. |
| **LOW** | A minor issue with limited impact. |
| **INFO** | An observation, uncertainty or question that is not necessarily a defect. |

Don't inflate. A *Likely risk* is usually at most one level below what it would be if confirmed,
and the Questions / Assumptions section should say what would raise it.

## Types (Rule 8 — don't confuse improvements with defects)

| Type | Meaning |
| ---- | ------- |
| Confirmed defect | You traced the code and it *will* misbehave under a stated, reachable condition. |
| Likely risk | Probable problem that depends on something not verifiable here (runtime config, library semantics, data). Includes the check that would confirm it. |
| Missing test | Specific risky behavior with no test that would catch a regression. (Minor gaps go in Test Gaps only; promote to a finding when the untested behavior is high-risk.) |
| Design concern | Works today, but the structure makes a defect likely (fragile coupling, duplicated rule that will drift, API easy to misuse). |
| Optional improvement | Not a defect. Use sparingly; usually LOW or INFO. |

Unresolved assumptions are not findings — they go in **Questions / Assumptions**.

## Mode adjustments

- **quick:** Findings (HIGH/CRITICAL only, plus anything CRITICAL-adjacent you noticed), a short
  Things I Checked, Questions only if they could change a finding's severity. Intent vs.
  Implementation shrinks to one line unless a requirement is missing. Skip Diff Hygiene (serious
  hygiene items are still Findings) and What Looks Solid.
- **recheck:** a different structure — see `recheck.md`.
- **tests:** Test Gaps is the main section — group gaps by component, and for each say which
  existing test comes closest and why it wouldn't catch the problem. Findings hold only actual
  defects you ran into.
- **security / production / ai:** same structure; Things I Checked lists the focus-area checks
  explicitly, so the reader can see coverage.

## Style

- Refer to code as `path:line` (clickable), with the symbol name when it helps.
- Quote at most a few lines of code in a finding, only when the exact text is the point.
- Speak to the code, not the author ("this handler retries…", not "you forgot…").
- No secret values, ever — name the variable and the file instead.
