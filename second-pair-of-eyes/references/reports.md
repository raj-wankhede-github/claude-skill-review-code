# Report files (`--save`, `--visual`)

The chat report is always the primary output. Files are copies of it.

## Where files go

| File | Location |
| ---- | -------- |
| Automatic Markdown copy (every review) | `~/.second-pair-of-eyes/reviews/<repo-name>/<YYYYMMDD-HHMM>-<target-slug>.md`, starting with the metadata block from `recheck.md` |
| `--save` without a path | Only the automatic copy above; tell the user its path |
| `--save <path>` | That path too — the only way a file lands inside the repository. Ask before overwriting an existing file. The copy at a user path gets no metadata block unless the user asks. |
| `--visual`, local fallback | Next to the automatic copy, same name with `.html` |

`<repo-name>` is the basename of the repository root (or of the reviewed directory without git).
`<target-slug>`: `uncommitted`, `staged`, `branch-<name>`, `pr-<n>`, `range-<a>-<b>` or the path,
lowercased, non-alphanumerics replaced by `-`, at most 40 characters.

Before writing any file, check it contains no secret values.

## `--visual` — HTML report

1. Read `assets/report-template.html`. Fill every `{{…}}` placeholder:
   - `<title>`: two to four words naming the subject ("Refund Worker Review").
   - Severity counts: one number per severity; **All** = total findings.
   - One `<section id="…">` per report section in the order of `output-format.md`: `summary`,
     `intent`, `findings`, `hygiene`, `checked`, `test-gaps`, `questions`, `solid`. Drop sections
     the chat report dropped.
   - Each finding becomes an `<article class="finding" data-sev="…">` card (see the template's
     component comment), most severe first. The filter buttons rely on the lowercase `data-sev`.
   - Intent vs. Implementation becomes a table with status tags.
   - Code references are `<button class="ref" type="button">path:line</button>`.
   - HTML-escape all code, paths and quoted text (`<` → `&lt;`, `&` → `&amp;`).
   Then delete the component-patterns comment.
2. Keep the template's styling; don't add external scripts.
3. Deliver:
   - **`Artifact` tool available:** delete the `LOCAL-ONLY` block, follow any artifact guidance the
     environment requires, write the file to the session scratchpad (or the reviews directory),
     and publish it. Artifacts are private by default; give the user the link and say it is
     private until they share it.
   - **Otherwise:** keep the `LOCAL-ONLY` block, write the file next to the Markdown copy and
     give the absolute path. It loads fonts from Google Fonts; everything else is inline.
4. Check: `grep -c '{{' <file>` returns 0, and no secret values.
