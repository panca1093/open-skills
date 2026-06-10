---
name: setup
description: Optional configuration for the Zone-v2 plugin — prompts for Notion DB/page IDs and the local MyBook wiki path, writes them to ~/.claude/plugins/data/zone-v2/config.json. Triggers when the user asks to "configure zone-v2", "set up zone-v2", "zone-v2 setup", or runs /zone-v2:setup. Only needed for --notion sync or a custom wiki path; /zone-v2 runs without it. Safe to re-run to update settings.
argument-hint: "[--show] [--reset]"
allowed-tools: [Read, Write, Bash, AskUserQuestion]
---

# /zone-v2:setup — Plugin Configuration

Zone-v2 reads optional configuration from `~/.claude/plugins/data/zone-v2/config.json`. This skill creates or updates that file interactively.

Config is **optional** in zone-v2: `/zone-v2` runs without it (Notion off, wiki defaults to `~/Documents/MyBook/wiki`). Run this only when you want `--notion` sync or a custom wiki path. Re-run any time to change settings.

## Arguments

- `--show` — print the current config and exit
- `--reset` — delete the existing config before prompting
- (no args) — interactive setup; prefills from existing config if present

---

## 1. Resolve config path

```bash
CONFIG_DIR="$HOME/.claude/plugins/data/zone-v2"
CONFIG_PATH="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"
```

## 2. Handle `--show`

If `$ARGUMENTS` contains `--show`:

```bash
if [ -f "$CONFIG_PATH" ]; then
  cat "$CONFIG_PATH"
else
  echo "No config yet. Run /zone-v2:setup to create one (only needed for --notion or a custom wiki path)."
fi
```

Stop.

## 3. Handle `--reset`

If `$ARGUMENTS` contains `--reset`:

```bash
rm -f "$CONFIG_PATH"
```

Then continue to step 4 (fresh setup).

## 4. Load existing config (for prefill)

If `$CONFIG_PATH` exists, read it and use values as defaults in prompts.

## 5. Prompt for values

Use the AskUserQuestion tool with these four questions (single-select with "Other" for free-text input). For each, frame the default as the recommended option if a previous value exists.

**Question 1 — Notion: Work Tasks DB ID**
"What is the Notion database ID for your work tasks (Jira path)? Leave empty to skip Notion sync for Jira mode."

**Question 2 — Notion: Personal Tasks DB ID**
"What is the Notion database ID for your personal tasks (Scratch path)? Leave empty to skip Notion sync for Scratch mode."

**Question 3 — Notion: Work spec parent page ID**
"Under which Notion page should work specs (Jira mode) be created? Use the page ID of a 'Tickets & RFCs' style parent. Leave empty to skip."

**Question 4 — Notion: Personal spec parent page ID**
"Under which Notion page should personal specs (Scratch mode) be created? Use the 'Personal' parent page ID. Leave empty to skip."

Then prompt for wiki path (separate AskUserQuestion):

**Wiki path**
"Where is your local wiki for ship-phase updates? Default: `~/Documents/MyBook/wiki`. Enter a path or pick Default."

## 6. Write config file

Write `$CONFIG_PATH` with the following structure:

```json
{
  "version": "1.0",
  "notion": {
    "work_db_id": "<answer 1 or empty>",
    "personal_db_id": "<answer 2 or empty>",
    "work_parent_id": "<answer 3 or empty>",
    "personal_parent_id": "<answer 4 or empty>"
  },
  "wiki_path": "<wiki path answer or default>"
}
```

Empty values are stored as empty strings, not omitted — keeps schema consistent.

## 7. Confirm

Tell the user:

```
Zone-v2 config written to ~/.claude/plugins/data/zone-v2/config.json

Notion sync: opt-in — pass --notion to /zone-v2 to use it (requires IDs above)
Wiki path:   <wiki_path>

Run `/zone-v2 TICKET-XXX` (Jira) or `/zone-v2` (Scratch) to start.
```
