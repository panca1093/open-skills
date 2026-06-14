---
name: orchestrator
description: Spec-driven development pipeline (subagent-driven). Use when the user types /zone-v2:orchestrator, asks to "run zone-v2", or wants an autonomous brief→spec→plan→implement→review→test→ship flow where each phase runs as a dispatched agent ("player"). Player personas live in players/. State flows through .claude/zone-v2/ files. Reads/writes .claude/zone-v2/manifest.json.
argument-hint: "[TICKET-ID] [--notion] [--interactive]"
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Agent]
---

## Arguments

- `[A-Z]+-\d+` → Jira path (`mode=jira`, `ticket_id=match`)
- (empty) → Scratch path (`mode=scratch`, `ticket_id=null`)
- `--notion` — enable Notion sync (requires configured IDs)
- `--interactive` — pause after each phase; re-run `/zone-v2:orchestrator` to continue

## 1. Determine mode and flags

Strip `--notion` → `notion_flag`. Strip `--interactive` → `interactive`. Match remaining for ticket ID.

## 2. Check session state

Read `.claude/zone-v2/manifest.json` if present → resume from `manifest.status`, skip to step 4. If not → step 3.

## 3. Initialize

```bash
CONFIG_PATH="$HOME/.claude/plugins/data/zone-v2/config.json"
[ -f "$CONFIG_PATH" ] && cat "$CONFIG_PATH" || echo "MISSING"
```

**Models** (required — run `/zone-v2:setup` to configure):
```bash
M_PG=$(jq -r '.models.pg // empty' "$CONFIG_PATH" 2>/dev/null)
M_SF=$(jq -r '.models.sf // empty' "$CONFIG_PATH" 2>/dev/null)
M_SF_ESCALATE=$(jq -r '.models.sf_escalate // empty' "$CONFIG_PATH" 2>/dev/null)
M_CENTER=$(jq -r '.models.center // empty' "$CONFIG_PATH" 2>/dev/null)
M_PF=$(jq -r '.models.pf // empty' "$CONFIG_PATH" 2>/dev/null)
M_SG=$(jq -r '.models.sg // empty' "$CONFIG_PATH" 2>/dev/null)
[ -z "$M_SF_ESCALATE" ] && M_SF_ESCALATE="$M_CENTER"
```
If any required var is empty → stop: "Player models not configured. Run /zone-v2:setup first."

SF escalation: use `M_SF_ESCALATE` when `retries≥2` or fix is architectural.

**Notion:** `notion_enabled = notion_flag AND work/personal db_id non-empty`. If flag set but no IDs: tell user to run `/zone-v2:setup` or drop `--notion`.
- Enabled: `db_id` = work_db_id (jira) / personal_db_id (scratch); `spec_parent` = matching parent ID.
- Disabled: both null.

**Wiki path:**
```bash
WIKI_PATH=$(jq -r '.wiki_path // "~/Documents/MyBook/wiki"' "$CONFIG_PATH" 2>/dev/null | sed "s|^~|$HOME|")
[ -z "$WIKI_PATH" ] || [ "$WIKI_PATH" = "null" ] && WIKI_PATH="$HOME/Documents/MyBook/wiki"
```

**Write manifest** (`.claude/zone-v2/manifest.json`):
```json
{
  "mode": "<jira|scratch>",
  "ticket_id": "<TICKET-XXXX or null>",
  "project": null,
  "project_dir": null,
  "interactive": <true|false>,
  "wiki_path": "<resolved>",
  "notion": { "enabled": <bool>, "spec_parent": null, "spec_page_id": null, "db_id": null },
  "tasks": [],
  "current_task_index": 0,
  "retries": { "review_to_implement": 0, "test_to_implement": 0 },
  "branch": null,
  "pr_url": null,
  "status": "brief"
}
```

`manifest.tasks` = `[{ "title", "status": "pending|in_progress|done", "notion_page_id": null }]`. Full task detail lives in `plan.md`.

## 4. Execute pipeline

**Orchestrator owns `manifest.json`.** Players write only their artifact files and return one line. After each returns: read artifact → update manifest (single Edit) → emit one status line → loop. No re-reads, no echo, no exploratory Bash between phases.

**Dispatch contract** — Agent tool call per player:
- `subagent_type: "general-purpose"`, `model: <M_PLAYER>`, `description: "zone-v2 <phase>"`
- `prompt:` content of `players/<name>.md` (read first) + Runtime context:

```
## Runtime context
- Working directory: <manifest.project_dir or cwd>
- State directory: .claude/zone-v2/
- Read before acting: <phase-specific>
- Convention files: read CLAUDE.md / AGENTS.md if present.
- Go projects: run `go` commands plainly. If GOROOT error occurs, prepend:
    if [ -z "$GOROOT" ] || [ ! -x "$GOROOT/bin/go" ]; then
      [ -d /opt/homebrew/Cellar/go ] && export GOROOT="$(ls -d /opt/homebrew/Cellar/go/*/libexec 2>/dev/null | sort -V | tail -n1)";
    fi
- Notion enabled: <true|false>
- Current task index: <n>  (implement only)
- Current task block: <### Task N block verbatim>  (implement normal mode)
- Fix mode: <none|review|test>  (implement only)

## Your deliverable
- Write <result file> per your output contract.
- Do NOT modify manifest.json.
- Return ONE line: status + short summary.
```

**Loop:** run phase → read artifact → update manifest → check stop conditions → repeat.
Stop if: retry counter > 5 (exhaustion report) · `status="done"` (completion) · `BLOCKED`/`NEEDS_CONTEXT` user must resolve.
Interactive mode: run one phase then stop; user re-runs.

## Phase handlers

### `brief` → Coach (INLINE)

Read `players/coach.md` and embody inline (can't be subagent — needs AskUserQuestion).

**Jira:** fetch ticket via `mcp__atlassian-jira__getJiraIssue` or ask user to paste. Load context first: `MEMORY.md`, wiki index, `git log --oneline -20`, `git branch -a`, repo layout, `CLAUDE.md`/`AGENTS.md`/`README.md`. Interview (≤5 AskUserQuestion), each showing why. Cover: unstated AC, affected services, edge cases, breaking changes, inflight deps.

**Scratch:** AskUserQuestion until idea is precise (problem, users, success, existing code, constraints). Ask project name → set `manifest.project`. If `project_dir` null: `mkdir -p <cwd>/<name>`, git init, set `manifest.project_dir`.

**Both:** write `brief.md` (Base Axioms / User Interfaces / Architectural Layers: Contract·Domain·Persistence / Out of scope). Set `status="spec"`, write manifest.

### `spec` → dispatch PG (`M_PG`)

Read `players/pg.md`. Read before acting: `brief.md`. PG writes `spec.md` + `plan.md`.

After PG: extract `### Task N: <title>` headings from `plan.md` → set `manifest.tasks` (all pending, index=0). If Notion: create spec page, create task rows. Set `status="implement"`, write manifest.

### `implement` → dispatch SF (`M_SF` / `M_SF_ESCALATE` on escalation)

**Fix mode check:**
- `review_result.json` with `status="CHANGES_NEEDED"` → fix=review (`M_SF`; `M_SF_ESCALATE` if retries≥2 or architectural)
- `test_result.json` with `status` in {`FAILED`,`BLOCKED`} → fix=test (`M_SF`; `M_SF_ESCALATE` if retries≥2)
- else → normal mode

**Normal mode:**
- `current_task_index >= len(tasks)` → set `status="review"`, write manifest, stop handler.
- Else: if `branch` null → `git checkout -b feat/<ticket-or-project>-<kebab>`, set `manifest.branch`. Mark task `in_progress`, write manifest.

Read `players/sf.md`. Normal: embed `### Task N` block in context; read-before-acting = `spec.md` only. Fix: read-before-acting = result json + named files. SF writes `task_result.json`.

**After SF:**
- Normal `DONE`/`DONE_WITH_CONCERNS` → task `done`, increment index, stay `implement`.
- `NEEDS_CONTEXT` → AskUserQuestion → re-dispatch SF. Unanswerable non-interactive → STOP.
- `BLOCKED` → STOP, report blocker.
- Fix=review `DONE` → rename `review_result.json`→`review_prev.json`, set `status="review"`.
- Fix=test `DONE` → delete `test_result.json`, set `status="test"`.

### `review` → dispatch Center (`M_CENTER`)

First pass (`retries=0`): read before acting = `spec.md`, `plan.md`, diff (`git diff main...HEAD` or `master...HEAD` or `HEAD`).
Re-review (`retries≥1`): scoped — read `review_prev.json`; verify only prior blockers resolved + quick regression scan. Read before acting = `review_prev.json`, `spec.md`, diff.

Read `players/center.md`. Center writes `review_result.json`.

- `APPROVED` → set `status="test"`.
- `CHANGES_NEEDED` → increment `retries.review_to_implement`. >5 → exhaustion, STOP. Else set `status="implement"`.

### `test` → dispatch PF (`M_PF`)

Read `players/pf.md`. Read before acting: `spec.md`, `plan.md`. PF writes `test_result.json`.
If no suite: PF returns `BLOCKED("no suite found")` → AskUserQuestion: add tests or "skip tests". Don't advance without confirmation.

- `PASSED` → set `status="ship"`.
- `FAILED`/`BLOCKED` → increment `retries.test_to_implement`. >5 → exhaustion, STOP. Else set `status="implement"`.

### `ship` → dispatch SG (`M_SG`)

Precondition: `test_result.json` PASSED. If not → set `status="test"`, loop.

Read `players/sg.md`. Read before acting: `manifest.json`, `spec.md`, `brief.md`, `test_result.json`. Branch already exists; SF committed each task. SG: commit leftovers (no `git add -A`), push, open PR, sync Notion if enabled. Returns branch + PR URL.

After SG: set `manifest.branch`, `manifest.pr_url`. Update wiki (`tickets/<id>.md` or `personal/<project>.md` + `index.md` + `log.md`); sync Notion if enabled. Set `status="done"`, write manifest.

### `done` — completion

```
Zone complete. You're in the zone.

PR:     <pr_url or commit hash>
Branch: <branch>
Spec:   <notion url — omit if disabled>
Wiki:   <wiki_path>/...
```

### Exhaustion (retry counter > 5)

```
Zone stalled — <review|test> loop exhausted (5 retries).
Last finding: <summary>
Fix manually, then re-run /zone-v2:orchestrator, or reset the retry counter in manifest.json.
```
