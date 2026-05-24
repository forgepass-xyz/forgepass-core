# ForgePass Onboarding Gate Specifications v1.0

> This document is the authoritative technical reference for the four
> onboarding gates implemented in Issue #026. It defines the exact API
> endpoint, field, query method, and evaluation logic for each gate.
> Every gate check in the implementation must trace back to a
> specification in this document.

---

## Gate Execution Order

Gates are evaluated in strict sequence. A gate failure halts evaluation
immediately. No subsequent gates are checked after a failure.

```
Gate 1: Stellar Account Age
  PASS -> Gate 2: XLM Balance
    PASS -> Gate 3: GitHub Activity
      PASS -> Gate 4: Duplicate Identity
        PASS -> Proceed to passport creation
```

This order is intentional. Gates 1 and 2 use the same Horizon API call
and can be evaluated together in a single request. Gate 3 requires a
separate GitHub API call. Gate 4 is a local database check and is the
cheapest operation, but it runs last because it is only meaningful once
the contributor has passed the identity and activity checks.

---

## Gate 1: Stellar Account Age

**Purpose:** Verify the contributor's Stellar wallet has existed for at
least 60 days before onboarding.

**API endpoint:**
```
GET https://horizon.stellar.org/accounts/{wallet_address}
```

**Field evaluated:**
```
response.account.created_at
```
ISO 8601 timestamp of account creation. Parse to UTC datetime.

**Evaluation logic:**
```
elapsed_days = (current_utc_date - created_at_date).days
passes = elapsed_days >= 60
```

**On pass:** Proceed to Gate 2.

**On fail:** Return gate failure with:
```json
{
  "gate": "stellar_account_age",
  "passed": false,
  "current_value": "{elapsed_days} days",
  "minimum_required": "60 days",
  "days_remaining": "{60 - elapsed_days}",
  "message": "Your Stellar wallet was created {elapsed_days} days ago. A minimum of 60 days is required to create a Builder Passport. You will be eligible in {days_remaining} days."
}
```

**Re-verification:** Not applicable. Account age can only increase.

**Implementation notes:**
- Cache the Horizon response for Gate 2: both gates use the same
  account object. Do not make two Horizon calls for the same wallet.
- Handle Horizon 404 (account not found) as a Gate 1 failure with a
  distinct message: "This Stellar wallet address could not be found
  on the network. Please check the address and try again."

---

## Gate 2: Minimum XLM Balance (30-Day Rolling Average)

**Purpose:** Verify the contributor's Stellar wallet has maintained an
average native XLM balance of at least 10 XLM over the preceding 30
days.

**API endpoint:**
```
GET https://horizon.stellar.org/accounts/{wallet_address}/effects
  ?order=desc
  &limit=200
```

Fetch the account's effect history. Filter for effects of type
`account_credited` and `account_debited` on the native (XLM) asset.
Reconstruct the balance at each point in time by walking backwards
from the current balance through each credit and debit operation.

**Current balance field (from Gate 1 cached response):**
```
response.account.balances[].balance where asset_type == "native"
```

**Evaluation logic:**
```
current_balance = native balance from Gate 1 response
window_start = current_utc_date - 30 days

Reconstruct daily balance snapshots over the 30-day window by
replaying credit and debit effects in reverse chronological order.

daily_balances = [balance_on_day_1, balance_on_day_2, ... balance_on_day_30]
rolling_average = sum(daily_balances) / 30
passes = rolling_average >= 10
```

**On pass:** Proceed to Gate 3.

**On fail:** Return gate failure with:
```json
{
  "gate": "xlm_balance",
  "passed": false,
  "current_value": "{rolling_average} XLM (30-day average)",
  "minimum_required": "10 XLM (30-day average)",
  "message": "Your Stellar wallet's average XLM balance over the past 30 days is {rolling_average} XLM. A minimum average of 10 XLM is required. Top up your wallet and maintain that balance for 30 days before retrying."
}
```

**Re-verification trigger:** After passport creation, this gate is
re-evaluated on each scheduled indexer run. If the 30-day rolling
average drops below 10 XLM, the passport is flagged per FR-01.8 and
the contributor is notified. Flagging does not revoke the passport
per FR-02.3.

**Implementation notes:**
- If the account has fewer than 30 days of transaction history,
  use all available history and note the shorter window in the
  rolling average calculation. A wallet with only 20 days of history
  averages across those 20 days. This does not override Gate 1 — the
  account must still be at least 60 days old to reach Gate 2.
- Pagination: if the account has more than 200 effects in the 30-day
  window, paginate using the Horizon cursor until the window_start
  date is reached. Stop fetching once effects are older than 30 days.
- Round rolling_average to 2 decimal places in the rejection message.

---

## Gate 3: GitHub Activity

**Purpose:** Verify the contributor has a real, established GitHub
presence before their GitHub identity is anchored permanently to an
on-chain passport record.

This gate has two sequential sub-checks. Both must pass.

### Sub-check 3A: GitHub Account Age

**API endpoint:**
```
GET https://api.github.com/users/{github_username}
Authorization: Bearer {contributor_oauth_token}
```

**Field evaluated:**
```
response.created_at
```
ISO 8601 timestamp of GitHub account creation.

**Evaluation logic:**
```
elapsed_days = (current_utc_date - created_at_date).days
passes = elapsed_days >= 180
```

**On fail:** Return gate failure immediately without evaluating 3B:
```json
{
  "gate": "github_activity",
  "sub_check": "account_age",
  "passed": false,
  "current_value": "{elapsed_days} days",
  "minimum_required": "180 days",
  "days_remaining": "{180 - elapsed_days}",
  "dispute_available": false,
  "message": "Your GitHub account was created {elapsed_days} days ago. A minimum of 180 days is required. Your account will meet this requirement in {days_remaining} days."
}
```

### Sub-check 3B: GitHub Activity Check

Only evaluated if Sub-check 3A passes.

**Evaluation logic:**
```
passes = (public_repos >= 1) OR (stellar_contribution == true)
```

**Field for public_repos (from Sub-check 3A cached response):**
```
response.public_repos
```
Integer count of public repositories owned by the contributor.

**Stellar contribution check:**

A stellar contribution is defined as at least one merged pull request
into a repository registered in the ForgePass Stellar ecosystem
repository registry.

```
GET https://api.github.com/search/issues
  ?q=is:pr+is:merged+author:{github_username}+repo:{registered_repo_1}+repo:{registered_repo_2}+...
  &per_page=1
Authorization: Bearer {contributor_oauth_token}
```

If `response.total_count >= 1`, stellar_contribution is true.

The registered repository list is maintained by ForgePass admins via
Issue #042 (admin API) and stored in the `registered_repos` table.
The gate check must query the current registered repo list at
evaluation time, not use a hardcoded list.

**On pass (either branch):** Proceed to Gate 4.

**On fail:** Return gate failure with dispute option:
```json
{
  "gate": "github_activity",
  "sub_check": "activity_check",
  "passed": false,
  "public_repos": "{public_repos_count}",
  "stellar_contribution": false,
  "dispute_available": true,
  "dispute_type": "ONBOARDING_GATE_REJECTION",
  "message": "Your GitHub account meets the age requirement but does not yet meet the activity criteria. You need at least one public repository or one merged pull request into a registered Stellar ecosystem repository to qualify."
}
```

**Re-verification:** Not applicable. Public repo count and account age
can only increase after passport creation.

**Implementation notes:**
- Cache the GitHub user response from Sub-check 3A for use in
  Sub-check 3B. Do not make two calls to the same endpoint.
- The GitHub search API has a rate limit of 30 requests per minute
  for authenticated requests. The stellar contribution check counts
  against this limit. Implement backoff per the GitHub API
  rate limit headers (X-RateLimit-Remaining, X-RateLimit-Reset).
- If the registered repo list is empty (no repos registered yet),
  the stellar contribution branch evaluates to false and the
  public_repos branch is the only qualifying path.
- GitHub API occasionally returns stale public_repos counts for
  accounts that have recently created or deleted repositories.
  This is the primary reason ONBOARDING_GATE_REJECTION disputes
  exist. Do not cache the public_repos value — always fetch fresh
  at gate evaluation time.

---

## Gate 4: Duplicate Identity

**Purpose:** Prevent one GitHub identity from being linked to multiple
Stellar wallets and one Stellar wallet from being linked to multiple
GitHub accounts.

**Data source:** ForgePass PostgreSQL contributors table.

**Evaluation logic:**
```sql
-- Check 1: Is this GitHub account already linked to a different wallet?
SELECT wallet_address FROM contributors
WHERE github_user_id = {github_user_id}
AND wallet_address != {current_wallet_address}
LIMIT 1;

-- Check 2: Is this wallet already linked to a different GitHub account?
SELECT github_user_id FROM contributors
WHERE wallet_address = {current_wallet_address}
AND github_user_id != {github_user_id}
LIMIT 1;

passes = (check_1 returns no rows) AND (check_2 returns no rows)
```

Use `github_user_id` (integer) not `github_username` (string) for the
uniqueness check. GitHub usernames can be changed; user IDs cannot.

**On pass:** Proceed to passport creation.

**On fail:** Return gate failure with dispute option:
```json
{
  "gate": "duplicate_identity",
  "passed": false,
  "dispute_available": true,
  "dispute_type": "DUPLICATE_IDENTITY",
  "message": "This GitHub account is already linked to a different Stellar wallet. Each GitHub identity may only be linked to one Builder Passport. If you believe this is an error or your account has been compromised, please submit a dispute and our team will review it within 7 days."
}
```

**Implementation notes:**
- Use github_user_id from the GitHub OAuth token claims, not the
  username string. This prevents username change attacks.
- Run both SQL checks in a single transaction to avoid race conditions
  where two concurrent onboarding attempts for the same identity
  could both pass the check simultaneously. Use SELECT FOR UPDATE
  on the contributors row if it exists.
- This gate does not make any external API calls. It is the cheapest
  gate to evaluate and is placed last only because it is only
  meaningful after identity and activity are confirmed.

---

## Gate Response Schema

All gate responses follow this structure whether passing or failing:

```typescript
interface GateCheckResponse {
  passed: boolean;
  gates: {
    stellar_account_age: GateResult;
    xlm_balance: GateResult;
    github_activity: GateResult;
    duplicate_identity: GateResult;
  };
}

interface GateResult {
  passed: boolean;
  checked: boolean; // false if gate was not reached due to earlier failure
  current_value?: string;
  minimum_required?: string;
  message?: string;
  dispute_available?: boolean;
  dispute_type?: "ONBOARDING_GATE_REJECTION" | "DUPLICATE_IDENTITY";
}
```

The `POST /onboarding/check-gates` endpoint returns this structure
for the full gate sequence. Unchecked gates (due to earlier failure)
return `checked: false` with no other fields populated.

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| Horizon API unavailable | Return 503 with message: "The Stellar network is temporarily unavailable. Please try again in a few minutes." Do not fail the gate permanently. |
| Horizon 404 (account not found) | Fail Gate 1 with account not found message. |
| GitHub API unavailable | Return 503 with message: "GitHub is temporarily unavailable. Please try again in a few minutes." Do not fail the gate permanently. |
| GitHub OAuth token expired | Return 401 and prompt re-authentication via GET /auth/github. |
| GitHub API rate limit hit | Retry after X-RateLimit-Reset timestamp. Return 429 to the client with Retry-After header if retry window exceeds 30 seconds. |
| Database unavailable | Return 503. Do not fail Gate 4 permanently. |

Transient external API failures must never result in a permanent gate
failure for the contributor. Only deterministic checks (age, balance,
repo count) produce permanent gate failures.

---

*v1.0 · github.com/forgepass-xyz · MIT Licensed*
*Based on FRD v1.1 · Issues v1.1 · Issue #002 Roadmap v1.0*
*Companion documents: sybil-thresholds.json · threshold-rationale.md*
