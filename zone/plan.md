# /zone:plan — Plan Phase

Read `.zone/manifest.json`, `.zone/brief.md`, `.zone/spec.md`.

---

## Break Into Tasks

Create an ordered task list. Each task must be:
- Independently implementable (no circular dependencies)
- Small enough to TDD in one session (one logical change)
- Named with a verb phrase: "Add X", "Migrate Y", "Fix Z", "Expose X endpoint"

For each task define:
- `title` — verb phrase
- `test_cases` — list of concrete test scenarios (these become the Red phase targets)
- `files_to_touch` — best-guess list of files that will change

Aim for 3–8 tasks. One task is fine if the work is trivial.

---

## Push Tasks to Notion (skip if `manifest.notion.enabled = false`)

If `manifest.notion.enabled` is true:

For each task, create a row in the Notion DB at `manifest.notion.db_id` using `notion-create-pages`.

Set fields:
- `Task` = title
- `Status` = "To Do"
- `Ticket` = ticket_id (Jira) or project name (Scratch)
- `Spec` = Notion spec page URL (derive from `manifest.notion.spec_page_id`: `https://www.notion.so/<id-no-dashes>`)

Record each created row's Notion page ID into `manifest.notion.task_ids` in order.

---

## Update Manifest

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
Write updated `.zone/manifest.json`.

---

## Print Plan

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

Tell user: "Plan ready. Run `/zone` to start implementing."
