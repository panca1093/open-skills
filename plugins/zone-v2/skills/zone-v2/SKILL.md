---
name: zone-v2
description: Spec-driven development pipeline (single-file). Use when the user types /zone-v2, asks to "run zone-v2", "start a zone-v2 session", invokes the zone-v2 pipeline for a Jira ticket (e.g. /zone-v2 LOAN-1234), or wants an autonomous brief→spec→plan→implement→review→test→ship flow. Merged single-file successor to zone v1 — all seven phases inline, Notion opt-in (--notion), state tracked in .zone-v2/manifest.json.
argument-hint: "[TICKET-ID] [--notion] [--interactive]"
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion]
---

# /zone-v2 — Spec-Driven Development Pipeline (single-file)

One command, seven phases, autonomous by default. Takes an idea from brief to shipped PR.

This is the merged successor to zone v1: the orchestrator and all seven phases live in this one file as `## Phase:` sections. The pipeline runs in a single agent context — there is no per-phase Skill dispatch. State lives in `.zone-v2/` so v2 never collides with a v1 `.zone/` manifest on the same repo.

Name inspired by Kuroko's Basketball — entering the Zone is peak performance state where everything flows perfectly.

## Arguments

`$ARGUMENTS` can be:
- A Jira ticket ID matching `[A-Z]+-\d+` (e.g. `LOAN-1234`) → **Jira path** (TDD, formal spec, Notion Tasks — Work)
- Empty → **Scratch path** (personal/side project, Notion Tasks — Personal)
- `--notion` — **opt in** to Notion sync for this session (off by default; requires configured IDs)
- `--interactive` — pause after each phase and wait for `/zone-v2` to be re-run (default: autonomous)

---

## 1. Determine mode and flags

Strip `--notion` from `$ARGUMENTS` if present → `notion_flag = true` if found, else `false`.
Strip `--interactive` from `$ARGUMENTS` if present → `interactive = true` if found, else `false`.

- If remaining argument matches `[A-Z]+-\d+` → `mode = "jira"`, `ticket_id = match`
- Otherwise → `mode = "scratch"`, `ticket_id = null`

---

## 2. Check session state

Look for `.zone-v2/manifest.json` in the current working directory.

**If manifest exists:** Read it. Resume from `manifest.status`. Skip to step 4.

**If no manifest:** Continue to step 3.

---

## 3. Initialize new session

### 3a. Load plugin config (optional)

Config is optional in zone-v2 — the pipeline runs without it (Notion off, wiki defaults). Only read it to pick up Notion IDs and a custom wiki path:

```bash
CONFIG_PATH="$HOME/.claude/plugins/data/zone-v2/config.json"
if [ -f "$CONFIG_PATH" ]; then
  cat "$CONFIG_PATH"
else
  echo "MISSING"
fi
```

If the file is missing, that is fine — proceed with Notion disabled and the default wiki path. Only mention setup if the user passed `--notion` (see 3b).

### 3b. Derive Notion config

Notion is **off by default** and opt-in via `--notion`. From the loaded config (if any):
- `notion_enabled = notion_flag AND (config.notion.work_db_id OR config.notion.personal_db_id is non-empty)`
- If `notion_enabled`:
  - `db_id` = `config.notion.work_db_id` (jira) or `config.notion.personal_db_id` (scratch)
  - `spec_parent` = `config.notion.work_parent_id` (jira) or `config.notion.personal_parent_id` (scratch)
- Else: `db_id = null`, `spec_parent = null`

If `notion_flag` is true but no IDs are configured for the chosen mode, tell user:
```
--notion requested but no <work|personal> Notion IDs configured. Run /zone-v2:setup to add them, or drop --notion to run without Notion.
```

### 3c. Determine wiki path

```bash
WIKI_PATH=$(jq -r '.wiki_path // "~/Documents/MyBook/wiki"' "$CONFIG_PATH" 2>/dev/null | sed "s|^~|$HOME|")
[ -z "$WIKI_PATH" ] || [ "$WIKI_PATH" = "null" ] && WIKI_PATH="$HOME/Documents/MyBook/wiki"
echo "$WIKI_PATH"
```

Store this for later phases.

### 3d. Write manifest

Create `.zone-v2/` directory if missing. Write `.zone-v2/manifest.json`:

```json
{
  "mode": "<jira|scratch>",
  "ticket_id": "<TICKET-XXXX or null>",
  "project": null,
  "project_dir": null,
  "interactive": <true|false>,
  "wiki_path": "<resolved wiki path>",
  "notion": {
    "enabled": <true|false>,
    "spec_parent": "<spec_parent or null>",
    "spec_page_id": null,
    "db_id": "<db_id or null>"
  },
  "tasks": [],
  "current_task_index": 0,
  "branch": null,
  "pr_url": null,
  "status": "brief"
}
```

---

## 4. Execute pipeline

### Dispatch to a phase

The pipeline phases are defined as `## Phase: <name>` sections at the bottom of this file. To "run a phase," execute the instructions in the matching section — there is no Skill tool call; everything runs in this one context.

| status | section |
|--------|---------|
| `brief` | `## Phase: brief` |
| `spec` | `## Phase: spec` |
| `plan` | `## Phase: plan` |
| `implement` | `## Phase: implement` |
| `review` | `## Phase: review` |
| `test` | `## Phase: test` |
| `ship` | `## Phase: ship` |

### Autonomous mode (default: `manifest.interactive = false`)

Run phases in a continuous loop:

1. Note the current `manifest.status` as `prev_status`
2. Execute the matching `## Phase:` section from the table above
3. Re-read `.zone-v2/manifest.json` to get `new_status`
4. Apply stop conditions:
   - `prev_status = "review"` AND `new_status = "implement"` → **STOP** (review found blockers — tell user to fix then re-run `/zone-v2`)
   - `prev_status = "test"` AND `new_status = "implement"` → **STOP** (tests failing — tell user to fix then re-run `/zone-v2`)
   - `new_status = "done"` → **STOP** — print completion summary (see below)
5. Otherwise: go back to step 1 and continue

For `implement`: status legitimately stays `"implement"` across multiple iterations (one task per iteration). Keep looping until status advances to `"review"`.

### Interactive mode (`manifest.interactive = true`)

Execute only the current phase's section. After it completes, stop. Do not advance to the next phase — the user re-runs `/zone-v2` manually.

### Completion summary (`status = "done"`)

```
Zone complete. You're in the zone.

PR:     <manifest.pr_url or commit hash>
Branch: <manifest.branch>
Spec:   <https://www.notion.so/<spec_page_id no-dashes> — omit if Notion disabled>
Wiki:   <manifest.wiki_path>/...  (set by ship)
```

---
---

## Phase: brief

Read `.zone-v2/manifest.json` to get `mode`, `ticket_id`, and `interactive`.

### Jira Path (`mode = "jira"`)

#### 1. Load context

Try to fetch the Jira ticket. The Jira MCP tool may or may not be loaded in this session.

- If `mcp__atlassian-jira__getJiraIssue` is available, call it with `ticket_id` to fetch the ticket details.
- If not, ask the user via AskUserQuestion: "Jira MCP isn't loaded. Paste the ticket title and description here so I can write the brief from it."

Then load supporting context:

- Read user memory index: `~/.claude/projects/-Users-Panca-Documents-MyBook/memory/MEMORY.md` (if it exists; skip silently if not)
- Read project wiki index if present (e.g. `<wiki_path>/index.md` from manifest)
- `git log --oneline -20` and `git branch -a` to understand repo state
- `find . -name "*.go" -o -name "*.ts" -o -name "*.py" 2>/dev/null | head -30` for codebase layout
- Read `CLAUDE.md`, `AGENTS.md`, or `README.md` at the repo root if present, for conventions

#### 2. Ask targeted questions

Based on what you've read, ask about anything that would block writing a complete spec. Use **AskUserQuestion** for these (multi-select where appropriate, free-text via "Other"). Focus on:
- Acceptance criteria not explicitly stated in the ticket
- Which services or repos are affected beyond what's obvious
- Edge cases the ticket doesn't address
- Whether this is a breaking change and how to handle existing behavior
- Any dependency on inflight work in other tickets

Keep it to ≤5 questions. Wait for user answers before proceeding.

#### 3. Write brief

Write `.zone-v2/brief.md`:

```markdown
# Brief: <ticket_id> — <one-line title>

## Ticket Summary
<your own words — what is being asked and why>

## Key Answers
<user's answers from Q&A>

## Constraints
<technical or business constraints identified>

## Edge Cases
<cases that need to be handled>

## Affected Files (best guess)
<list files/packages likely to change>
```

#### 4. Update manifest

Set `manifest.status = "spec"`. Write updated `.zone-v2/manifest.json`.

If `manifest.interactive = true`:
  Tell user: "Brief done. Run `/zone-v2` to continue to spec."
Else:
  Tell user: "Brief done. Continuing to spec."

### Scratch Path (`mode = "scratch"`)

#### 1. Brainstorm conversation

Use AskUserQuestion to sharpen the idea until it's precise enough to spec. Cover:
- What problem is this solving?
- Who uses it and how?
- What does success look like concretely?
- Any existing code this touches?
- Any technical constraints (language, platform, deadline)?

Iterate — ask follow-ups across multiple AskUserQuestion calls if the answers aren't crisp.

#### 2. Set project name

Ask: "What should I call this project? (e.g. `tka-prep-app`, `restaurant-app`)"

Update `manifest.project` with the answer.

#### 3. Create project directory (new projects only)

If `manifest.project_dir` is null (new session):

Get the current working directory path (where zone-v2 was invoked from). Create the project directory as a subdirectory:

```bash
mkdir -p "<cwd>/<project-name>"
```

Initialize git if the directory is not already a git repository:
```bash
git -C "<cwd>/<project-name>" init
```

Update manifest:
- `manifest.project_dir` = absolute path to `<cwd>/<project-name>`

Write updated manifest.

Tell user: "Created `<project-name>/` — all implementation will go here."

#### 4. Write brief

Write `.zone-v2/brief.md`:

```markdown
# Brief: <project> — <one-line title>

## Problem
<what breaks or is missing without this>

## Idea
<the solution in plain language>

## Users
<who uses it>

## Success Criteria
<what done looks like>

## Constraints
<language, platform, deadline, existing code>
```

#### 5. Update manifest

Set `manifest.status = "spec"`. Write updated `.zone-v2/manifest.json`.

If `manifest.interactive = true`:
  Tell user: "Brief done. Run `/zone-v2` to continue to spec."
Else:
  Tell user: "Brief done. Continuing to spec."

---

## Phase: spec

Read `.zone-v2/manifest.json` and `.zone-v2/brief.md`.

### Write Spec Locally

Write `.zone-v2/spec.md` using this template — keep it under 2 pages, dense over exhaustive:

```markdown
# Spec: <ticket_id or project> — <title>

## Problem
One paragraph. What breaks or is missing without this change?

## Solution
What we're building, in plain language.

## Scope

### In scope
- ...

### Out of scope
- ...

## API / Interface Changes
List new endpoints, function signatures, or proto changes. "None" if none.

## Data Changes
DB migrations, new fields, removed fields. "None" if none.

## Affected Services
| Repo | Change |
|------|--------|
| ... | ... |

## Acceptance Criteria
- [ ] ...
- [ ] ...

## Open Questions
(none — or list anything still unresolved)
```

### Push to Notion (skip if `manifest.notion.enabled = false`)

If `manifest.notion.enabled` is true:

Create a Notion page with the spec content under `manifest.notion.spec_parent`.

Page title: `Spec: <ticket_id or project> — <title>`

Use `mcp__claude_ai_Notion__notion-create-pages` with:
- `parent`: `{"type": "page_id", "page_id": "<manifest.notion.spec_parent>"}`
- `pages`: array with one page object having `properties.title` and `content` (spec body)

After creating, record the returned Notion page ID in `manifest.notion.spec_page_id`.

### Update Manifest

Set `manifest.status = "plan"`. Write updated `.zone-v2/manifest.json`.

Tell user: "Spec done. Run `/zone-v2` to continue to plan." (omit "pushed to Notion" if Notion disabled)

---

## Phase: plan

Read `.zone-v2/manifest.json`, `.zone-v2/brief.md`, `.zone-v2/spec.md`.

### Break Into Tasks

Create an ordered task list. Each task must be:
- Independently implementable (no circular dependencies)
- Small enough to TDD in one session (one logical change)
- Named with a verb phrase: "Add X", "Migrate Y", "Fix Z", "Expose X endpoint"

For each task define:
- `title` — verb phrase
- `test_cases` — list of concrete test scenarios (these become the Red phase targets)
- `files_to_touch` — best-guess list of files that will change

Aim for 3–8 tasks. One task is fine if the work is trivial.

### Push Tasks to Notion (skip if `manifest.notion.enabled = false`)

If `manifest.notion.enabled` is true:

For each task, create a row in the Notion DB at `manifest.notion.db_id` using `mcp__claude_ai_Notion__notion-create-pages` with `parent.type = "data_source_id"`.

Set fields:
- `Task` = title
- `Status` = "To Do"
- `Ticket` = ticket_id (Jira) or project name (Scratch)
- `Spec` = Notion spec page URL (derive from `manifest.notion.spec_page_id`: `https://www.notion.so/<id-no-dashes>`)

Record each created row's Notion page ID into the matching task's `notion_page_id` (see manifest shape below).

### Update Manifest

Populate `manifest.tasks`:

```json
[
  {
    "id": "task-1",
    "title": "...",
    "status": "todo",
    "notion_page_id": "<id or null if Notion disabled>",
    "test_cases": ["when X, expect Y", "..."],
    "files_to_touch": ["src/foo.go", "..."]
  }
]
```

Set `manifest.current_task_index = 0`.
Set `manifest.status = "implement"`.
Write updated `.zone-v2/manifest.json`.

### Print Plan

Show the task breakdown:

```
Plan (N tasks):
  [1] Add X
      Tests: scenario A, scenario B
      Files: src/foo.go
  [2] Migrate Y
      Tests: ...
      Files: ...
```

Tell user: "Plan ready. Run `/zone-v2` to start implementing."

---

## Phase: implement

Read `.zone-v2/manifest.json`.

### Check Completion

If `manifest.current_task_index >= len(manifest.tasks)`:
  - Set `manifest.status = "review"`. Write manifest.
  - Tell user: "All tasks done. Run `/zone-v2` to start review."
  - Stop.

### Current Task

Get task at `manifest.tasks[manifest.current_task_index]`.

Print: `Working on task [<index+1>/<total>]: <title>`

Update task status to `in_progress`:
- In manifest: `task.status = "in_progress"`
- In Notion (only if `manifest.notion.enabled`): update `task.notion_page_id` row, Status = "In Progress"
- Write updated manifest.

### TDD Loop

#### Project type detection

| Language | Detection | Test convention |
|---|---|---|
| Go | `go.mod` | Table-driven, same package, `TestFunc_Scenario` |
| Node/JS | `package.json` | Jest/Vitest `describe`/`it` blocks |
| Python | `pyproject.toml` or `requirements.txt` | pytest, `test_func_scenario` |
| Rust | `Cargo.toml` | `#[test]` in a `tests` module |
| Other | — | Match existing test style in the repo |

If a CLAUDE.md or AGENTS.md is present at the repo root, read it for layering rules and architectural conventions BEFORE writing any implementation.

#### GOROOT auto-correction (Go projects only)

For Go projects, before invoking any `go` command, run this guard inline (or prefix the command):

```bash
# If GOROOT is unset, missing, or doesn't contain a Go binary, try Homebrew
if [ -z "$GOROOT" ] || [ ! -x "$GOROOT/bin/go" ]; then
  if [ -d /opt/homebrew/Cellar/go ]; then
    export GOROOT="$(ls -d /opt/homebrew/Cellar/go/*/libexec 2>/dev/null | sort -V | tail -n1)"
  fi
fi
```

This auto-detects the Homebrew Go install on machines where the system `GOROOT` env var points to a stale location. No-op on machines where GOROOT is fine.

#### Red — Write failing tests first

Look at `task.test_cases`. Write tests covering all scenarios BEFORE writing any implementation.

Run the test command for the detected language:

| Language | Test command |
|---|---|
| Go | `go test ./... -race -count=1` |
| Node | `npm test` or `yarn test` |
| Python | `pytest` |
| Rust | `cargo test` |
| Other | Check for `Makefile` `test` target → `make test` |

Confirm they fail — if a test passes before any implementation, the test case is likely wrong. Fix it.

#### Green — Implement

Write the minimum implementation to make the failing tests pass.

Run tests. Confirm they pass (Green).

#### Refactor

Clean up: remove duplication, improve naming, simplify. Do NOT change behavior.
Run tests again to confirm still green.

### Complete Task

- Set `task.status = "done"` in manifest
- Update Notion row: Status = "Done" (only if `manifest.notion.enabled`)
- Increment `manifest.current_task_index`
- Write updated manifest

Tell user: "Task [N] done. Run `/zone-v2` to continue to next task (or review if all done)."

---

## Phase: review

Read `.zone-v2/manifest.json` and `.zone-v2/spec.md`.

### 0. Optional model override

Before running the review, ask the user whether to use a stronger model. Use AskUserQuestion with one question:

**Question:** "Run review with the current model, or escalate to Opus for higher-quality findings?"
- "Current model" — proceed inline (default)
- "Opus" — note this in the output for the user to re-run the review with `--model opus` themselves, OR (next iteration) dispatch a sub-agent with Opus model override.

If the user picks "Opus", for now just tell them: "Re-run `/zone-v2` at the review phase with the Opus model override (e.g. by switching the session model or invoking via a sub-agent). Pausing the pipeline."

Set `manifest.status` to stay at `"review"` and stop. The user will re-invoke after switching model.

If the user picks "Current model", continue.

### 1. Get the Diff

```bash
git diff main...HEAD 2>/dev/null || git diff master...HEAD
```

If no diff (nothing committed yet), run `git diff HEAD` instead.

### 2. Review Against These Criteria

#### Blockers — must fix before ship

- [ ] Business logic placed in the wrong architectural layer (consult CLAUDE.md or AGENTS.md for project conventions)
- [ ] Acceptance criteria from spec not covered by tests
- [ ] Missing test for any scenario listed in `task.test_cases`
- [ ] Security issue: SQL injection, unvalidated external input, exposed secret
- [ ] Data race or concurrency bug
- [ ] Breaking change to existing API not documented in the spec
- [ ] Panic / null dereference without guard

#### Warnings — note but do not block

- Missing edge case coverage (document, not block)
- Overly complex abstraction for the problem size
- Missing error handling at a system boundary (external API, DB call)
- Inconsistent naming or style with surrounding code

### 3. Decision

#### Blockers found

List each blocker precisely (file, line number, what's wrong, how to fix).

Set `manifest.status = "implement"`. Write manifest.

Tell user:
```
Review: BLOCKED (<N> issue(s))
<list of blockers>

Fix these, then run `/zone-v2` to re-review.
```

#### No blockers

Set `manifest.status = "test"`. Write manifest.

Tell user:
```
Review: PASSED
<optional: list any warnings for awareness>

Run `/zone-v2` to run tests.
```

---

## Phase: test

Read `.zone-v2/manifest.json`.

### GOROOT auto-correction (Go projects)

If the project is Go (`go.mod` present), apply this guard before invoking `go`:

```bash
if [ -z "$GOROOT" ] || [ ! -x "$GOROOT/bin/go" ]; then
  if [ -d /opt/homebrew/Cellar/go ]; then
    export GOROOT="$(ls -d /opt/homebrew/Cellar/go/*/libexec 2>/dev/null | sort -V | tail -n1)"
  fi
fi
```

### Detect Project Type and Run Tests

#### Go project (has `go.mod`)

```bash
go test ./... -race -count=1
```

If that passes, also run with `-shuffle=on` to catch order-dependent failures:
```bash
go test ./... -race -shuffle=on -count=1
```

#### Node/JS project (has `package.json`)

Run the `test` script: `npm test` or `yarn test`.

#### Python project (has `pyproject.toml` or `requirements.txt`)

```bash
pytest
```

#### Rust project (has `Cargo.toml`)

```bash
cargo test
```

#### Other

Check for a `Makefile` target named `test`. If found, run `make test`.

### No Test Suite Found

**Do NOT silently pass.**

Tell user:
```
No test suite found in this project.

Options:
  1. Add tests now (recommended) — tell me what to cover and I'll write them
  2. Confirm this is intentional — type "skip tests" to proceed to ship anyway

Waiting for your decision.
```

Stop and wait. Do not advance to ship without explicit confirmation.

### Tests Fail

Show the full failure output (don't truncate).

Set `manifest.status = "implement"`. Write manifest.

Tell user:
```
Tests: FAILING

<failure output>

Fix the failures, then run `/zone-v2` to re-test.
```

### Tests Pass

Set `manifest.status = "ship"`. Write manifest.

Tell user:
```
Tests: GREEN ✓

Run `/zone-v2` to ship.
```

---

## Phase: ship

Read `.zone-v2/manifest.json` and `.zone-v2/spec.md`.

### 1. Create Branch (if not already on a feature branch)

Determine the working directory: use `manifest.project_dir` if set, otherwise cwd.

If `manifest.branch` is null or the current branch is `main`/`master`:

- Jira path: `git checkout -b feat/<ticket_id>-<kebab-slug-of-title>`
- Scratch path: `git checkout -b feat/<project>-<kebab-slug-of-title>`

Update `manifest.branch` with the branch name. Write manifest.

### 2. Commit

Stage relevant changed files (be specific — no `git add -A`).

Commit with message:
- Jira path: `feat: <TICKET-ID> | <brief description>`
- Scratch path: `feat: <brief description>`

### 3. Create PR

If a git remote exists, push and create PR:

```bash
git push -u origin <branch>
```

Then use `gh pr create` with a HEREDOC.

**Title:**
- Jira path: `feat: <TICKET-ID> | <brief description>`
- Scratch path: `feat: <brief description>`

**Body:**
```
## Summary
- <bullet 1 from spec solution>
- <bullet 2>

## Spec
<if manifest.notion.enabled and manifest.notion.spec_page_id is set:
  https://www.notion.so/<spec_page_id no-dashes>
  otherwise omit this section>

## Test plan
- [ ] All tests green
- [ ] <acceptance criterion 1 from spec>
- [ ] <acceptance criterion 2 from spec>

🤖 Generated with [Claude Code](https://claude.ai/code) via /zone-v2
```

If no git remote exists, skip PR creation and print the commit hash and summary instead.

### 4. Update Notion (skip if `manifest.notion.enabled = false`)

If `manifest.notion.enabled` is true:

For each task in `manifest.tasks`:
- Update Notion row Status = "Done" (if not already done)

Update the spec Notion page (`manifest.notion.spec_page_id`) — append PR URL to the page body using `mcp__claude_ai_Notion__notion-update-page` with `command: "insert_content"`, `position: {type: "end"}`.

### 5. Update Local Wiki

Read `wiki_base` from `manifest.wiki_path`. If missing, fall back to `~/Documents/MyBook/wiki`.

Today's date is in `Asia/Jakarta` timezone.

#### Jira path

Check if `<wiki_base>/tickets/<ticket_id>.md` exists.

**If it exists:** Update the page — add the Implementation section with branch, PR URL, and a brief note on what changed.

**If it does not exist:** Create `<wiki_base>/tickets/<ticket_id>.md`:

```markdown
---
title: <ticket_id> — <title from spec>
category: ticket
tags: [implementation]
sources: []
updated: <today's date YYYY-MM-DD>
---

## Summary
<problem paragraph from spec>

## Solution
<solution paragraph from spec>

## Acceptance Criteria
<from spec>

## Implementation
- Branch: `<manifest.branch>`
- PR: <manifest.pr_url or commit hash>

## Spec
<if Notion enabled: [Notion Spec](https://www.notion.so/<spec_page_id no-dashes>)>
```

Update `<wiki_base>/index.md` — add the ticket entry under the Tickets section:
```
- [[<ticket_id>]] — <one-line summary>  (sources: 0)
```

Append to `<wiki_base>/log.md`:
```
## [<today YYYY-MM-DD>] ingest | <ticket_id> — <title>
Shipped <ticket_id> via /zone-v2. PR: <pr_url>. Created wiki page from spec.
```

**Sync to Notion** (if `manifest.notion.enabled = true`):
- Create a page under Tickets & RFCs (configured via `config.notion.work_parent_id`) using `mcp__claude_ai_Notion__notion-create-pages`
- Title: `<ticket_id> — <title>`
- Body: same content as the local wiki page

#### Scratch path

Check if `<wiki_base>/personal/<project>.md` exists.

**If it does not exist (new project):** Create `<wiki_base>/personal/<project>.md`:

```markdown
---
title: <project>
category: personal
tags: [project]
sources: []
updated: <today's date YYYY-MM-DD>
---

## About
<problem and idea from brief>

## Users
<who uses it>

## Tech Stack
<language and frameworks used in implementation>

## Status
Active

## Links
- Repo: `<manifest.project_dir>`
- PR/Commit: <manifest.pr_url or commit hash>
<if Notion enabled: - Spec: [Notion Spec](https://www.notion.so/<spec_page_id no-dashes>)>
```

Update `<wiki_base>/personal/index.md` — add the project entry.

Update `<wiki_base>/index.md` — add under Personal section:
```
- [[<project>]] — <one-line description>  (sources: 0)
```

Append to `<wiki_base>/log.md`:
```
## [<today YYYY-MM-DD>] ingest | <project> — new project
Created new project via /zone-v2 scratch path. PR: <pr_url>. Wiki page created.
```

**If it exists (project already has a page):** Update the Status, Links, and Tech Stack sections to reflect the new PR/commit.

**Sync to Notion** (if `manifest.notion.enabled = true`):
- Create or update a page under the Personal parent (configured via `config.notion.personal_parent_id`) using `mcp__claude_ai_Notion__notion-create-pages` or `mcp__claude_ai_Notion__notion-update-page`

### 6. Finalize Manifest

Set `manifest.pr_url` to the PR URL (or commit hash if no remote).
Set `manifest.status = "done"`.
Write updated `.zone-v2/manifest.json`.

### 7. Done

Tell user:

```
Zone complete. You're in the zone.

PR:     <pr_url or commit hash>
Branch: <branch>
Spec:   <https://www.notion.so/<spec_page_id> — omit if Notion disabled>
Wiki:   <wiki_base>/tickets/<ticket_id>.md  (or personal/<project>.md)
```
