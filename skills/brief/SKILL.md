---
name: brief
description: Zone pipeline phase 1 — clarifying Q&A that turns a Jira ticket or a vague idea into a complete .zone/brief.md. Invoked by /zone when manifest.status="brief"; rarely invoked directly by users. Reads CLAUDE.md/AGENTS.md/wiki for context, asks ≤5 targeted questions, writes the brief, advances manifest to "spec".
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion]
---

# /zone:brief — Brief Phase

Read `.zone/manifest.json` to get `mode`, `ticket_id`, and `interactive`.

---

## Jira Path (`mode = "jira"`)

### 1. Load context

Try to fetch the Jira ticket. The Jira MCP tool may or may not be loaded in this session.

```bash
# Check if Jira MCP is available
# If a tool named mcp__atlassian-jira__getJiraIssue is callable, use it.
# Otherwise, ask the user to paste the ticket body inline.
```

**Conditional behavior:**
- If `mcp__atlassian-jira__getJiraIssue` is available, call it with `ticket_id` to fetch the ticket details.
- If not, ask the user via AskUserQuestion: "Jira MCP isn't loaded. Paste the ticket title and description here so I can write the brief from it."

Then load supporting context:

- Read user memory index: `~/.claude/projects/-Users-Panca-Documents-MyBook/memory/MEMORY.md` (if it exists; skip silently if not)
- Read project wiki index if present (e.g. `<wiki_path>/index.md` from manifest)
- `git log --oneline -20` and `git branch -a` to understand repo state
- `find . -name "*.go" -o -name "*.ts" -o -name "*.py" 2>/dev/null | head -30` for codebase layout
- Read `CLAUDE.md`, `AGENTS.md`, or `README.md` at the repo root if present, for conventions

### 2. Ask targeted questions

Based on what you've read, ask about anything that would block writing a complete spec. Use **AskUserQuestion** for these (multi-select where appropriate, free-text via "Other"). Focus on:
- Acceptance criteria not explicitly stated in the ticket
- Which services or repos are affected beyond what's obvious
- Edge cases the ticket doesn't address
- Whether this is a breaking change and how to handle existing behavior
- Any dependency on inflight work in other tickets

Keep it to ≤5 questions. Wait for user answers before proceeding.

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

If `manifest.interactive = true`:
  Tell user: "Brief done. Run `/zone` to continue to spec."
Else:
  Tell user: "Brief done. Continuing to spec."

---

## Scratch Path (`mode = "scratch"`)

### 1. Brainstorm conversation

Use AskUserQuestion to sharpen the idea until it's precise enough to spec. Cover:
- What problem is this solving?
- Who uses it and how?
- What does success look like concretely?
- Any existing code this touches?
- Any technical constraints (language, platform, deadline)?

Iterate — ask follow-ups across multiple AskUserQuestion calls if the answers aren't crisp.

### 2. Set project name

Ask: "What should I call this project? (e.g. `tka-prep-app`, `restaurant-app`)"

Update `manifest.project` with the answer.

### 3. Create project directory (new projects only)

If `manifest.project_dir` is null (new session):

Get the current working directory path (where zone was invoked from). Create the project directory as a subdirectory:

```bash
mkdir -p "<cwd>/<project-name>"
```

Initialize git if the directory is not already a git repository:
```bash
git -C "<cwd>/<project-name>" init
```

Update manifest:
- `manifest.project_dir` = absolute path to `<cwd>/<project-name>`

Write updated manifest.

Tell user: "Created `<project-name>/` — all implementation will go here."

### 4. Write brief

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

### 5. Update manifest

Set `manifest.status = "spec"`. Write updated `.zone/manifest.json`.

If `manifest.interactive = true`:
  Tell user: "Brief done. Run `/zone` to continue to spec."
Else:
  Tell user: "Brief done. Continuing to spec."
