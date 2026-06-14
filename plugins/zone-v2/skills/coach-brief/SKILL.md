---
name: coach-brief
description: Zone-v2 phase 1 — interviews the user (Coach inline), then writes spec and plan (PG dispatched). Creates .claude/zone-v2/ and initialises manifest.json. Ends with manifest.status="implement" and manifest.tasks populated. Run before /zone-v2:3o3-play.
argument-hint: "[TICKET-ID] [--notion] [--interactive]"
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Agent]
---

## 1. Parse arguments

Strip `--notion` → `notion_flag`. Strip `--interactive` → `interactive`. If remaining matches `[A-Z]+-\d+` → `mode=jira`, `ticket_id=match`. Else → `mode=scratch`, `ticket_id=null`.

## 2. Check existing manifest

Read `.claude/zone-v2/manifest.json` if present.
- `status` in {`brief`,`spec`} → resume from current status.
- Any other status → stop: "Pipeline already past brief (status: <X>). Run /zone-v2:3o3-play or /zone-v2:shoot-play. Delete .claude/zone-v2/ to restart."
- No manifest → fresh start.

## 3. Initialize

```bash
CONFIG_PATH="$HOME/.claude/plugins/data/zone-v2/config.json"
[ -f "$CONFIG_PATH" ] && cat "$CONFIG_PATH" || echo "MISSING"
```

**Models (optional):**
```bash
M_PG=$(jq -r '.models.pg // empty' "$CONFIG_PATH" 2>/dev/null)
```
Empty = no override → omit `model` on dispatch, inherit the session model.

**Notion:** `notion_enabled = notion_flag AND work/personal db_id non-empty`. If flag but no IDs: tell user to run `/zone-v2:setup`. `db_id` = work (jira) / personal (scratch); `spec_parent` = matching parent. Disabled: both null.

**Wiki path:**
```bash
WIKI_PATH=$(jq -r '.wiki_path // "~/Documents/MyBook/wiki"' "$CONFIG_PATH" 2>/dev/null | sed "s|^~|$HOME|")
[ -z "$WIKI_PATH" ] || [ "$WIKI_PATH" = "null" ] && WIKI_PATH="$HOME/Documents/MyBook/wiki"
```

**Write manifest** (`.claude/zone-v2/manifest.json`):
```json
{
  "mode": "<jira|scratch>", "ticket_id": "<id or null>",
  "project": null, "project_dir": null, "interactive": <bool>,
  "wiki_path": "<resolved>",
  "notion": { "enabled": <bool>, "spec_parent": null, "spec_page_id": null, "db_id": null },
  "tasks": [], "current_task_index": 0,
  "retries": { "review_to_implement": 0, "test_to_implement": 0 },
  "branch": null, "pr_url": null, "status": "brief"
}
```

## 4. Brief — Coach (INLINE)

Read `players/coach.md` and embody inline (needs AskUserQuestion — can't be subagent).

**Jira:** fetch via `mcp__atlassian-jira__getJiraIssue` or ask user to paste. Load context first: `MEMORY.md`, wiki index, `git log --oneline -20`, `git branch -a`, repo layout, `CLAUDE.md`/`AGENTS.md`/`README.md`. Interview (≤5 AskUserQuestion, each showing why). Cover: unstated AC, affected services, edge cases, breaking changes, inflight deps.

**Scratch:** AskUserQuestion until precise (problem, users, success, existing code, constraints). Ask project name → `manifest.project`. If `project_dir` null: `mkdir -p <cwd>/<name>`, git init, set `manifest.project_dir`.

**Both:** write `brief.md` (Base Axioms / User Interfaces / Architectural Layers: Contract·Domain·Persistence / Out of scope). Set `status="spec"`, write manifest.

## 5. Spec + Plan — dispatch PG (`M_PG`)

Read `players/pg.md`. Dispatch:
- `subagent_type: "general-purpose"`, `description: "zone-v2 coach-brief — PG"`; pass `model: M_PG` only if non-empty.
- Runtime context: working dir, state dir `.claude/zone-v2/`, read-before-acting: `brief.md` + `CLAUDE.md`/`AGENTS.md`.

PG writes `spec.md` + `plan.md`.

After PG: extract `### Task N: <title>` headings from `plan.md` → `manifest.tasks` (all pending, index=0). If Notion: create spec page, task rows. Set `status="implement"`, write manifest.

Tell user: "Brief, spec, plan done — <N> tasks ready. Run /zone-v2:3o3-play to implement."
