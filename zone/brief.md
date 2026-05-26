# /zone:brief — Brief Phase

Read `.zone/manifest.json` to get `mode` and `ticket_id`.

---

## Jira Path (`mode = "jira"`)

### 1. Load context

- Fetch the Jira ticket using the Jira MCP tool with `ticket_id`
- Run `git log --oneline -20` and `git branch -a` to understand repo state
- Run `find . -name "*.go" -o -name "*.ts" -o -name "*.py" | head -30` to get a feel for the codebase layout
- Check for a CLAUDE.md, AGENTS.md, or README at the repo root — read it for conventions

### 2. Ask targeted questions

Based on what you've read, ask about anything that would block writing a complete spec. Focus on:
- Acceptance criteria not explicitly stated in the ticket
- Which services or repos are affected beyond what's obvious
- Edge cases the ticket doesn't address
- Whether this is a breaking change and how to handle existing behavior
- Any dependency on inflight work in other tickets

Keep it to ≤5 questions. Stop and wait for user answers before proceeding.

### 3. Write brief

Write `.zone/brief.md`:

```markdown
# Brief: <ticket_id> — <one-line title>

## Ticket Summary
<your own words — what is being asked and why>

## Key Answers
<user's answers from Q&A>

## Constraints
<technical or business constraints identified>

## Edge Cases
<cases that need to be handled>

## Affected Files (best guess)
<list files/packages likely to change>
```

### 4. Update manifest

Set `manifest.status = "spec"`. Write updated `.zone/manifest.json`.

Tell user: "Brief done. Run `/zone` to continue to spec."

---

## Scratch Path (`mode = "scratch"`)

### 1. Brainstorm conversation

Ask open questions to sharpen the idea until it is precise enough to spec. Cover:
- What problem is this solving?
- Who uses it and how?
- What does success look like concretely?
- Any existing code this touches?
- Any technical constraints (language, platform, deadline)?

Iterate — stop and wait for answers, then ask follow-ups until the idea is crisp.

### 2. Set project name

Ask: "What should I call this project? (e.g. `my-api`, `dashboard-v2`)"

Update `manifest.project` with the answer.

### 3. Write brief

Write `.zone/brief.md`:

```markdown
# Brief: <project> — <one-line title>

## Problem
<what breaks or is missing without this>

## Idea
<the solution in plain language>

## Users
<who uses it>

## Success Criteria
<what done looks like>

## Constraints
<language, platform, deadline, existing code>
```

### 4. Update manifest

Set `manifest.status = "spec"`. Write updated `.zone/manifest.json`.

Tell user: "Brief done. Run `/zone` to continue to spec."
