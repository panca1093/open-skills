# /zone:spec — Spec Phase

Read `.zone/manifest.json` and `.zone/brief.md`.

---

## Write Spec Locally

Write `.zone/spec.md` using this template — keep it under 2 pages, dense over exhaustive:

```markdown
# Spec: <ticket_id or project> — <title>

## Problem
One paragraph. What breaks or is missing without this change?

## Solution
What we're building, in plain language.

## Scope

### In scope
- ...

### Out of scope
- ...

## API / Interface Changes
List new endpoints, function signatures, or proto changes. "None" if none.

## Data Changes
DB migrations, new fields, removed fields. "None" if none.

## Affected Services
| Repo | Change |
|------|--------|
| ... | ... |

## Acceptance Criteria
- [ ] ...
- [ ] ...

## Open Questions
(none — or list anything still unresolved)
```

---

## Push to Notion (skip if `manifest.notion.enabled = false`)

If `manifest.notion.enabled` is true:

Create a Notion page with the spec content under `manifest.notion.spec_parent`.

Page title: `Spec: <ticket_id or project> — <title>`

Use `notion-create-pages` to create it under `manifest.notion.spec_parent`.

After creating, record the returned Notion page ID in `manifest.notion.spec_page_id`.

---

## Update Manifest

Set `manifest.status = "plan"`. Write updated `.zone/manifest.json`.

Tell user: "Spec done. Run `/zone` to continue to plan." (omit "pushed to Notion" if Notion disabled)
