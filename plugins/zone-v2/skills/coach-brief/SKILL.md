---
name: coach-brief
description: Zone-v2 phase 1 — interviews the user (Coach inline), then writes spec and plan (PG dispatched). Creates a fresh .claude/zone-v2/ state directory and initialises manifest.json. Ends with manifest.status="implement" and manifest.tasks populated. Triggers when the user runs /zone-v2:coach-brief or wants to start a new zone-v2 pipeline from scratch.
argument-hint: "[TICKET-ID] [--notion] [--interactive]"
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Agent]
---

# /zone-v2:coach-brief — Brief, Spec & Plan

Phase 1 of the zone-v2 pipeline. Coach sets direction via user interview; PG turns it into a spec and a task plan. Everything else builds on what this phase produces.

---

## 1. Parse arguments

Strip `--notion` → `notion_flag = true` if found, else `false`.
Strip `--interactive` → `interactive = true` if found, else `false`.

- If remaining argument matches `[A-Z]+-\d+` → `mode = "jira"`, `ticket_id = match`
- Otherwise → `mode = "scratch"`, `ticket_id = null`

---

## 2. Check for existing manifest

Look for `.claude/zone-v2/manifest.json` in the current working directory.

- **No manifest** → continue to step 3 (fresh start).
- **manifest.status in {`brief`, `spec`}** → resume: skip to step 3b (re-read existing manifest values) and pick up from the current status.
- **Any other status** → stop and tell the user:
  ```
  Pipeline already past the brief phase (status: <status>).
  Run /zone-v2:3o3-play to implement, or /zone-v2:shoot-play to ship.
  To restart from scratch, delete .claude/zone-v2/ and re-run.
  ```

---

## 3. Initialise session

### 3a. Load plugin config (optional)

```bash
CONFIG_PATH="$HOME/.claude/plugins/data/zone-v2/config.json"
[ -f "$CONFIG_PATH" ] && cat "$CONFIG_PATH" || echo "MISSING"
```

Missing config is fine — proceed with Notion disabled and the default wiki path. Only mention `/zone-v2:setup` if the user passed `--notion`.

### 3b. Derive Notion config

`notion_enabled = notion_flag AND (config.notion.work_db_id OR config.notion.personal_db_id non-empty)`.
- Enabled: `db_id` = work_db_id (jira) or personal_db_id (scratch); `spec_parent` = work_parent_id (jira) or personal_parent_id (scratch).
- Disabled: `db_id = null`, `spec_parent = null`.

If `notion_flag` but no IDs:
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

---

## 4. Brief phase — Coach (INLINE)

Brief cannot be a subagent: Coach interviews the user, and dispatched agents can't run AskUserQuestion. Read `players/coach.md` and embody that persona inline here.

**Jira path:**
1. Fetch the ticket: if `mcp__atlassian-jira__getJiraIssue` is callable, call it with `ticket_id`; else AskUserQuestion: "Jira MCP isn't loaded — paste the ticket title + description."
2. Load context before asking (Coach's "discover before asking"): read `~/.claude/projects/-Users-Panca-Documents-MyBook/memory/MEMORY.md` if present, `<wiki_path>/index.md`, `git log --oneline -20`, `git branch -a`, repo layout (`find . -name "*.go" -o -name "*.ts" -o -name "*.py" | head -30`), and `CLAUDE.md`/`AGENTS.md`/`README.md`.
3. Interview with AskUserQuestion (≤5 questions), each showing why you ask. Cover unstated acceptance criteria, affected services, edge cases, breaking-change handling, inflight dependencies.

**Scratch path:**
1. Brainstorm with AskUserQuestion until the idea is precise (problem, users, success, existing code, constraints).
2. Ask the project name; set `manifest.project`.
3. If `manifest.project_dir` is null: `mkdir -p "<cwd>/<project-name>"`, git init if needed, set `manifest.project_dir` to the absolute path, write manifest. Tell the user where implementation will live.

**Both paths — write `.claude/zone-v2/brief.md`** (Coach structure: Base Axioms / User Interfaces / Architectural Layers: Contract/Domain/Persistence / Out of scope).

Set `manifest.status = "spec"`, write manifest.

---

## 5. Spec + Plan phase — dispatch PG (`sonnet`)

Read `players/pg.md` and dispatch PG with:
- `subagent_type: "general-purpose"`, `model: "sonnet"`, `description: "zone-v2 coach-brief — PG spec+plan"`
- Runtime context: working directory, state directory `.claude/zone-v2/`, read-before-acting: `.claude/zone-v2/brief.md` + CLAUDE.md/AGENTS.md.

PG writes `.claude/zone-v2/spec.md` and `.claude/zone-v2/plan.md`.

After PG returns:
1. Read `.claude/zone-v2/plan.md`, extract its task list (each `### Task N: <title>` heading).
2. Set `manifest.tasks = [{title, status:"pending", notion_page_id:null}, ...]` in plan order; `manifest.current_task_index = 0`.
3. If `notion.enabled`: create the Notion spec page under `spec_parent` from `spec.md`, record `manifest.notion.spec_page_id`; create a To-Do row per task in `db_id`, record each `notion_page_id`.
4. Set `manifest.status = "implement"`, write manifest.

---

## 6. Hand off

```
Brief, spec, and plan done — <N> tasks ready.
Run /zone-v2:3o3-play to start implementing.
```

If `interactive`:
```
Brief, spec, and plan done — <N> tasks ready.
Run /zone-v2:3o3-play when ready.
```
