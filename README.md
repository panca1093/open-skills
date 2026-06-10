# zone

A spec-driven development pipeline as a Claude Code plugin. One command, seven phases, autonomous by default — takes an idea from brief to shipped PR with no manual handoffs.

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

| Phase | What happens | Artifact |
|---|---|---|
| **brief** | Clarifying Q&A — surfaces edge cases, constraints, affected files | `.zone/brief.md` |
| **spec** | Formal write-up: problem, solution, scope, API changes, acceptance criteria | `.zone/spec.md` (+ Notion page if configured) |
| **plan** | Breaks spec into ordered TDD tasks, each with concrete test scenarios | manifest `tasks[]` (+ Notion task rows) |
| **implement** | TDD loop per task: write failing tests → implement → refactor → repeat | source + test files |
| **review** | Self-review against spec ACs, layering rules, security, concurrency | pass / block list |
| **test** | Full test suite run with `-race` and `-shuffle` (Go) or equivalent | green / failing |
| **ship** | Branch + commit + PR, Notion tasks marked done, spec page updated with PR link, wiki page written | PR URL + wiki page |

State is tracked in `.zone/manifest.json` at the repo root. In autonomous mode (default), `/zone` loops through phases until a stop condition (review blockers, failing tests, done). If a phase fails, Zone sets the status back to `implement` and waits — it never skips forward on a broken state.

### Why not just prompt the AI directly?

A single prompt produces a single pass. Zone enforces a deliberate gate at each phase: you can review the spec before any code is written, see the task breakdown before the TDD loop starts, and the review phase can send execution back to implement if something is wrong. Each gate is a cheap place to catch a misunderstanding before it compounds.

## Install

Zone is a Claude Code plugin, distributed via the `open-skills` marketplace hosted in this repo.

### From this repo (GitHub)

```
/plugin marketplace add panca1093/open-skills
/plugin install zone@open-skills
```

(The marketplace name is `open-skills`; the plugin name is `zone`.)

### From a local clone (dev install)

```bash
git clone git@github.com:panca1093/open-skills.git
```

Then in Claude Code, add the local checkout as a marketplace and install:
```
/plugin marketplace add /absolute/path/to/open-skills
/plugin install zone@open-skills
```

After install:
```
/zone:setup
```

This walks through Notion DB/page IDs and the wiki path, and writes `~/.claude/plugins/data/zone/config.json`. Skip Notion fields to disable Notion sync.

## Usage

```
/zone TICKET-123                   # Jira path, autonomous
/zone                              # Scratch path, autonomous
/zone TICKET-123 --interactive     # pause after each phase
/zone TICKET-123 --no-notion       # skip Notion sync for this session
```

### Jira path (`/zone LOAN-1234`)

Triggered when the argument matches `[A-Z]+-\d+`. Zone fetches the ticket via the Jira MCP if loaded (otherwise asks you to paste the body inline), asks ≤5 clarifying questions, writes a spec, breaks it into TDD tasks, implements them one by one, self-reviews, runs the test suite, then opens a PR. Spec + tasks land in the configured Notion "Tasks — Work" database; wiki page lands at `wiki_path/tickets/<TICKET-ID>.md`.

### Scratch path (`/zone`)

No ticket needed. Zone runs a brainstorm conversation to sharpen the idea before moving into spec and implementation. Spec + tasks land in the configured Notion "Tasks — Personal" database; wiki page lands at `wiki_path/personal/<project>.md`. If no project directory exists yet, Zone creates one in the current working directory.

## Sub-skills

Each phase is a standalone skill you can invoke independently to re-enter the pipeline at any point:

- `/zone:brief` — brief phase
- `/zone:spec` — spec phase
- `/zone:plan` — plan phase
- `/zone:implement` — one TDD task per invocation
- `/zone:review` — self-review (with optional Opus override prompt)
- `/zone:test` — run the test suite
- `/zone:ship` — branch + PR + Notion + wiki update
- `/zone:setup` — configure or update Notion IDs and wiki path

State is shared via `.zone/manifest.json`. The Skill tool can be used by sub-agents too — Zone is invokable from any agent that has Skill access, not just the user via slash command.

## Configuration

Zone reads `~/.claude/plugins/data/zone/config.json`. Run `/zone:setup` to create or update it. Schema:

```json
{
  "version": "1.0",
  "notion": {
    "work_db_id": "<Tasks — Work DB ID>",
    "personal_db_id": "<Tasks — Personal DB ID>",
    "work_parent_id": "<Spec parent page for Jira mode>",
    "personal_parent_id": "<Spec parent page for Scratch mode>"
  },
  "wiki_path": "~/Documents/MyBook/wiki"
}
```

Any Notion field can be empty — Zone disables Notion sync gracefully when IDs are missing.

## Prerequisites

- [Claude Code](https://claude.ai/code)
- `gh` CLI (for PR creation in the ship phase)
- Git
- A Jira MCP server (optional — only needed for the Jira path; Zone falls back to inline ticket paste if the MCP isn't loaded)
- A Notion MCP server (optional — only needed if you want Notion sync)

## Language support

The implement and test phases auto-detect the project type:

| Language | Detection | Test command |
|---|---|---|
| Go | `go.mod` | `go test ./... -race -count=1` (+ `-shuffle=on` second pass) |
| Node/JS | `package.json` | `npm test` / `yarn test` |
| Python | `pyproject.toml` / `requirements.txt` | `pytest` |
| Rust | `Cargo.toml` | `cargo test` |
| Other | `Makefile` test target | `make test` |

For Go projects on machines with a broken `GOROOT` env var, Zone auto-detects the Homebrew Go install at `/opt/homebrew/Cellar/go/*/libexec` and overrides `GOROOT` inline. No-op on machines where `GOROOT` is fine.

## Project-level conventions

Architectural rules (layering, naming, etc.) belong in your project's `CLAUDE.md` or `AGENTS.md`. Zone reads these during the brief and implement phases and applies them automatically.

## Stronger review (Opus override)

The review phase optionally prompts you to escalate to Opus for higher-stakes diffs. In the current version this pauses the pipeline so you can re-invoke with the model switched; the upcoming sub-agent integration will dispatch a model-overridden agent automatically.

## Layout

The marketplace manifest sits at the root; each plugin lives under `plugins/<name>/`. This README documents the stable `zone` (v1) plugin; `zone-v2` is the merged single-file successor — same seven phases collapsed into one skill, Notion opt-in (`--notion`), state in `.zone-v2/`, runnable side by side with v1.

```
open-skills/                             # repo root = the "open-skills" marketplace
├── .claude-plugin/
│   └── marketplace.json                 # marketplace manifest (name: "open-skills")
├── plugins/
│   ├── zone/                            # the zone plugin (v1, stable)
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json              # plugin manifest (name: "zone")
│   │   └── skills/
│   │       ├── zone/SKILL.md            # /zone (orchestrator)
│   │       ├── setup/SKILL.md           # /zone:setup
│   │       ├── brief/SKILL.md
│   │       ├── spec/SKILL.md
│   │       ├── plan/SKILL.md
│   │       ├── implement/SKILL.md
│   │       ├── review/SKILL.md
│   │       ├── test/SKILL.md
│   │       └── ship/SKILL.md
│   └── zone-v2/                         # merged single-file successor
│       ├── .claude-plugin/
│       │   └── plugin.json              # plugin manifest (name: "zone-v2")
│       └── skills/
│           ├── zone-v2/SKILL.md         # /zone-v2 (orchestrator + 7 inline phases)
│           └── setup/SKILL.md           # /zone-v2:setup
└── README.md
```

Future plugins added to this marketplace go under `plugins/<plugin-name>/` and get listed in `.claude-plugin/marketplace.json`.

## License

MIT.
