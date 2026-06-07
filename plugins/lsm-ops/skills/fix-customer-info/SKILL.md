---
name: fix-customer-info
description: Fix customerNumber and customerName on LSM loans via the internal API. Handles single loans or CSV batches with rate limiting and token refresh.
argument-hint: "[loan_id customer_number customer_name | --csv <file>] [--rate <per_min>]"
allowed-tools: [Bash, Read]
---

# fix-customer-info — LSM Customer Info Patcher

Patches `customerNumber` and `customerName` on one or more loans via the LSM internal API (GET → patch → PUT with ETag).

## Constants

```
SSO_URL   = https://sso.amartha.id/realms/lsm-api/protocol/openid-connect/token
API_BASE  = https://api-gw-krakend.amartha.id/loan-state-machine/v2/internal/api
CLIENT_ID = go-loan-state-machine
CLIENT_SECRET = 35SRGXir55TF227GEePMRYKEybgvLOLs
UPDATED_BY = lsm-customer-change
TOKEN_TTL  = 270s  (refresh 30s before 5-min SSO expiry)
DEFAULT_RATE = 30/min
```

## Argument parsing

Parse `$ARGUMENTS`:
- `--csv <path>` → batch mode; read CSV (no header: `loan_id,customer_number,customer_name`)
- `--rate <n>` → override rate limit (calls/min, default 30)
- Three bare args `<loan_id> <customer_number> <customer_name>` → single-loan mode
- No args → ask the user which mode and collect inputs

## Steps

### 1. Confirm intent

**Single-loan mode:** show a one-line summary and ask for confirmation before proceeding.

**Batch mode (CSV):**
- Count rows in the CSV
- Show: total loans, rate, estimated duration (`total / rate` minutes)
- Ask for confirmation before starting

If the user says no, stop.

### 2. Fetch token

```bash
TOKEN=$(curl --silent --request POST \
  --url "$SSO_URL" \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data client_id=$CLIENT_ID \
  --data grant_type=client_credentials \
  --data "client_secret=$CLIENT_SECRET" | jq -r '.access_token')
```

Store fetch timestamp. Re-fetch whenever `now - fetched_at >= 270`.

### 3. Fix each loan

For each loan (single or from CSV):

**GET:**
```bash
curl --silent --request GET \
  --url "$API_BASE/loans/$LOAN_ID" \
  --header "authorization: Bearer $TOKEN" \
  --dump-header /tmp/lsm_fix_headers_$LOAN_ID.txt
```
- Check `.code == 200`; on failure log `FAIL GET <code>: <message>` and skip.
- Extract ETag: `grep -i '^etag:' /tmp/lsm_fix_headers_$LOAN_ID.txt | awk '{print $2}' | tr -d '\r'`

**Patch body:**
```bash
echo "$GET_RESP" | jq \
  --arg cn "$CUSTOMER_NUMBER" \
  --arg name "$CUSTOMER_NAME" \
  '.data.customerNumber = $cn | .data.customerName = $name | .data.updatedBy = "lsm-customer-change" | .data'
```

**PUT:**
```bash
curl --silent --request PUT \
  --url "$API_BASE/loans/$LOAN_ID" \
  --header "authorization: Bearer $TOKEN" \
  --header 'content-type: application/json' \
  --header "if-match: $ETAG" \
  --data "$PATCHED_BODY"
```
- `.code == 200` → log `OK`
- `.code == 422` and message contains `invest amount not equal to principal` → log `SKIP (investors:null — needs DB fix)`, do NOT retry
- Other failure → log `FAIL PUT <code>: <message>`

**Rate limiting:** sleep `60 / rate` seconds between loans (skip after the last one).

**Token refresh:** check before each GET, re-fetch if stale.

### 4. Summary

After all loans:
```
--- done ---
OK:    <n>
SKIP:  <n>  (investors:null)
FAIL:  <n>
TOTAL: <n>
```

List any FAIL loans with their error for follow-up.
