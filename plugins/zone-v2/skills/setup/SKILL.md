---
name: setup
description: Configuration for the Zone-v2 plugin — prompts for Notion DB/page IDs and the local MyBook wiki path (written to ~/.claude/plugins/data/zone-v2/config.json), and installs a per-project dev-command allowlist + GOROOT env into the current project's .claude/settings.local.json to cut permission prompts during runs. Triggers when the user asks to "configure zone-v2", "set up zone-v2", "zone-v2 setup", or runs /zone-v2:setup. Notion/wiki config is optional; run setup from a project root to install its allowlist. Safe to re-run to update settings.
argument-hint: "[--show] [--reset]"
allowed-tools: [Read, Write, Bash, AskUserQuestion]
---

# /zone-v2:setup — Plugin Configuration

Zone-v2 reads optional configuration from `~/.claude/plugins/data/zone-v2/config.json`. This skill creates or updates that file interactively.

Config is **optional** in zone-v2: `/zone-v2` runs without it (Notion off, wiki defaults to `~/Documents/MyBook/wiki`, all players on the current session model). Run this only when you want `--notion` sync, a custom wiki path, or per-player model overrides. Re-run any time to change settings.

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

Then ask whether to configure per-player models (AskUserQuestion):

**Per-player models?**
"Configure a model per player? Models are **optional** — if you skip, every player runs on whatever model your Claude Code session is set to (`/model`). Configure only to tune cost/quality per phase (e.g. a cheaper SF for the implement loop)."
- **(Recommended) Skip — use session model** — leave `models` empty; one model for everyone.
- **Configure per player** — set a model id for each.

If **Skip**: omit the `models` block (or write `"models": {}`).

If **Configure**: ask free-text for each player. Use the model id your LLM provider requires (e.g. `claude-sonnet-4-5`, `gpt-4o`, `gemini-1.5-pro`). Leave any one empty to let that player inherit the session model.
1. **pg** — spec + plan (runs once; capable reasoning model)
2. **sf** — implement loop (runs most; consider a faster/cheaper model)
3. **sf_escalate** — implement on retry (sf retries≥2 or architectural fix; stronger than sf). Empty → falls back to `sf`.
4. **center** — review
5. **pf** — test
6. **sg** — ship

Prefill from existing config if present. Store whatever the user types — no validation.

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
  "wiki_path": "<wiki path answer or default>",
  "models": {}
}
```

If the user configured per-player models, fill `models` with only the non-empty entries (e.g. `{ "sf": "...", "sf_escalate": "..." }`); otherwise leave it `{}`. Notion/wiki empty values are stored as empty strings — keeps schema consistent.

## 7. Install per-project dev allowlist (cut permission prompts)

Zone-v2 dispatches many subagents that each cold-start and re-hit permission prompts on routine dev commands (`go build/test`, `git add/commit`, `mkdir`, `npm`/`next`) plus the orchestrator's constant `manifest.json` edits. This step writes a **curated allowlist** of safe commands + zone-v2 state files into the **current project's** `.claude/settings.local.json`, scoped to that project only (never global, never your work repos unless you run setup there).

**Target = current working directory.** Run `/zone-v2:setup` from the project root you will zone in. Merge is idempotent (dedupes into existing `permissions.allow`); re-running is safe.

Only **safe, local** commands are allowed. Outward/destructive ones stay gated and still prompt: `git push` / force-push, `gh pr create`, `git reset --hard`, `git remote set-url`, `rm`, `sudo`, web `curl`/`wget`, `brew`, `go install`, `npm publish`.

Run this merge (also sets `env.GOROOT` to the newest Homebrew Go so `go` commands run plainly and stay matchable):

```bash
PROJECT_DIR="$(pwd)"
SETTINGS_DIR="$PROJECT_DIR/.claude"
SETTINGS_PATH="$SETTINGS_DIR/settings.local.json"
mkdir -p "$SETTINGS_DIR"
GOROOT_DETECTED="$(ls -d /opt/homebrew/Cellar/go/*/libexec 2>/dev/null | sort -V | tail -n1)"
PROJECT_DIR="$PROJECT_DIR" GOROOT_DETECTED="$GOROOT_DETECTED" SETTINGS_PATH="$SETTINGS_PATH" python3 - <<'PY'
import json, os
path = os.environ["SETTINGS_PATH"]
proj = os.environ["PROJECT_DIR"]
goroot = os.environ.get("GOROOT_DETECTED", "").strip()
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except json.JSONDecodeError:
    raise SystemExit(f"Refusing to overwrite malformed {path} — fix the JSON first.")

allow = data.setdefault("permissions", {}).setdefault("allow", [])
rules = [
    "Bash(go build *)", "Bash(go test *)", "Bash(go vet *)", "Bash(go mod *)",
    "Bash(go run *)", "Bash(go fmt *)", "Bash(gofmt *)", "Bash(go env*)",
    "Bash(go version*)", "Bash(golangci-lint run*)",
    "Bash(git status*)", "Bash(git diff*)", "Bash(git add *)", "Bash(git commit *)",
    "Bash(git log*)", "Bash(git show*)", "Bash(git branch*)", "Bash(git checkout *)",
    "Bash(git switch *)", "Bash(git restore *)", "Bash(git stash*)",
    "Bash(git rev-parse*)", "Bash(git init*)", "Bash(git worktree *)",
    "Bash(mkdir -p *)", "Bash(ls *)",
    "Bash(npm run *)", "Bash(npm test*)", "Bash(npm ci*)", "Bash(npm install*)",
    "Bash(pnpm *)", "Bash(npx next *)", "Bash(npx tsc*)",
    f"Write(/{proj}/.claude/zone-v2/**)", f"Edit(/{proj}/.claude/zone-v2/**)",
]
added = [r for r in rules if r not in allow]
allow.extend(added)
if goroot:
    data.setdefault("env", {})["GOROOT"] = goroot
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"Wrote {path}")
print(f"  +{len(added)} new allow rules ({len(allow)} total)")
print(f"  env.GOROOT: {goroot or '(none — no /opt/homebrew/Cellar/go found, skipped)'}")
PY
```

## 8. Confirm

Tell the user:

```
Zone-v2 config written to ~/.claude/plugins/data/zone-v2/config.json

Notion sync:  opt-in — pass --notion to /zone-v2 to use it (requires IDs above)
Wiki path:    <wiki_path>
Allowlist:    <N> rules + GOROOT env → <project>/.claude/settings.local.json
              (safe dev commands auto-allowed; push/PR/rm/sudo still prompt)
Models:       <"session model (no overrides)" if models empty, else the configured map>

Run `/zone-v2:orchestrator TICKET-XXX` (Jira) or `/zone-v2:orchestrator` (Scratch) to start.
```
