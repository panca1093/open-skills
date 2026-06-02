---
name: zone
description: Spec-driven development pipeline. Use when the user types /zone, asks to "run zone", "start a zone session", invokes the zone pipeline for a Jira ticket (e.g. /zone LOAN-1234), or wants an autonomous brief→spec→plan→implement→review→test→ship flow. The single entry point that orchestrates the seven sub-skills (brief, spec, plan, implement, review, test, ship). Reads/writes .zone/manifest.json to track state across phases.
argument-hint: "[TICKET-ID] [--no-notion] [--interactive]"
allowed-tools: [Read, Write, Edit, Bash, Skill]
---

# /zone — Spec-Driven Development Pipeline

One command, seven phases, autonomous by default. Takes an idea from brief to shipped PR.

Name inspired by Kuroko's Basketball — entering the Zone is peak performance state where everything flows perfectly.

## Arguments

`$ARGUMENTS` can be:
- A Jira ticket ID matching `[A-Z]+-\d+` (e.g. `LOAN-1234`) → **Jira path** (TDD, formal spec, Notion Tasks — Work)
- Empty → **Scratch path** (personal/side project, Notion Tasks — Personal)
- `--no-notion` — disable Notion sync for this session
- `--interactive` — pause after each phase and wait for `/zone` to be re-run (default: autonomous)

---

## 1. Determine mode and flags

Strip `--no-notion` from `$ARGUMENTS` if present → `notion_flag = false` if found, else `true`.
Strip `--interactive` from `$ARGUMENTS` if present → `interactive = true` if found, else `false`.

- If remaining argument matches `[A-Z]+-\d+` → `mode = "jira"`, `ticket_id = match`
- Otherwise → `mode = "scratch"`, `ticket_id = null`

---

## 2. Check session state

Look for `.zone/manifest.json` in the current working directory.

**If manifest exists:** Read it. Resume from `manifest.status`. Skip to step 4.

**If no manifest:** Continue to step 3.

---

## 3. Initialize new session

### 3a. Load plugin config

Read the plugin config file:

```bash
CONFIG_PATH="$HOME/.claude/plugins/data/zone/config.json"
if [ -f "$CONFIG_PATH" ]; then
  cat "$CONFIG_PATH"
else
  echo "MISSING"
fi
```

If the file is missing, tell the user:

```
Zone config not found at ~/.claude/plugins/data/zone/config.json

Run `/zone:setup` first to configure Notion IDs and wiki path, or run `/zone --no-notion` to proceed without Notion.
```

If the user passed `--no-notion`, proceed without config (Notion-disabled, wiki path defaults).

### 3b. Derive Notion config

From the loaded config:
- `notion_enabled = notion_flag AND (config.notion.work_db_id OR config.notion.personal_db_id is non-empty)`
- If `notion_enabled`:
  - `db_id` = `config.notion.work_db_id` (jira) or `config.notion.personal_db_id` (scratch)
  - `spec_parent` = `config.notion.work_parent_id` (jira) or `config.notion.personal_parent_id` (scratch)
- Else: `db_id = null`, `spec_parent = null`

If `notion_flag` is true but no IDs are configured for the chosen mode, tell user:
```
Notion sync requested but no <work|personal> Notion IDs configured. Run /zone:setup to add them, or pass --no-notion to skip.
```

### 3c. Determine wiki path

```bash
WIKI_PATH=$(jq -r '.wiki_path // "~/Documents/MyBook/wiki"' "$CONFIG_PATH" 2>/dev/null | sed "s|^~|$HOME|")
[ -z "$WIKI_PATH" ] || [ "$WIKI_PATH" = "null" ] && WIKI_PATH="$HOME/Documents/MyBook/wiki"
echo "$WIKI_PATH"
```

Store this for later phases.

### 3d. Write manifest

Create `.zone/` directory if missing. Write `.zone/manifest.json`:

```json
{
  "version": "2.0",
  "mode": "<jira|scratch>",
  "ticket_id": "<TICKET-XXXX or null>",
  "project": null,
  "project_dir": null,
  "interactive": <true|false>,
  "brief_path": ".zone/brief.md",
  "spec_path": ".zone/spec.md",
  "wiki_path": "<resolved wiki path>",
  "notion": {
    "enabled": <true|false>,
    "spec_parent": "<spec_parent or null>",
    "spec_page_id": null,
    "db_id": "<db_id or null>",
    "task_ids": []
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

### Invoke a phase

Always use the Skill tool to invoke phases (this plugin assumes Claude Code or compatible). The mapping:

| status | skill to invoke |
|--------|-----------------|
| `brief` | `zone:brief` |
| `spec` | `zone:spec` |
| `plan` | `zone:plan` |
| `implement` | `zone:implement` |
| `review` | `zone:review` |
| `test` | `zone:test` |
| `ship` | `zone:ship` |

### Autonomous mode (default: `manifest.interactive = false`)

Run phases in a continuous loop:

1. Note the current `manifest.status` as `prev_status`
2. Invoke the phase skill from the mapping above
3. Re-read `.zone/manifest.json` to get `new_status`
4. Apply stop conditions:
   - `prev_status = "review"` AND `new_status = "implement"` → **STOP** (review found blockers — tell user to fix then re-run `/zone`)
   - `prev_status = "test"` AND `new_status = "implement"` → **STOP** (tests failing — tell user to fix then re-run `/zone`)
   - `new_status = "done"` → **STOP** — print completion summary (see below)
5. Otherwise: go back to step 1 and continue

For `implement`: status legitimately stays `"implement"` across multiple invocations (one task per invocation). Keep looping until status advances to `"review"`.

### Interactive mode (`manifest.interactive = true`)

Execute only the current phase. After it completes, stop. Do not advance to the next phase — the user re-runs `/zone` manually.

### Completion summary (`status = "done"`)

```
Zone complete. You're in the zone.

PR:     <manifest.pr_url or commit hash>
Branch: <manifest.branch>
Spec:   <https://www.notion.so/<spec_page_id no-dashes> — omit if Notion disabled>
Wiki:   <manifest.wiki_path>/...  (set by ship)
```
