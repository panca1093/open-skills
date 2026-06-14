---
name: shoot-play
description: Zone-v2 phase 3 — mini-review sanity check (Center, light scope) then ship (SG). Reads .claude/zone-v2/manifest.json; requires status="ship". Ends with manifest.status="done". Triggers when the user runs /zone-v2:shoot-play or when the orchestrator advances past 3o3-play.
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Agent]
---

# /zone-v2:shoot-play — Mini-Review & Ship

Phase 3 of the zone-v2 pipeline. A light Center pass confirms nothing was missed before SG pushes, opens the PR, and closes the loop.

---

## 1. Load manifest

Read `.claude/zone-v2/manifest.json`.

- **No manifest** → stop: "No pipeline state found. Run /zone-v2:coach-brief first."
- **status ≠ `ship`** → stop:
  - status in {`brief`, `spec`}: "Run /zone-v2:coach-brief first."
  - status in {`implement`, `review`, `test`}: "Run /zone-v2:3o3-play first."
  - status = `done`: "Pipeline is already done."

Also verify `test_result.json` exists with `status="PASSED"`. If not:
```
test_result.json is missing or not PASSED — refusing to ship.
Run /zone-v2:3o3-play to fix tests first.
```

---

## 2. Mini-review — dispatch Center (light scope)

This is a fast pre-ship sanity check, not a full spec walkthrough. Read `players/center.md` and dispatch Center with a constrained brief:

- `subagent_type: "general-purpose"`, `model: "sonnet"`, `description: "zone-v2 shoot-play — mini-review"`
- Tell Center: **light scope only** — verify these three things:
  1. All `manifest.tasks` entries have `status="done"`.
  2. `test_result.json` is `PASSED` with no unresolved `is_impl_bug`.
  3. The top 3 functional requirements from `spec.md` are present in the diff (`git diff main...HEAD`).
  - If all three clear → `APPROVED`. Do NOT do a full spec walkthrough.
  - If any fail → `CHANGES_NEEDED` with only the specific finding.

Center writes `.claude/zone-v2/review_result.json` (overwrites; previous review was preserved as `review_prev.json` by 3o3-play).

After Center returns:
- `APPROVED` → continue to step 3.
- `CHANGES_NEEDED` → STOP:
  ```
  Mini-review flagged an issue before shipping:
  <Center's finding>
  Fix it and re-run /zone-v2:shoot-play, or run /zone-v2:3o3-play if it needs a full fix cycle.
  ```

---

## 3. Ship — dispatch SG (`sonnet`)

Read `players/sg.md` and dispatch SG:
- `subagent_type: "general-purpose"`, `model: "sonnet"`, `description: "zone-v2 shoot-play — SG ship"`
- Read before acting: `manifest.json`, `spec.md`, `brief.md`, `test_result.json`.
- The branch already exists (`manifest.branch`); SF committed each task to it. SG must not create a new branch.

SG pushes the branch, commits any leftover uncommitted files (no `git add -A`; skip if tree is clean), opens the PR with `gh pr create`, syncs Notion spec page if `notion.enabled`. Returns branch + PR URL.

After SG returns:
1. Set `manifest.branch`, `manifest.pr_url` from SG's summary.
2. Update the local wiki at `manifest.wiki_path` (Jira → `tickets/<ticket_id>.md`; Scratch → `personal/<project>.md`), plus `index.md` and `log.md`; sync to Notion if enabled.
3. Set `manifest.status = "done"`, write manifest.

---

## 4. Completion

```
Zone complete. You're in the zone.

PR:     <manifest.pr_url or commit hash>
Branch: <manifest.branch>
Spec:   <https://www.notion.so/<spec_page_id no-dashes> — omit if Notion disabled>
Wiki:   <manifest.wiki_path>/...
```
