---
name: 3o3-play
description: Zone-v2 phase 2 — implement→review→test loop. SF, Center, PF rotate with up to 5 retries. Reads .claude/zone-v2/manifest.json; resumes from implement/review/test. Ends with manifest.status="ship". Run after /zone-v2:coach-brief.
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Agent]
---

## 0. Load models from config

```bash
CONFIG_PATH="$HOME/.claude/plugins/data/zone-v2/config.json"
M_SF=$(jq -r '.models.sf // empty' "$CONFIG_PATH" 2>/dev/null)
M_SF_ESCALATE=$(jq -r '.models.sf_escalate // empty' "$CONFIG_PATH" 2>/dev/null)
M_CENTER=$(jq -r '.models.center // empty' "$CONFIG_PATH" 2>/dev/null)
M_PF=$(jq -r '.models.pf // empty' "$CONFIG_PATH" 2>/dev/null)
[ -z "$M_SF_ESCALATE" ] && M_SF_ESCALATE="$M_CENTER"
```
If any required var is empty → stop: "Player models not configured. Run /zone-v2:setup first."

## 1. Load manifest

Read `.claude/zone-v2/manifest.json`.
- No manifest → stop: "Run /zone-v2:coach-brief first."
- `status` in {`brief`,`spec`} → stop: "Run /zone-v2:coach-brief first."
- `status="ship"` → stop: "Run /zone-v2:shoot-play."
- `status="done"` → stop: "Pipeline done."

## 2. Loop

Manifest owns `manifest.json`. After each player: read artifact → update manifest (single Edit) → emit one line → loop.
Stop if: retry counter >5 (exhaustion) · `status="ship"` (hand off) · `BLOCKED`/`NEEDS_CONTEXT`.

**Dispatch contract** — Agent tool per player:
`subagent_type: "general-purpose"`, `model: <M_PLAYER>`, `description: "zone-v2 3o3-play — <player>"`

Prompt = content of `players/<name>.md` + Runtime context:
```
## Runtime context
- Working directory: <manifest.project_dir or cwd>
- State directory: .claude/zone-v2/
- Read before acting: <see handler>
- Convention files: read CLAUDE.md / AGENTS.md if present.
- Go projects: run `go` commands plainly. On GOROOT error prepend:
    if [ -z "$GOROOT" ] || [ ! -x "$GOROOT/bin/go" ]; then
      [ -d /opt/homebrew/Cellar/go ] && export GOROOT="$(ls -d /opt/homebrew/Cellar/go/*/libexec 2>/dev/null | sort -V | tail -n1)";
    fi
- Notion enabled: <bool>
- Current task index / block / fix mode: <implement only>

## Your deliverable
- Write <result file> per output contract. Do NOT modify manifest.json.
- Return ONE line: status + summary.
```

## 3. Phase handlers

### `implement` → SF (`M_SF` / `M_SF_ESCALATE` on escalation)

**Mode:**
- `review_result.json` `CHANGES_NEEDED` → fix=review (`M_SF`; `M_SF_ESCALATE` if retries≥2 or architectural)
- `test_result.json` `FAILED`/`BLOCKED` → fix=test (`M_SF`; `M_SF_ESCALATE` if retries≥2)
- else → normal

**Normal:** if `current_task_index >= len(tasks)` → set `status="review"`, write manifest, stop. Else: if `branch` null → `git checkout -b feat/<ticket-or-project>-<kebab>`, set `manifest.branch`. Mark task `in_progress`, write manifest.

Read `players/sf.md`. Normal: embed `### Task N` block in context; read-before-acting=`spec.md`. Fix: read-before-acting=result json + named files. SF writes `task_result.json`.

After SF:
- Normal `DONE`/`DONE_WITH_CONCERNS` → task `done`, increment index, stay `implement`.
- `NEEDS_CONTEXT` → AskUserQuestion → re-dispatch. Unanswerable → STOP.
- `BLOCKED` → STOP.
- Fix=review `DONE` → rename `review_result.json`→`review_prev.json`, set `status="review"`.
- Fix=test `DONE` → delete `test_result.json`, set `status="test"`.

### `review` → Center (`M_CENTER`)

First pass (`retries=0`): read-before-acting=`spec.md`, `plan.md`, diff (`git diff main...HEAD` || `master...HEAD` || `HEAD`).
Re-review (`retries≥1`): scoped — `review_prev.json` + verify prior blockers only + quick regression. Read-before-acting=`review_prev.json`, `spec.md`, diff.

Read `players/center.md`. Center writes `review_result.json`.
- `APPROVED` → set `status="test"`.
- `CHANGES_NEEDED` → increment `retries.review_to_implement`. >5 → exhaustion. Else set `status="implement"`.

### `test` → PF (`M_PF`)

Read `players/pf.md`. Read-before-acting: `spec.md`, `plan.md`. No suite → PF returns `BLOCKED("no suite found")` → AskUserQuestion: add tests or "skip tests". Don't advance without confirmation.

PF writes `test_result.json`.
- `PASSED` → set `status="ship"`. Print: "3o3 complete. Run /zone-v2:shoot-play to ship." STOP.
- `FAILED`/`BLOCKED` → increment `retries.test_to_implement`. >5 → exhaustion. Else set `status="implement"`.

**Exhaustion:**
```
Zone stalled — <review|test> loop exhausted (5 retries).
Last finding: <summary>
Fix manually then re-run /zone-v2:3o3-play, or reset the retry counter in manifest.json.
```
