---
name: shoot-play
description: Zone-v2 phase 3 — mini-review sanity check (Center, light scope) then ship (SG). Reads .claude/zone-v2/manifest.json; requires status="ship". Ends with manifest.status="done". Run after /zone-v2:3o3-play.
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Agent]
---

## 0. Load models from config

```bash
CONFIG_PATH="$HOME/.claude/plugins/data/zone-v2/config.json"
M_CENTER=$(jq -r '.models.center // empty' "$CONFIG_PATH" 2>/dev/null)
M_SG=$(jq -r '.models.sg // empty' "$CONFIG_PATH" 2>/dev/null)
```
Models are optional. An empty `M_*` means "no override" — **omit the `model` field** when dispatching that player, so it inherits the session model.

## 1. Load manifest

Read `.claude/zone-v2/manifest.json`.
- No manifest → stop: "Run /zone-v2:coach-brief first."
- `status` in {`brief`,`spec`} → stop: "Run /zone-v2:coach-brief first."
- `status` in {`implement`,`review`,`test`} → stop: "Run /zone-v2:3o3-play first."
- `status="done"` → stop: "Pipeline done."

Verify `test_result.json` exists with `status="PASSED"`. If not → stop: "test_result not PASSED — run /zone-v2:3o3-play to fix tests first."

## 2. Mini-review — Center (light scope)

Read `players/center.md`. Dispatch Center with constrained scope:
- `subagent_type: "general-purpose"`, `description: "zone-v2 shoot-play — mini-review"`; pass `model: M_CENTER` only if non-empty.
- Tell Center: **light scope only** — verify three things:
  1. All `manifest.tasks` have `status="done"`.
  2. `test_result.json` is `PASSED` with no unresolved `is_impl_bug`.
  3. Top 3 functional requirements from `spec.md` are present in diff (`git diff main...HEAD`).
  - All clear → `APPROVED`. Do NOT do a full spec walkthrough.
  - Any fail → `CHANGES_NEEDED` with only the specific finding.

Center writes `review_result.json`.

- `APPROVED` → continue.
- `CHANGES_NEEDED` → stop: "Mini-review flagged: <finding>. Fix then re-run /zone-v2:shoot-play, or run /zone-v2:3o3-play for a full fix cycle."

## 3. Ship — SG (`M_SG`)

Read `players/sg.md`. Dispatch:
- `subagent_type: "general-purpose"`, `description: "zone-v2 shoot-play — SG"`; pass `model: M_SG` only if non-empty.
- Read before acting: `manifest.json`, `spec.md`, `brief.md`, `test_result.json`.
- Branch exists (`manifest.branch`); SF committed each task. SG must not create a new branch.

SG: commit leftovers (no `git add -A`; skip if clean), `git push -u origin <branch>`, `gh pr create`, sync Notion spec page if enabled. Returns branch + PR URL.

After SG: set `manifest.branch`, `manifest.pr_url`. Update wiki (`tickets/<id>.md` or `personal/<project>.md` + `index.md` + `log.md`); sync Notion if enabled. Set `status="done"`, write manifest.

```
Zone complete. You're in the zone.

PR:     <pr_url or commit hash>
Branch: <branch>
Spec:   <notion url — omit if disabled>
Wiki:   <wiki_path>/...
```
