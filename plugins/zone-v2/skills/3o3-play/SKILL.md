---
name: 3o3-play
description: Zone-v2 phase 2 — the implement→review→test loop. Three players (SF, Center, PF) in rotation with up to 5 retries per loop. Reads .claude/zone-v2/manifest.json; resumes from current status (implement/review/test). Ends with manifest.status="ship". Triggers when the user runs /zone-v2:3o3-play or when the orchestrator advances past coach-brief.
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Agent]
---

# /zone-v2:3o3-play — Implement, Review & Test

Phase 2 of the zone-v2 pipeline. SF implements task by task, Center reviews the result, PF tests it. The three rotate until all tasks are done and tests pass.

---

## 1. Load manifest

Read `.claude/zone-v2/manifest.json`.

- **No manifest** → stop: "No pipeline state found. Run /zone-v2:coach-brief first."
- **status not in {`implement`, `review`, `test`}** → stop:
  - status in {`brief`, `spec`}: "Pipeline still in brief phase. Run /zone-v2:coach-brief first."
  - status = `ship`: "Already past 3o3 — run /zone-v2:shoot-play."
  - status = `done`: "Pipeline is done."

---

## 2. Autonomous loop

**The orchestrator owns `manifest.json` — players write only their artifact files.** After each player returns, read the artifact, update manifest, decide next move.

**Efficiency:** after a player returns, do exactly three things — read its artifact, update manifest in a single Edit, emit one status line. Don't re-read files you just wrote, don't echo artifact contents, don't run exploratory Bash between dispatches.

**Stop conditions:**
- A retry counter exceeds **5** → exhaustion report (below), STOP.
- `status = "ship"` → hand-off message, STOP.
- A player returns `BLOCKED` or `NEEDS_CONTEXT` the user must resolve → STOP.

---

## 3. Phase handlers

### status `implement` → dispatch SF (`haiku`, or `sonnet` on fix)

Decide mode first:
- If `.claude/zone-v2/review_result.json` exists with `status="CHANGES_NEEDED"` → **fix mode = review** (`haiku`; `sonnet` only if `retries.review_to_implement >= 2` or finding is explicitly architectural).
- Else if `.claude/zone-v2/test_result.json` exists with `status` in {`FAILED`, `BLOCKED`} → **fix mode = test** (`haiku`; `sonnet` only if `retries.test_to_implement >= 2`).
- Else → **normal mode**:
  - If `current_task_index >= len(tasks)` → set `status="review"`, write manifest, tell user "All tasks done. Dispatching Center." Stop this handler.
  - Otherwise:
    - **If `manifest.branch` is null** (first task): create feature branch before SF runs — `git checkout -b feat/<ticket_id-or-project>-<kebab-title>` from current base. Set `manifest.branch`, write manifest.
    - Mark `tasks[current_task_index].status="in_progress"`, write manifest.

Read `players/sf.md` and dispatch SF:
- `subagent_type: "general-purpose"`, `model: "haiku"` (or `"sonnet"` per above), `description: "zone-v2 3o3-play — SF implement"`
- Runtime context: working directory, state dir, CLAUDE.md/AGENTS.md; **normal mode**: embed the current `### Task N` block from plan.md verbatim (SF must NOT re-read the whole plan.md); **fix mode**: read-before-acting is the relevant result json + the files it names.
- (Go projects) GOROOT guard in Runtime context (see zone-v2 main skill for the guard snippet).
- Notion enabled flag.

SF writes `.claude/zone-v2/task_result.json`.

After SF returns, read `task_result.json`:
- **Normal mode:**
  - `DONE` / `DONE_WITH_CONCERNS` → `tasks[current_task_index].status="done"`, increment `current_task_index`. Stay `implement`.
  - `NEEDS_CONTEXT` → AskUserQuestion with SF's question. Re-dispatch SF with answer in context. (Non-interactive and unanswerable → STOP and report.)
  - `BLOCKED` → STOP. Report SF's blocker.
- **Fix mode = review:** on `DONE`/`DONE_WITH_CONCERNS` → rename `review_result.json` → `review_prev.json`, set `status="review"`, write manifest. On `BLOCKED` → STOP.
- **Fix mode = test:** on `DONE`/`DONE_WITH_CONCERNS` → delete `test_result.json`, set `status="test"`, write manifest. On `BLOCKED` → STOP.

### status `review` → dispatch Center

**First pass** (`retries.review_to_implement == 0`) — model `sonnet`. Read before acting: `spec.md`, `plan.md`, full diff (`git diff main...HEAD` || `git diff master...HEAD` || `git diff HEAD`).

**Re-review** (`retries.review_to_implement >= 1`) — model `sonnet`, scoped. Tell Center to read `review_prev.json` (prior findings) and verify only that each prior blocker is now resolved, plus a quick regression scan. Read before acting: `review_prev.json`, `spec.md`, the diff.

Read `players/center.md` and dispatch Center:
- `subagent_type: "general-purpose"`, `model: "sonnet"`, `description: "zone-v2 3o3-play — Center review"`

Center writes `.claude/zone-v2/review_result.json`.

After Center returns:
- `APPROVED` → set `status="test"`, write manifest.
- `CHANGES_NEEDED` → increment `retries.review_to_implement`. If `> 5` → exhaustion report, STOP. Else set `status="implement"`, write manifest. "Review found N blocker(s) — routing to SF (retry <k>/5)."

### status `test` → dispatch PF (`sonnet`)

Read `players/pf.md` and dispatch PF:
- `subagent_type: "general-purpose"`, `model: "sonnet"`, `description: "zone-v2 3o3-play — PF test"`
- Read before acting: `spec.md`, `plan.md`.

If no test suite exists, PF reports `BLOCKED` ("no suite found"). Orchestrator then AskUserQuestion: add tests now, or type "skip tests" to proceed. Do not advance to ship without explicit confirmation.

PF writes `.claude/zone-v2/test_result.json`.

After PF returns:
- `PASSED` → set `status="ship"`, write manifest. STOP — hand off below.
- `FAILED` / `BLOCKED` (real impl bug) → increment `retries.test_to_implement`. If `> 5` → exhaustion report, STOP. Else set `status="implement"`, write manifest. "Tests red — routing to SF (retry <k>/5)."

---

## 4. Hand off

```
3o3 complete — all tasks done and tests green.
Run /zone-v2:shoot-play to ship.
```

---

## 5. Exhaustion report

```
Zone stalled — <review|test> loop exhausted (5 retries).

Last finding: <summary from review_result.json or test_result.json>
State preserved in .claude/zone-v2/. Fix manually, then run /zone-v2:3o3-play to resume,
or reset the relevant retry counter in manifest.json.
```
