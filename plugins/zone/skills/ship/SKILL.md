---
name: ship
description: Zone pipeline phase 7 — final phase. Creates a feature branch, commits, pushes, opens a PR via gh, marks Notion tasks Done, updates the spec page with the PR URL, and writes/updates a wiki page at the configured wiki_path. Invoked by /zone when manifest.status="ship". Advances to "done".
allowed-tools: [Read, Write, Edit, Bash]
---

# /zone:ship — Ship Phase

Read `.zone/manifest.json` and `.zone/spec.md`.

---

## 1. Create Branch (if not already on a feature branch)

Determine the working directory: use `manifest.project_dir` if set, otherwise cwd.

If `manifest.branch` is null or the current branch is `main`/`master`:

- Jira path: `git checkout -b feat/<ticket_id>-<kebab-slug-of-title>`
- Scratch path: `git checkout -b feat/<project>-<kebab-slug-of-title>`

Update `manifest.branch` with the branch name. Write manifest.

---

## 2. Commit

Stage relevant changed files (be specific — no `git add -A`).

Commit with message:
- Jira path: `feat: <TICKET-ID> | <brief description>`
- Scratch path: `feat: <brief description>`

---

## 3. Create PR

If a git remote exists, push and create PR:

```bash
git push -u origin <branch>
```

Then use `gh pr create` with a HEREDOC.

**Title:**
- Jira path: `feat: <TICKET-ID> | <brief description>`
- Scratch path: `feat: <brief description>`

**Body:**
```
## Summary
- <bullet 1 from spec solution>
- <bullet 2>

## Spec
<if manifest.notion.enabled and manifest.notion.spec_page_id is set:
  https://www.notion.so/<spec_page_id no-dashes>
  otherwise omit this section>

## Test plan
- [ ] All tests green
- [ ] <acceptance criterion 1 from spec>
- [ ] <acceptance criterion 2 from spec>

🤖 Generated with [Claude Code](https://claude.ai/code) via /zone
```

If no git remote exists, skip PR creation and print the commit hash and summary instead.

---

## 4. Update Notion (skip if `manifest.notion.enabled = false`)

If `manifest.notion.enabled` is true:

For each task in `manifest.tasks`:
- Update Notion row Status = "Done" (if not already done)

Update the spec Notion page (`manifest.notion.spec_page_id`) — append PR URL to the page body using `mcp__claude_ai_Notion__notion-update-page` with `command: "insert_content"`, `position: {type: "end"}`.

---

## 5. Update Local Wiki

Read `wiki_base` from `manifest.wiki_path`. If missing, fall back to `~/Documents/MyBook/wiki`.

Today's date is in `Asia/Jakarta` timezone.

### Jira path

Check if `<wiki_base>/tickets/<ticket_id>.md` exists.

**If it exists:** Update the page — add the Implementation section with branch, PR URL, and a brief note on what changed.

**If it does not exist:** Create `<wiki_base>/tickets/<ticket_id>.md`:

```markdown
---
title: <ticket_id> — <title from spec>
category: ticket
tags: [implementation]
sources: []
updated: <today's date YYYY-MM-DD>
---

## Summary
<problem paragraph from spec>

## Solution
<solution paragraph from spec>

## Acceptance Criteria
<from spec>

## Implementation
- Branch: `<manifest.branch>`
- PR: <manifest.pr_url or commit hash>

## Spec
<if Notion enabled: [Notion Spec](https://www.notion.so/<spec_page_id no-dashes>)>
```

Update `<wiki_base>/index.md` — add the ticket entry under the Tickets section:
```
- [[<ticket_id>]] — <one-line summary>  (sources: 0)
```

Append to `<wiki_base>/log.md`:
```
## [<today YYYY-MM-DD>] ingest | <ticket_id> — <title>
Shipped <ticket_id> via /zone. PR: <pr_url>. Created wiki page from spec.
```

**Sync to Notion** (if `manifest.notion.enabled = true`):
- Create a page under Tickets & RFCs (configured via `config.notion.work_parent_id`) using `mcp__claude_ai_Notion__notion-create-pages`
- Title: `<ticket_id> — <title>`
- Body: same content as the local wiki page

### Scratch path

Check if `<wiki_base>/personal/<project>.md` exists.

**If it does not exist (new project):** Create `<wiki_base>/personal/<project>.md`:

```markdown
---
title: <project>
category: personal
tags: [project]
sources: []
updated: <today's date YYYY-MM-DD>
---

## About
<problem and idea from brief>

## Users
<who uses it>

## Tech Stack
<language and frameworks used in implementation>

## Status
Active

## Links
- Repo: `<manifest.project_dir>`
- PR/Commit: <manifest.pr_url or commit hash>
<if Notion enabled: - Spec: [Notion Spec](https://www.notion.so/<spec_page_id no-dashes>)>
```

Update `<wiki_base>/personal/index.md` — add the project entry.

Update `<wiki_base>/index.md` — add under Personal section:
```
- [[<project>]] — <one-line description>  (sources: 0)
```

Append to `<wiki_base>/log.md`:
```
## [<today YYYY-MM-DD>] ingest | <project> — new project
Created new project via /zone scratch path. PR: <pr_url>. Wiki page created.
```

**If it exists (project already has a page):** Update the Status, Links, and Tech Stack sections to reflect the new PR/commit.

**Sync to Notion** (if `manifest.notion.enabled = true`):
- Create or update a page under the Personal parent (configured via `config.notion.personal_parent_id`) using `mcp__claude_ai_Notion__notion-create-pages` or `mcp__claude_ai_Notion__notion-update-page`

---

## 6. Finalize Manifest

Set `manifest.pr_url` to the PR URL (or commit hash if no remote).
Set `manifest.status = "done"`.
Write updated `.zone/manifest.json`.

---

## 7. Done

Tell user:

```
Zone complete. You're in the zone.

PR:     <pr_url or commit hash>
Branch: <branch>
Spec:   <https://www.notion.so/<spec_page_id> — omit if Notion disabled>
Wiki:   <wiki_base>/tickets/<ticket_id>.md  (or personal/<project>.md)
```
