---
name: test
description: Zone pipeline phase 6 — runs the full test suite with race + shuffle (Go) or equivalent. Detects project type; auto-corrects broken GOROOT for Go. Refuses to silently pass when no test suite exists (asks user). Invoked by /zone when manifest.status="test". Failure routes back to "implement"; green advances to "ship".
allowed-tools: [Read, Bash]
---

# /zone:test — Test Phase

Read `.zone/manifest.json`.

---

## GOROOT auto-correction (Go projects)

If the project is Go (`go.mod` present), apply this guard before invoking `go`:

```bash
if [ -z "$GOROOT" ] || [ ! -x "$GOROOT/bin/go" ]; then
  if [ -d /opt/homebrew/Cellar/go ]; then
    export GOROOT="$(ls -d /opt/homebrew/Cellar/go/*/libexec 2>/dev/null | sort -V | tail -n1)"
  fi
fi
```

---

## Detect Project Type and Run Tests

### Go project (has `go.mod`)

```bash
go test ./... -race -count=1
```

If that passes, also run with `-shuffle=on` to catch order-dependent failures:
```bash
go test ./... -race -shuffle=on -count=1
```

### Node/JS project (has `package.json`)

Run the `test` script: `npm test` or `yarn test`.

### Python project (has `pyproject.toml` or `requirements.txt`)

```bash
pytest
```

### Rust project (has `Cargo.toml`)

```bash
cargo test
```

### Other

Check for a `Makefile` target named `test`. If found, run `make test`.

---

## No Test Suite Found

**Do NOT silently pass.**

Tell user:
```
No test suite found in this project.

Options:
  1. Add tests now (recommended) — tell me what to cover and I'll write them
  2. Confirm this is intentional — type "skip tests" to proceed to ship anyway

Waiting for your decision.
```

Stop and wait. Do not advance to ship without explicit confirmation.

---

## Tests Fail

Show the full failure output (don't truncate).

Set `manifest.status = "implement"`. Write manifest.

Tell user:
```
Tests: FAILING

<failure output>

Fix the failures, then run `/zone` to re-test.
```

---

## Tests Pass

Set `manifest.status = "ship"`. Write manifest.

Tell user:
```
Tests: GREEN ✓

Run `/zone` to ship.
```
