# /zone — Spec-Driven Development Pipeline

Entry point for Zone: one command, seven steps, no manual handoffs. Takes an idea from brief to shipped PR.

Name inspired by Kuroko's Basketball — entering the Zone is peak performance state where everything flows perfectly.

## Arguments

`$ARGUMENTS` is either:
- A Jira ticket ID like `LOAN-1234` → **Jira path** (TDD, formal spec, Notion Tasks — Work)
- Empty → **Scratch path** (personal/side project, Notion Tasks — Personal)
- `--no-notion` can be appended to either to disable Notion sync for this session

---

## 1. Determine Mode

Strip `--no-notion` from `$ARGUMENTS` if present. Set `notion_flag = false` if found, otherwise `true`.

- If remaining arguments match pattern `[A-Z]+-\d+` → `mode = "jira"`, `ticket_id = that match`
- Otherwise → `mode = "scratch"`

---

## 2. Check Session State

Look for `.zone/manifest.json` in the current working directory.

**If manifest exists:** Read it. Resume from `manifest.status`. Skip to step 4.

**If no manifest:** Continue to step 3.

---

## 3. Initialize New Session

Read Notion config from environment by running:
```bash
printf '%s\n' "$ZONE_NOTION_WORK_DB_ID" "$ZONE_NOTION_PERSONAL_DB_ID" "$ZONE_NOTION_WORK_PARENT_ID" "$ZONE_NOTION_PERSONAL_PARENT_ID"
```

Derive:
- `notion_enabled = notion_flag AND (ZONE_NOTION_WORK_DB_ID or ZONE_NOTION_PERSONAL_DB_ID is non-empty)`
- If `notion_enabled`:
  - `db_id` = `ZONE_NOTION_WORK_DB_ID` (jira) or `ZONE_NOTION_PERSONAL_DB_ID` (scratch)
  - `spec_parent` = `ZONE_NOTION_WORK_PARENT_ID` (jira) or `ZONE_NOTION_PERSONAL_PARENT_ID` (scratch)
- Else: `db_id = null`, `spec_parent = null`

If `notion_flag` is true but all vars are empty, tell user: "Notion env vars not set — run install.sh to configure. Proceeding without Notion."

Create `.zone/` directory. Write `.zone/manifest.json`:

```json
{
  "version": "1.0",
  "mode": "<jira|scratch>",
  "ticket_id": "<TICKET-XXXX or null>",
  "project": null,
  "brief_path": ".zone/brief.md",
  "spec_path": ".zone/spec.md",
  "notion": {
    "enabled": "<notion_enabled>",
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

## 4. Execute Current Step

Read the sub-skill file for `manifest.status` and follow its instructions exactly.

| status | file to read and execute |
|--------|--------------------------|
| `brief` | `ZONE_COMMANDS_DIR/zone/brief.md` |
| `spec` | `ZONE_COMMANDS_DIR/zone/spec.md` |
| `plan` | `ZONE_COMMANDS_DIR/zone/plan.md` |
| `implement` | `ZONE_COMMANDS_DIR/zone/implement.md` |
| `review` | `ZONE_COMMANDS_DIR/zone/review.md` |
| `test` | `ZONE_COMMANDS_DIR/zone/test.md` |
| `ship` | `ZONE_COMMANDS_DIR/zone/ship.md` |
| `done` | Print the PR URL from manifest and: "Zone complete. You're in the zone." |

Read the file now, then follow its instructions completely before responding to the user.
