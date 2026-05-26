# /zone:review — Code Review Phase

Read `.zone/manifest.json` and `.zone/spec.md`.

---

## Get the Diff

```bash
git diff main...HEAD 2>/dev/null || git diff master...HEAD
```

If no diff (nothing committed yet), run `git diff HEAD` instead.

---

## Review Against These Criteria

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

## Decision

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
