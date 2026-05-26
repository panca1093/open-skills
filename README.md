# zone-skill

A spec-driven development pipeline as a custom slash command for AI coding tools. One command takes an idea from brief to shipped PR — no manual handoffs.

Inspired by Kuroko no Basket — entering the Zone is peak performance state where everything flows.

## What is spec-driven development?

Most AI-assisted coding starts from a vague prompt and jumps straight to implementation. The AI writes code, you review it, realize the scope was wrong, and iterate. The output drives the thinking.

Spec-driven development inverts this. Before any code is written, you and the AI align on:

- **What problem is actually being solved** (brief)
- **Exactly what will be built and what won't** (spec)
- **What the concrete test cases are** (plan)

Only then does implementation begin — and it's constrained by the spec, not improvised from it.

The payoff: the AI implements exactly what was agreed, tests prove the spec was met, and the PR description writes itself from the artifacts already produced.

## Pipeline

```
brief → spec → plan → implement → review → test → ship
```

| Step | What happens | Artifact |
|---|---|---|
| **brief** | Clarifying Q&A — surfaces edge cases, constraints, affected files | `.zone/brief.md` |
| **spec** | Formal write-up: problem, solution, scope, API changes, acceptance criteria | `.zone/spec.md` |
| **plan** | Breaks spec into ordered TDD tasks, each with concrete test scenarios | manifest `tasks[]` |
| **implement** | TDD loop per task: write failing tests → implement → refactor → repeat | source + test files |
| **review** | Self-review against spec ACs, layering rules, security, concurrency | pass / block list |
| **test** | Full test suite run with `-race` and `-shuffle` (Go) or equivalent | green / failing |
| **ship** | Branch + commit + PR, Notion tasks marked done, spec page updated with PR link | PR URL |

State is tracked in `.zone/manifest.json` at the repo root. Re-run `/zone` after each step to continue. If a step fails (review blocked, tests red), Zone sets the status back to `implement` and waits — it never skips forward on a broken state.

### Why not just prompt the AI directly?

A single prompt produces a single pass. Zone enforces a deliberate gate at each step: you review the spec before any code is written, you see the task breakdown before the TDD loop starts, and the review step can send execution back to implement if something is wrong. Each gate is a cheap place to catch a misunderstanding before it compounds.

## Prerequisites

- [Claude Code](https://claude.ai/code) or [OpenCode](https://opencode.ai)
- `gh` CLI (for PR creation in the ship step)
- Git
- A Jira MCP server (optional — only needed for the Jira path)
- A Notion MCP server (optional — only needed if you want Notion sync)

## Install

```bash
git clone git@github.com:panca1093/zone-skill.git
cd zone-skill
bash install.sh
```

The installer:
1. Detects which platforms are installed (Claude Code, OpenCode)
2. Prompts for Notion database/page IDs (press Enter to skip)
3. Writes Notion IDs to the platform's native config (`~/.claude/settings.json` env block for Claude Code; shell profile for OpenCode)
4. Copies skill files to the platform's commands directory

## Usage

```bash
/zone TICKET-123        # Jira path — fetches ticket, creates spec + tasks in Notion
/zone                   # Scratch path — interactive brief, personal Notion workspace
/zone TICKET-123 --no-notion  # skip Notion for this session
```

### Jira path

Pass a ticket ID. Zone fetches the ticket, asks clarifying questions, writes a spec, breaks it into TDD tasks, implements them one by one, self-reviews, runs tests, then opens a PR.

### Scratch path

No ticket needed. Zone opens a brainstorm conversation to sharpen the idea before moving into spec and implementation.

## Notion sync (optional)

When configured, Zone creates a spec page and task rows in Notion and keeps them in sync throughout the pipeline. Four env vars are required:

| Variable | Purpose |
|---|---|
| `ZONE_NOTION_WORK_DB_ID` | Tasks database for work projects |
| `ZONE_NOTION_PERSONAL_DB_ID` | Tasks database for personal projects |
| `ZONE_NOTION_WORK_PARENT_ID` | Parent page for work specs |
| `ZONE_NOTION_PERSONAL_PARENT_ID` | Parent page for personal specs |

Run `bash install.sh` to set these interactively, or set them manually in your platform's config.

## Supported platforms

| Platform | Commands dir | Notion config |
|---|---|---|
| Claude Code | `~/.claude/commands/` | `~/.claude/settings.json` env block |
| OpenCode | `~/.config/opencode/commands/` | shell profile (`~/.zshrc`) |

Adding a new platform: update `install.sh` with the platform's commands directory and env var injection mechanism.

## Language support

The implement and test steps auto-detect the project type:

| Language | Detection | Test command |
|---|---|---|
| Go | `go.mod` | `go test ./... -race` |
| Node/JS | `package.json` | `npm test` / `yarn test` |
| Python | `pyproject.toml` / `requirements.txt` | `pytest` |
| Rust | `Cargo.toml` | `cargo test` |
| Other | `Makefile` test target | `make test` |

## Project-level conventions

Architectural rules (layering, naming, etc.) belong in your project's `CLAUDE.md` or `AGENTS.md`. Zone reads these files during the implement step and applies them automatically.
