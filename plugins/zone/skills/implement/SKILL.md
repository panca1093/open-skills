---
name: implement
description: Zone pipeline phase 4 — runs one TDD task per invocation (Red → Green → Refactor) based on manifest.tasks[current_task_index]. Detects project language, follows its test conventions, reads CLAUDE.md/AGENTS.md for layering rules. Auto-corrects broken GOROOT on Go projects. Invoked by /zone when manifest.status="implement"; status stays "implement" until all tasks are done, then advances to "review".
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

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

### Project type detection

| Language | Detection | Test convention |
|---|---|---|
| Go | `go.mod` | Table-driven, same package, `TestFunc_Scenario` |
| Node/JS | `package.json` | Jest/Vitest `describe`/`it` blocks |
| Python | `pyproject.toml` or `requirements.txt` | pytest, `test_func_scenario` |
| Rust | `Cargo.toml` | `#[test]` in a `tests` module |
| Other | — | Match existing test style in the repo |

If a CLAUDE.md or AGENTS.md is present at the repo root, read it for layering rules and architectural conventions BEFORE writing any implementation.

### GOROOT auto-correction (Go projects only)

For Go projects, before invoking any `go` command, run this guard inline (or prefix the command):

```bash
# If GOROOT is unset, missing, or doesn't contain a Go binary, try Homebrew
if [ -z "$GOROOT" ] || [ ! -x "$GOROOT/bin/go" ]; then
  if [ -d /opt/homebrew/Cellar/go ]; then
    export GOROOT="$(ls -d /opt/homebrew/Cellar/go/*/libexec 2>/dev/null | sort -V | tail -n1)"
  fi
fi
```

This auto-detects the Homebrew Go install on machines where the system `GOROOT` env var points to a stale location. No-op on machines where GOROOT is fine.

### Red — Write failing tests first

Look at `task.test_cases`. Write tests covering all scenarios BEFORE writing any implementation.

Run the test command for the detected language:

| Language | Test command |
|---|---|
| Go | `go test ./... -race -count=1` |
| Node | `npm test` or `yarn test` |
| Python | `pytest` |
| Rust | `cargo test` |
| Other | Check for `Makefile` `test` target → `make test` |

Confirm they fail — if a test passes before any implementation, the test case is likely wrong. Fix it.

### Green — Implement

Write the minimum implementation to make the failing tests pass.

Run tests. Confirm they pass (Green).

### Refactor

Clean up: remove duplication, improve naming, simplify. Do NOT change behavior.
Run tests again to confirm still green.

---

## Complete Task

- Set `task.status = "done"` in manifest
- Update Notion row: Status = "Done" (only if `manifest.notion.enabled`)
- Increment `manifest.current_task_index`
- Write updated manifest

Tell user: "Task [N] done. Run `/zone` to continue to next task (or review if all done)."
