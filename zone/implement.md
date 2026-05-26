# /zone:implement — TDD Implementation Loop

Read `.zone/manifest.json`.

---

## Check Completion

If `manifest.current_task_index >= len(manifest.tasks)`:
  - Set `manifest.status = "review"`. Write manifest.
  - Tell user: "All tasks done. Run `/zone` to start review."
  - Stop.

---

## Current Task

Get task at `manifest.tasks[manifest.current_task_index]`.

Print: `Working on task [<index+1>/<total>]: <title>`

Update task status to `in_progress`:
- In manifest: `task.status = "in_progress"`
- In Notion (only if `manifest.notion.enabled`): update `task.notion_page_id` row, Status = "In Progress"
- Write updated manifest.

---

## TDD Loop

### Red — Write failing tests first

Look at `task.test_cases`. Write tests covering all scenarios BEFORE writing any implementation.

Detect the project type and follow its conventions:

| Language | Detection | Test convention |
|---|---|---|
| Go | `go.mod` | Table-driven, same package, `TestFunc_Scenario` |
| Node/JS | `package.json` | Jest/Vitest `describe`/`it` blocks |
| Python | `pyproject.toml` or `requirements.txt` | pytest, `test_func_scenario` |
| Rust | `Cargo.toml` | `#[test]` in a `tests` module |
| Other | — | Match existing test style in the repo |

If a CLAUDE.md or AGENTS.md is present at the repo root, read it for layering rules and architectural conventions before writing any implementation.

Run tests. Confirm they fail — if a test passes before any implementation, the test case is likely wrong. Fix it.

**Test command by language:**
- Go: `go test ./... -race -count=1`
- Node: `npm test` or `yarn test`
- Python: `pytest`
- Rust: `cargo test`
- Other: check for a `Makefile` `test` target → `make test`

### Green — Implement

Write the minimum implementation to make the failing tests pass.

Run tests. Confirm they pass (Green).

### Refactor

Clean up: remove duplication, improve naming, simplify. Do not change behavior.
Run tests again to confirm still green.

---

## Complete Task

- Set `task.status = "done"` in manifest
- Update Notion row: Status = "Done" (only if `manifest.notion.enabled`)
- Increment `manifest.current_task_index`
- Write updated manifest

Tell user: "Task [N] done. Run `/zone` to continue to next task (or review if all done)."
