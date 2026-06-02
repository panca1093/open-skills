---
name: review
description: Zone pipeline phase 5 — self-reviews the diff against spec ACs, layering rules, security, and concurrency. Blocking findings send the pipeline back to "implement"; clean review advances to "test". Optionally prompts the user to delegate the review to a more capable model (Opus) for higher-stakes diffs. Invoked by /zone when manifest.status="review".
allowed-tools: [Read, Bash, Glob, Grep, Edit, AskUserQuestion]
---

# /zone:review — Code Review Phase

Read `.zone/manifest.json` and `.zone/spec.md`.

---

## 0. Optional model override

Before running the review, ask the user whether to use a stronger model. Use AskUserQuestion with one question:

**Question:** "Run review with the current model, or escalate to Opus for higher-quality findings?"
- "Current model" — proceed inline (default)
- "Opus" — note this in the output for the user to re-run the review with `--model opus` themselves, OR (next iteration) dispatch a sub-agent with Opus model override (see "Future" section).

If the user picks "Opus", for now just tell them: "Re-run `/zone:review` with the Opus model override (e.g. by switching the session model or invoking via a sub-agent). Pausing the pipeline."

Set `manifest.status` to stay at `"review"` and stop. The user will re-invoke after switching model.

If the user picks "Current model", continue.

---

## 1. Get the Diff

```bash
git diff main...HEAD 2>/dev/null || git diff master...HEAD
```

If no diff (nothing committed yet), run `git diff HEAD` instead.

---

## 2. Review Against These Criteria

### Blockers — must fix before ship

- [ ] Business logic placed in the wrong architectural layer (consult CLAUDE.md or AGENTS.md for project conventions)
- [ ] Acceptance criteria from spec not covered by tests
- [ ] Missing test for any scenario listed in `task.test_cases`
- [ ] Security issue: SQL injection, unvalidated external input, exposed secret
- [ ] Data race or concurrency bug
- [ ] Breaking change to existing API not documented in the spec
- [ ] Panic / null dereference without guard

### Warnings — note but do not block

- Missing edge case coverage (document, not block)
- Overly complex abstraction for the problem size
- Missing error handling at a system boundary (external API, DB call)
- Inconsistent naming or style with surrounding code

---

## 3. Decision

### Blockers found

List each blocker precisely (file, line number, what's wrong, how to fix).

Set `manifest.status = "implement"`. Write manifest.

Tell user:
```
Review: BLOCKED (<N> issue(s))
<list of blockers>

Fix these, then run `/zone` to re-review.
```

### No blockers

Set `manifest.status = "test"`. Write manifest.

Tell user:
```
Review: PASSED
<optional: list any warnings for awareness>

Run `/zone` to run tests.
```

---

## Future: sub-agent dispatch for Opus reviews

When Saifullah ships the sub-agent integration, the "Opus" option above should dispatch an Agent (with model=opus) running this same instruction file. The sub-agent reports its findings; this skill then writes them into the manifest decision flow. Placeholder noted for next iteration.
