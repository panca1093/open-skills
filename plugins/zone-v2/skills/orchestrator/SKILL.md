---
name: orchestrator
description: Spec-driven development pipeline (subagent-driven). Use when the user types /zone-v2:orchestrator, asks to "run zone-v2", or wants an autonomous brief→spec→plan→implement→review→test→ship flow where each phase runs as a dispatched agent ("player"). One orchestrator skill defines who runs each phase; player personas live in players/. State flows through .claude/zone-v2/ files. Reads/writes .claude/zone-v2/manifest.json.
argument-hint: "[TICKET-ID] [--notion] [--interactive]"
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Agent]
---

# /zone-v2:orchestrator — Subagent-Driven Development Pipeline

One command, seven phases, autonomous by default. Each phase runs as a player on the court. The orchestrator (this file, running in the main session) drives the loop; every phase except `brief` is a **dispatched Agent** carrying that phase's persona. State flows through `.claude/zone-v2/` files only — subagents cold-start and never share memory.

Name inspired by Kuroko's Basketball — entering the Zone is peak performance, and each phase is a position on the court: coach, point guard, small forward, center, power forward, shooting guard.

## Model tiers

| Player | Phase | Model | Notes |
|--------|-------|-------|-------|
| coach | brief | (inline, current session) | interviews the user — cannot be a subagent |
| pg | spec + plan | `sonnet` | reasoning-heavy, runs once |
| sf | implement | `haiku` (fixes stay `haiku`; → `sonnet` only on 2nd+ retry of the same finding, or an explicitly architectural fix) | the loop hammers this — keep it cheap |
| center | review | `sonnet` first pass → `sonnet` re-review | scoped re-reviews after a fix run |
| pf | test | `sonnet` | |
| sg | ship | `sonnet` | |

Dispatched phases use `subagent_type: "general-purpose"` with the `model` above. Persona `permissions` (read-only, etc.) are advisory — enforced by the persona prompt, not a hard sandbox.

---

## Arguments

`$ARGUMENTS` can be:
- A Jira ticket ID matching `[A-Z]+-\d+` (e.g. `LOAN-1234`) → **Jira path**
- Empty → **Scratch path** (personal/side project)
- `--notion` — opt in to Notion sync (off by default; requires configured IDs)
- `--interactive` — stop after each phase; user re-runs `/zone-v2:orchestrator` to continue (default: autonomous)

---

## 1. Determine mode and flags

Strip `--notion` → `notion_flag = true` if found, else `false`.
Strip `--interactive` → `interactive = true` if found, else `false`.

- If remaining argument matches `[A-Z]+-\d+` → `mode = "jira"`, `ticket_id = match`
- Otherwise → `mode = "scratch"`, `ticket_id = null`

---

## 2. Check session state

Look for `.claude/zone-v2/manifest.json` in the current working directory.

**If it exists:** read it, resume from `manifest.status`, skip to step 4.
**If not:** continue to step 3.

---

## 3. Initialize new session

### 3a. Load plugin config (optional)

```bash
CONFIG_PATH="$HOME/.claude/plugins/data/zone-v2/config.json"
[ -f "$CONFIG_PATH" ] && cat "$CONFIG_PATH" || echo "MISSING"
```

Missing config is fine — proceed with Notion disabled and the default wiki path. Only mention `/zone-v2:setup` if the user passed `--notion`.

### 3b. Derive Notion config

`notion_enabled = notion_flag AND (config.notion.work_db_id OR config.notion.personal_db_id non-empty)`.
- If enabled: `db_id` = work_db_id (jira) or personal_db_id (scratch); `spec_parent` = work_parent_id (jira) or personal_parent_id (scratch).
- Else: `db_id = null`, `spec_parent = null`.

If `notion_flag` but no IDs for the mode:
```
--notion requested but no <work|personal> Notion IDs configured. Run /zone-v2:setup, or drop --notion.
```

### 3c. Determine wiki path

```bash
WIKI_PATH=$(jq -r '.wiki_path // "~/Documents/MyBook/wiki"' "$CONFIG_PATH" 2>/dev/null | sed "s|^~|$HOME|")
[ -z "$WIKI_PATH" ] || [ "$WIKI_PATH" = "null" ] && WIKI_PATH="$HOME/Documents/MyBook/wiki"
echo "$WIKI_PATH"
```

### 3d. Write manifest

Create `.claude/zone-v2/` and write `.claude/zone-v2/manifest.json`:

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
  "retries": { "review_to_implement": 0, "test_to_implement": 0 },
  "branch": null,
  "pr_url": null,
  "status": "brief"
}
```

`manifest.tasks` entries are lightweight trackers: `{ "title": "...", "status": "pending|in_progress|done", "notion_page_id": null }`. The full task detail (files, done-when) lives in `.claude/zone-v2/plan.md`.

---

## 4. Execute pipeline

**The orchestrator owns `manifest.json` — it is the single writer.** Dispatched players write only their artifact files (`spec.md`, `plan.md`, `task_result.json`, `review_result.json`, `test_result.json`) and return a one-line summary. After each player returns, the orchestrator reads the artifact, updates the manifest, and decides the next move.

### Dispatch contract (used by every dispatched phase)

To dispatch a player, call the **Agent** tool with:
- `subagent_type: "general-purpose"`
- `model:` the tier from the table above
- `description:` `"zone-v2 <phase>"`
- `prompt:` the content of `players/<name>.md` (read it first) followed by a **Runtime context** block:

```
## Runtime context
- Working directory: <manifest.project_dir or cwd>
- State directory: .claude/zone-v2/ (all paths below are relative to the working directory)
- Read before acting: <phase-specific list>
- Convention files: read CLAUDE.md / AGENTS.md at the repo root if present — they define layering, naming, and PR conventions.
- (Go projects) Run `go` commands plainly (`go build ./...`, `go test ./...`). GOROOT is set per-project by `/zone-v2:setup` in `.claude/settings.local.json` `env` — this fixes the broken-GOROOT machine AND keeps commands matchable against the allowlist (a compound `... && go build` would bypass `Bash(go build *)`). ONLY if a `go` command fails with a GOROOT / `package unsafe is not in std` error, prepend this one-time guard and retry:
    if [ -z "$GOROOT" ] || [ ! -x "$GOROOT/bin/go" ]; then
      [ -d /opt/homebrew/Cellar/go ] && export GOROOT="$(ls -d /opt/homebrew/Cellar/go/*/libexec 2>/dev/null | sort -V | tail -n1)";
    fi
- Notion enabled: <true|false>  (skip all Notion steps if false)
- Current task index: <n>  (implement only)
- Current task block: <the full `### Task N` block copied verbatim from plan.md>  (implement, normal mode — SF works from this and must NOT re-read the whole plan.md)
- Fix mode: <none | review | test>  (implement only — see below)

## Your deliverable
- Write <result file> exactly per your output contract.
- Do NOT modify .claude/zone-v2/manifest.json — the orchestrator owns it.
- Return ONE line: your result status + a short summary.
```

### Autonomous loop (default: `manifest.interactive = false`)

1. Note `manifest.status` as `prev_status`.
2. Run the phase per its handler below (inline for `brief`, dispatch for the rest).
3. Read the produced artifact, update the manifest accordingly.
4. Apply stop conditions:
   - A retry counter exceeds **5** → write the exhaustion report (below), **STOP**.
   - `status = "done"` → print completion summary, **STOP**.
   - A player returns `BLOCKED` or `NEEDS_CONTEXT` that the user must resolve → **STOP** (or ask, see handlers).
5. Otherwise loop from step 1.

`implement` stays `"implement"` across iterations (one SF dispatch per task, or per fix). Keep looping until it advances to `"review"`.

**Orchestrator efficiency (keep your own context lean — across a full run you are the single biggest token line):** after a player returns, do exactly three things — read its one artifact, update the manifest in a single Edit, emit one status line. Don't re-read files you just wrote, don't echo artifact contents back into the conversation, don't run exploratory Bash between phases, and hold narration to one line per transition.

### Interactive mode (`manifest.interactive = true`)

Run only the current phase, then stop. The user re-runs `/zone-v2:orchestrator`.

---

## Phase handlers

### status `brief` → Coach (INLINE — runs in this session)

Brief cannot be a subagent: Coach interviews the user, and dispatched agents can't run AskUserQuestion. So read `players/coach.md` and embody that persona **inline** here.

**Jira path:**
1. Fetch the ticket: if `mcp__atlassian-jira__getJiraIssue` is callable, call it with `ticket_id`; else AskUserQuestion: "Jira MCP isn't loaded — paste the ticket title + description."
2. Load context yourself before asking anything (Coach's "discover before asking"): read `~/.claude/projects/-Users-Panca-Documents-MyBook/memory/MEMORY.md` if present, `<wiki_path>/index.md`, `git log --oneline -20`, `git branch -a`, repo layout (`find . -name "*.go" -o -name "*.ts" -o -name "*.py" | head -30`), and `CLAUDE.md`/`AGENTS.md`/`README.md`.
3. Interview with AskUserQuestion (≤5), each question showing why you ask. Cover unstated acceptance criteria, affected services, edge cases, breaking-change handling, inflight dependencies.

**Scratch path:**
1. Brainstorm with AskUserQuestion until the idea is precise (problem, users, success, existing code, constraints).
2. Ask the project name; set `manifest.project`.
3. If `manifest.project_dir` is null: `mkdir -p "<cwd>/<project-name>"`, `git -C` init if needed, set `manifest.project_dir` to the absolute path, write manifest. Tell the user where implementation will live.

**Both paths — write `.claude/zone-v2/brief.md`** in Coach's structure (Base Axioms / User Interfaces / Architectural Layers: Contract/Domain/Persistence / Out of scope).

Then set `manifest.status = "spec"`, write manifest.
- If interactive: "Brief done. Run `/zone-v2:orchestrator` to continue to spec."
- Else: "Brief done. Dispatching PG for spec + plan."

### status `spec` → dispatch PG (`sonnet`)

Read before acting: `.claude/zone-v2/brief.md`. Read `players/pg.md` and dispatch PG. PG writes `.claude/zone-v2/spec.md` and `.claude/zone-v2/plan.md`.

After PG returns:
1. Read `.claude/zone-v2/plan.md`, extract its task list (each `### Task N: <title>` heading).
2. Set `manifest.tasks = [{title, status:"pending", notion_page_id:null}, ...]` in plan order; `manifest.current_task_index = 0`.
3. If `notion.enabled`: create the Notion spec page under `spec_parent` from `spec.md`, record `manifest.notion.spec_page_id`; create a To-Do row per task in `db_id`, record each `notion_page_id`.
4. Set `manifest.status = "implement"`, write manifest.
5. Tell user: "Spec + plan ready (N tasks). Dispatching SF." (interactive: "Run `/zone-v2:orchestrator` to start implementing.")

### status `implement` → dispatch SF (`haiku`, or `sonnet` on fix)

Decide the mode first:
- If `.claude/zone-v2/review_result.json` exists with `status="CHANGES_NEEDED"` → **fix mode = review** (model `haiku`; use `sonnet` only if `retries.review_to_implement >= 2` or a finding is explicitly architectural).
- Else if `.claude/zone-v2/test_result.json` exists with `status` in {`FAILED`,`BLOCKED`} → **fix mode = test** (model `haiku`; use `sonnet` only if `retries.test_to_implement >= 2`).
- Else → **normal mode**:
  - If `current_task_index >= len(tasks)` → set `status="review"`, write manifest, tell user "All tasks done. Dispatching Center for review." Stop this handler.
  - Otherwise (a task remains):
    - **If `manifest.branch` is null** (first task): create the feature branch *before* SF runs, so its per-task commits land there and `git diff main...HEAD` stays meaningful for review. `git checkout -b feat/<ticket_id-or-project>-<kebab-title>` from the current base (`main`/`master`). Set `manifest.branch`, write manifest.
    - Mark `tasks[current_task_index].status="in_progress"` (and Notion row "In Progress" if enabled), write manifest.

Read `players/sf.md` and dispatch SF. In **normal mode**, embed the current task's `### Task N` block in the Runtime context (above) and tell SF to work from it — Read-before-acting is only `.claude/zone-v2/spec.md` (the requirements this task implements), NOT the whole `plan.md`. In **fix mode**, Read-before-acting is the relevant `review_result.json` / `test_result.json` plus the files they name. SF writes `.claude/zone-v2/task_result.json`.

After SF returns, read `task_result.json`:
- **Normal mode:**
  - `DONE` / `DONE_WITH_CONCERNS` → set `tasks[current_task_index].status="done"` (Notion "Done" if enabled), increment `current_task_index`. Stay `implement` (loop dispatches the next task, or advances to review when index passes the end).
  - `NEEDS_CONTEXT` → AskUserQuestion with SF's `question`. Re-dispatch SF with the answer appended to context. (If non-interactive and unanswerable, STOP and report.)
  - `BLOCKED` → STOP. Report SF's `blocker`. Stay `implement` for the user to resolve.
- **Fix mode = review:** on `DONE`/`DONE_WITH_CONCERNS`, **rename `.claude/zone-v2/review_result.json` → `.claude/zone-v2/review_prev.json`** (preserve the findings so the re-review can be scoped), set `status="review"`, write manifest (re-review). On `BLOCKED`, STOP.
- **Fix mode = test:** on `DONE`/`DONE_WITH_CONCERNS`, delete `.claude/zone-v2/test_result.json`, set `status="test"`, write manifest (re-test). On `BLOCKED`, STOP.

### status `review` → dispatch Center

**First pass** (`retries.review_to_implement == 0`) — model `sonnet`. Read before acting: `.claude/zone-v2/spec.md`, `.claude/zone-v2/plan.md`, plus the full diff (`git diff main...HEAD` || `git diff master...HEAD` || `git diff HEAD`).

**Re-review** (`retries.review_to_implement >= 1`, i.e. a fix run just happened) — model `sonnet`, **scoped**. Tell Center to read `.claude/zone-v2/review_prev.json` (the prior findings) and verify *only* that each prior `blocker` is now resolved, plus a quick regression scan of the changed files — not a fresh full-spec review. Read before acting: `.claude/zone-v2/review_prev.json`, `.claude/zone-v2/spec.md`, and the diff.

Read `players/center.md` and dispatch Center. Center writes `.claude/zone-v2/review_result.json`.

After Center returns:
- `APPROVED` → set `status="test"`, write manifest. "Review passed. Dispatching PF for tests."
- `CHANGES_NEEDED` → increment `manifest.retries.review_to_implement`.
  - If `> 5` → exhaustion report, STOP.
  - Else set `status="implement"`, write manifest (SF picks up fix mode = review, at `haiku` — `sonnet` only on the 2nd+ retry). "Review found N blocker(s) — routing back to SF (retry <k>/5)."

### status `test` → dispatch PF (`sonnet`)

Read before acting: `.claude/zone-v2/spec.md`, `.claude/zone-v2/plan.md`. Read `players/pf.md` and dispatch PF. PF writes `.claude/zone-v2/test_result.json`.

If no test suite exists, PF reports `BLOCKED` with "no suite found" rather than passing silently. The orchestrator then AskUserQuestion: add tests now, or type "skip tests" to proceed. Do not advance to ship without explicit confirmation.

After PF returns:
- `PASSED` → set `status="ship"`, write manifest. "Tests green. Dispatching SG to ship."
- `FAILED` / `BLOCKED` (real impl bug) → increment `manifest.retries.test_to_implement`.
  - If `> 5` → exhaustion report, STOP.
  - Else set `status="implement"`, write manifest (SF picks up fix mode = test, at `haiku` — `sonnet` only on the 2nd+ retry). "Tests red — routing back to SF (retry <k>/5)."

### status `ship` → dispatch SG (`sonnet`)

Precondition: `.claude/zone-v2/test_result.json` is `PASSED`. If not, set `status="test"` and loop instead of shipping.

Read before acting: `.claude/zone-v2/manifest.json`, `.claude/zone-v2/spec.md`, `.claude/zone-v2/brief.md`, `.claude/zone-v2/test_result.json`. Read `players/sg.md` and dispatch SG. The feature branch already exists (`manifest.branch`, created at implement start, with SF's per-task commits on it). SG pushes that branch, commits any leftover, opens the PR, syncs Notion (if enabled), and returns the branch + PR URL in its summary. SG must **not** write the manifest.

After SG returns:
1. Set `manifest.branch`, `manifest.pr_url` from SG's summary.
2. Update the local wiki at `manifest.wiki_path` (Jira → `tickets/<ticket_id>.md`; Scratch → `personal/<project>.md`), plus `index.md` and `log.md`; sync to Notion if enabled.
3. Set `manifest.status = "done"`, write manifest.

### Completion summary (`status = "done"`)

```
Zone complete. You're in the zone.

PR:     <manifest.pr_url or commit hash>
Branch: <manifest.branch>
Spec:   <https://www.notion.so/<spec_page_id no-dashes> — omit if Notion disabled>
Wiki:   <manifest.wiki_path>/...
```

### Exhaustion report (a retry counter exceeded 5)

```
Zone stalled — <review|test> loop exhausted (5 retries).

Last finding: <summary from review_result.json or test_result.json>
State preserved in .claude/zone-v2/. Fix manually, then run /zone-v2:orchestrator to resume,
or reset the relevant retry counter in manifest.json.
```

---
