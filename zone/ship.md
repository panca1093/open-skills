# /zone:ship — Ship Phase

Read `.zone/manifest.json` and `.zone/spec.md`.

---

## 1. Create Branch (if not already on a feature branch)

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

Then use `gh pr create` with a HEREDOC:

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

Update the spec Notion page (`manifest.notion.spec_page_id`) — append PR URL to the page body.

---

## 5. Finalize Manifest

Set `manifest.pr_url` to the PR URL (or commit hash if no remote).
Set `manifest.status = "done"`.
Write updated `.zone/manifest.json`.

---

## 6. Done

Tell user:

```
Zone complete. You're in the zone.

PR:     <pr_url or commit hash>
Branch: <branch>
Spec:   <https://www.notion.so/<spec_page_id> — omit if Notion disabled>
```
