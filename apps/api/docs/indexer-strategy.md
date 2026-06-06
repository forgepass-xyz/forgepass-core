# Indexer Strategy

**Issue:** #004 — Resolve: Indexer polling frequencies and webhook availability
**Phase:** 0 — Foundation and Setup
**Status:** Complete
**Config file:** `../config/indexer-config.json`
**Unblocks:** #031 (GitHub ingestion indexer) · #032 (Stellar Horizon ingestion indexer) · #033 (Soroban contract deployment indexer) · Phase 2 gate (FR-03-A)
**FRD coverage:** FR-03-A · FR-03.1 · FR-03.2 · FR-03.3 · FR-03.8 · FR-03.9 · FR-03.10 · NFR 16.2

---

## 1. Overview

This document defines how ForgePass observes the world. Every Trust Score, every credential record, and every on-chain anchor starts with signal ingestion. This strategy determines how each of the three confirmed v1 signal sources is polled, how cursors are advanced, and how failures are handled and alerted.

The three confirmed v1 sources are GitHub (merged PRs across registered Stellar ecosystem repositories), Stellar Horizon (on-chain transactions, DEX trades, and contract operations), and Aquarius LP positions (sourced via the Horizon operations stream rather than the Aquarius API directly). GrantFox, Trustless Work, and SCF are roadmap items reserved in `indexer-config.json` and not covered by this document.

All strategy parameters are committed to `../config/indexer-config.json`. This document provides the rationale and decision trail behind those parameters. Developers implementing #031, #032, and #033 should treat the config file as the specification and this document as the explanation.

---

## 2. Source API Characterisation

### 2.1 GitHub

| Dimension | Finding |
|---|---|
| Webhook availability | Org-level webhooks require an organisation owner with `admin:org_hook` scope. Even if available, org-level webhooks cover only repos inside `forgepass-xyz` — external Stellar repos still require polling regardless. |
| REST polling | `GET /repos/{owner}/{repo}/pulls?state=closed` with `Link: rel=next` cursor pagination. Incremental access via `merged_at` ISO 8601 timestamp. |
| Token architecture | GitHub App installation token: 15,000 req/hr, not tied to individual contributor OAuth sessions. Contributor OAuth tokens (5,000 req/hr per contributor, subject to revocation) ruled out for indexing. |
| Rate limits | GitHub App: 15,000 req/hr. Headers: `X-RateLimit-Remaining`, `X-RateLimit-Reset`. Secondary rate limit applies to concurrent bursting — avoid parallel repo queries. |
| Cross-repo coverage | FR-03.11 requires indexing all registered Stellar repos, not only contributor-linked ones. Per-repo polling naturally satisfies this — the indexer iterates over the registered repo list and matches merged PRs to contributor GitHub usernames. |

### 2.2 Stellar Horizon

| Dimension | Finding |
|---|---|
| SSE streaming | Available at collection endpoints (`/accounts/{id}/transactions`, `/accounts/{id}/trades`). Each heartbeat counts as a request (~12/min per stream = ~720 req/hr per open connection). At 100 concurrent contributor streams: ~72,000 req/hr against a 3,600 req/hr public endpoint limit. Infeasible on the public endpoint at any real contributor scale. |
| SSE via third-party provider | Removes the rate limit but adds monthly infrastructure cost, vendor dependency, and persistent connection management overhead for a latency improvement that is invisible to downstream consumers of a reputation system with a 60-second recalculation SLA. Not justified. |
| Batch polling | `GET /accounts/{id}/transactions?cursor={paging_token}&order=asc&limit=200`. The `paging_token` is monotonically increasing, durable across process restarts, and gap-free. Same cursor model applies to `/accounts/{id}/trades` and `/accounts/{id}/operations`. |
| Rate limits (public SDF) | 3,600 req/hr per IP. Headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`. HTTP 429 on breach with `Retry-After`. |
| History cap | Public SDF Horizon truncates historical data to 1 year as of August 2024. Contributors with activity older than 1 year will have an incomplete signal set on first onboarding. See open questions. |
| Soroban event detection | Soroban contract deployments appear as `invoke_host_function` operations in the account operations stream. No separate indexer pass needed. |
| DEX trade data | `/accounts/{id}/trades` returns asset pair, base/counter amount, price, timestamp, and trade type. Same `paging_token` cursor model as transactions. |

### 2.3 Aquarius

| Dimension | Finding |
|---|---|
| Per-account API endpoint | Not documented in public Aquarius API documentation. No confirmed per-account LP position endpoint available. |
| Streaming | No streaming, webhook, or push notification mechanism exists. Polling is the only available strategy. |
| Horizon as data path | Aquarius LP positions are visible in Horizon as account trustlines (LP share balances) and as `liquidity_pool_deposit`, `liquidity_pool_withdraw`, and `change_trust` operations in the account operations stream. This is the canonical, stable data path. |
| Aquarius API stability | No published SLA. Contract addresses rotate quarterly on testnet. Horizon-based path reads from the canonical Stellar ledger and is more stable. |

---

## 3. Trade-off Analysis

### 3.1 GitHub

| Approach | Latency | Reliability | Complexity | Cost | Total | Outcome |
|---|---|---|---|---|---|---|
| Org-level webhook | 3 | 2 | 2 | 3 | 10 | Ruled out — covers only forgepass-xyz repos; polling still required for external Stellar repos |
| Per-repo webhook | 3 | 2 | 1 | 3 | 9 | Ruled out — one webhook per registered repo, operationally expensive at scale |
| REST polling (GitHub App) | 2 | 3 | 3 | 2 | 11 | **Chosen** |

Scoring: 1 = poor, 2 = acceptable, 3 = good.

### 3.2 Stellar Horizon

| Approach | Latency | Reliability | Complexity | Cost | Total | Outcome |
|---|---|---|---|---|---|---|
| SSE streaming (public endpoint) | 3 | 1 | 1 | 1 | 6 | Ruled out — rate limit infeasible at scale |
| SSE streaming (third-party provider) | 3 | 2 | 1 | 2 | 8 | Ruled out — cost and complexity unjustified for the latency gain |
| Batch polling (paging_token) | 2 | 3 | 3 | 2 | 10 | **Chosen** |

### 3.3 Aquarius

| Approach | Latency | Reliability | Complexity | Cost | Total | Outcome |
|---|---|---|---|---|---|---|
| Aquarius API (direct) | 2 | 1 | 2 | 2 | 7 | Ruled out — no per-account endpoint, unknown rate limits, no SLA |
| Horizon trustlines and operations | 2 | 3 | 3 | 3 | 11 | **Chosen** — folds into existing Horizon pass, no additional dependency |

---

## 4. Per-Source Strategy

All numeric parameters below are committed to `../config/indexer-config.json`. This section provides the rationale.

### 4.1 GitHub

**Primary mechanism:** REST polling via GitHub App installation token.

**Query strategy:** Per registered repo. For each run cycle, the indexer iterates over all registered Stellar ecosystem repos, fetches merged PRs since the last cursor, and matches them to contributors by GitHub username stored in the database. This is more efficient than per-contributor per-repo queries (which scale as contributors × repos) and naturally satisfies FR-03.11 cross-project indexing.

**Polling interval:** 15 minutes. With a GitHub App installation token (15,000 req/hr) and per-repo querying, 500 registered repos at 15-minute intervals consumes ~2,000 req/hr — well within quota headroom.

**Cursor:** `merged_at` ISO 8601 timestamp. Stored in `indexer_runs` as `last_successful_cursor` for `pass_type = GITHUB_PRS`. See open questions for per-repo cursor granularity detail deferred to #031.

**Webhooks:** Not used. Rationale: org-level webhooks cover only `forgepass-xyz`-internal repos. External Stellar repos — the majority of the registered repo set — still require polling regardless. A dual architecture (webhook for internal, polling for external) adds a webhook receiver to maintain and a dead-letter recovery path to test, for no net reduction in polling surface.

**Pass type in `indexer_runs`:** `GITHUB_PRS`

---

### 4.2 Stellar Horizon

**Primary mechanism:** Batch polling on the public SDF Horizon endpoint.

**SSE ruling:** SSE streaming is infeasible on the public endpoint at any real contributor scale (see Section 3.2). A third-party provider removes the rate limit but adds cost and complexity for a latency improvement that is not visible to downstream consumers of a reputation system. Batch polling at 5-minute intervals provides a maximum 5-minute signal lag, which is well within the 60-second end-to-end recalculation SLA in FRD NFR 16.1.

**Three independent passes:** Horizon data is split into three pass types with independent cursors and failure counters. A failure in one pass does not stall the others.

#### HORIZON_TRANSACTIONS
- Endpoint: `GET /accounts/{id}/transactions`
- Interval: 5 minutes
- Cursor: `paging_token` (monotonically increasing, gap-free, restartable)
- Page size: 200 (Horizon maximum)
- Signal types: general on-chain activity

#### HORIZON_TRADES
- Endpoint: `GET /accounts/{id}/trades`
- Interval: 5 minutes
- Cursor: `paging_token`
- Page size: 200
- Signal types: `STELLAR_DEX` trades (asset pair, volume, price, timestamp)

#### HORIZON_OPERATIONS
- Endpoint: `GET /accounts/{id}/operations`
- Interval: 5 minutes
- Cursor: `paging_token`
- Page size: 200
- Signal types: `SOROBAN_CONTRACT` (filtered on `invoke_host_function`) and `AQUARIUS_LP` (filtered on `liquidity_pool_deposit`, `liquidity_pool_withdraw`, `change_trust`)
- Aquarius note: LP data is sourced from this pass rather than from the Aquarius API. LP share trustlines and deposit/withdrawal events are fully visible in the Horizon operations stream. No Aquarius API dependency is required.

**Why three passes at the same interval:** LP position data changes slowly; however, the `HORIZON_OPERATIONS` pass also covers Soroban contract deployments, which benefit from prompt detection. Running all three passes at the same 5-minute interval maintains a single scheduler cadence and avoids special-casing. The additional request cost is negligible at contributor scale.

**Horizon provider:** Public SDF endpoint (`https://horizon.stellar.org`) for v1. See open questions for the 1-year history cap impact.

---

### 4.3 Aquarius

Aquarius LP data is not a separate indexer pass. It is fully covered by the `HORIZON_OPERATIONS` pass (Section 4.2). No direct Aquarius API calls are made in v1. This decision removes one external API dependency, uses a more stable and documented data path, and adds no additional request overhead.

---

### 4.4 Reserved future sources

The following sources are reserved in `../config/indexer-config.json` with placeholder entries. No strategy parameters are defined for them in v1. Each is gated on #009 (FR-09-B — partnership confirmation).

| Source | Expected mechanism | Gate |
|---|---|---|
| `GRANTFOX_BOUNTY` | Webhook or polling — TBD on partnership confirmation | #009 |
| `TRUSTLESS_WORK` | Webhook with HMAC signature verification | #009 |
| `SCF_GRANT` | CSV batch upload or API — TBD (SCF has no public API) | #009 |

When a future source is confirmed, a new `pass_type` enum value is added to `indexer_runs` and a new strategy block is added to `indexer-config.json` following the same schema used for v1 sources.

---

## 5. Failure Handling and Retry Policy

All failure model parameters are committed to the `failure_model` block in `../config/indexer-config.json`.

### 5.1 Retry policy

| Parameter | Value | Rationale |
|---|---|---|
| Max retries per run | 3 | Aligned with NFR 16.2. After 3 failures within a single run cycle, the pass is skipped and the failure recorded. |
| Backoff strategy | Exponential with jitter | Prevents hammering a failing external API with immediate retries. |
| Base delay | 5 seconds | Short enough to recover from transient errors within the same polling cycle. |
| Multiplier | 2× | Standard exponential multiplier. |
| Max delay | 60 seconds | Caps total retry wait at ~35 seconds — well within any configured polling interval. |
| Jitter | ±20% | Spreads concurrent contributor retries to prevent thundering herd against the same external API. |
| Retry sequence | ~5s → ~10s → ~20s | Approximate. Actual values vary by ±20%. |

### 5.2 Failure isolation

Passes run independently per contributor. A failure in `HORIZON_TRADES` does not stall `HORIZON_TRANSACTIONS` or `GITHUB_PRS` for the same contributor in the same cycle. Each pass type has its own `indexer_runs` row with its own cursor, failure counter, and status.

### 5.3 Credential safety

A pass failure is a skip, not a rollback. Existing credential records are never modified or deleted as a result of a failed run. The next successful run resumes from `last_successful_cursor` without re-processing already-indexed events.

### 5.4 Alert definitions

All four alerts are implemented by #078 (monitoring, alerting, and observability).

#### INDEXER_PASS_FAILURE
- **Trigger:** `consecutive_failure_count` reaches 3 for any `pass_type` + `wallet_address` combination.
- **Scope:** Per contributor per pass. Does not fire on isolated or transient failures.
- **Severity:** High.
- **Action:** Log structured error with `pass_type`, `wallet_address`, `failure_reason`, and `run_id`. Fire alert to on-call channel. Do not halt other passes for the same contributor.

#### INDEXER_APP_TOKEN_FAILURE
- **Trigger:** GitHub API returns 401 or 403 on any request using the GitHub App installation token.
- **Scope:** Global — a token failure halts all contributors' `GITHUB_PRS` passes simultaneously. This is categorically different from a per-contributor pass failure, which affects one contributor. Waiting for three per-contributor consecutive failures to surface a token issue would delay detection by up to three full polling cycles.
- **Severity:** Critical.
- **Action:** Halt the GitHub indexer immediately. Do not retry until the token is refreshed — retrying burns quota against a known-broken token. Log response status and request URL. Fire high-severity alert to on-call channel.

#### INDEXER_RATE_LIMIT_HIT
- **Trigger:** GitHub: `X-RateLimit-Remaining` drops below 100. Horizon: 429 response received during any pass.
- **Scope:** Per source. GitHub rate limit is shared across all contributors — a hit affects all `GITHUB_PRS` passes.
- **Severity:** Warning.
- **Action:** Pause the affected source. Resume after the `Retry-After` header window. Log the event. Fire alert if the rate limit is hit on more than 3 consecutive runs — this indicates the polling interval is too aggressive for the current contributor volume and the interval should be increased.

#### INDEXER_CURSOR_STALE
- **Trigger:** `last_successful_cursor` has not advanced for more than 2× the configured `polling_interval_minutes` for a given `pass_type` + `wallet_address`.
- **Scope:** Per contributor per pass.
- **Severity:** Warning at 2× interval. Alert at 3× interval.
- **Action:** Log a warning at 2×. Fire alert at 3×. Investigate scheduler health and whether the contributor's pass is being enqueued correctly. This is distinct from `INDEXER_PASS_FAILURE` — a stale cursor may indicate a scheduling gap rather than an API failure.

### 5.5 Log event format

Every indexer run produces a structured JSON log entry with the following fields. All log lines also include standard fields from the NestJS global logging config: `level`, `service`, `timestamp`.

| Field | Type | Description |
|---|---|---|
| `run_id` | UUID | `indexer_runs` primary key for this run |
| `pass_type` | ENUM | `GITHUB_PRS` \| `HORIZON_TRANSACTIONS` \| `HORIZON_TRADES` \| `HORIZON_OPERATIONS` |
| `wallet_address` | String | Contributor Stellar public key |
| `status` | ENUM | `SUCCESS` \| `FAILURE` \| `PARTIAL` |
| `failure_reason` | String or null | HTTP status + message, or exception type and message. Null on success. |
| `retry_count` | Integer | 0–3 |
| `consecutive_failures` | Integer | Current `consecutive_failure_count` value after this run |
| `cursor_before` | String | Cursor value at start of run |
| `cursor_after` | String or null | Cursor value at end of run. Null on failure. |
| `timestamp` | ISO 8601 | Run completion time |

---

## 6. `indexer_runs` Table Requirements for #013

One row per contributor per pass type. The schema below must be reflected in migration 010 (indexer_runs table) in #030.

| Column | Type | Notes |
|---|---|---|
| `run_id` | UUID | Primary key |
| `pass_type` | ENUM | `GITHUB_PRS` \| `HORIZON_TRANSACTIONS` \| `HORIZON_TRADES` \| `HORIZON_OPERATIONS` — extensible when future sources are confirmed |
| `wallet_address` | FK | → `passports.wallet_address` |
| `status` | ENUM | `SUCCESS` \| `FAILURE` \| `PARTIAL` |
| `last_successful_cursor` | TEXT | ISO 8601 timestamp for `GITHUB_PRS`. `paging_token` string for Horizon passes. |
| `last_run_at` | TIMESTAMP | When this pass last executed |
| `consecutive_failure_count` | INTEGER | Resets to 0 on `SUCCESS`. Alert threshold: 3. |
| `failure_reason` | TEXT | Last error message, or null on success |

---

## 7. Open Questions at Close

The following items are unresolved at the time this document is merged. Each has a linked resolution path and does not block this issue from closing.

### 7.1 Horizon 1-year history cap

The public SDF Horizon endpoint truncates historical data to 1 year as of August 2024. A contributor who onboards with Stellar activity older than 1 year will have an incomplete signal set on first ingestion. Their Trust Score will be lower than it should be and will improve incrementally as new activity is indexed going forward.

**Resolution path:** Acceptable as a known limitation for v1. Document in contributor-facing onboarding copy. Evaluate a third-party Horizon provider (QuickNode, Blockdaemon) before mainnet if full history ingestion becomes a product requirement. No issue created yet — flag for Phase 5 readiness review (#079).

### 7.2 GITHUB_PRS cursor granularity

The `indexer_runs` schema stores one `GITHUB_PRS` row per contributor. However, GitHub polling runs per registered repo. If some repos fail during a run and others succeed, the per-contributor cursor would need to represent a mixed state. Whether to store a single `merged_at` cursor per contributor (simplest) or one cursor per contributor per repo (most precise) is an implementation decision deferred to #031.

**Resolution path:** #031 to define the cursor storage approach in its implementation. Per-contributor cursor (single `merged_at` of the most recently indexed PR across all repos) is the recommended starting point — simpler, and partial repo failures are recovered by the next full polling cycle.

### 7.3 Horizon pass scheduling order

Whether the three Horizon passes run sequentially or in parallel per contributor is an implementation detail for #031, #032, and #033. Parallel is faster but triples the Horizon request rate per contributor per cycle. Sequential is slower per contributor but more predictable under rate limit conditions.

**Resolution path:** #032 and #033 to decide based on observed Horizon request rates during Phase 2 development. Sequential is the safer default.

---

## 8. Acceptance Criteria Verification

| AC | Criterion | Status |
|---|---|---|
| AC-1 | `indexer-config.json` committed with strategy block for all three v1 sources, all parameters set, no TBD values | Complete |
| AC-2 | Primary mechanism for each source declared and justified with trade-off reference | Complete — Section 4 |
| AC-3 | Cursor types defined and compatible with `indexer_runs` schema | Complete — Section 6 |
| AC-4 | Failure handling model documented: max retries, backoff, alert threshold, isolation, credential safety | Complete — Section 5 |
| AC-5 | All four alert definitions documented with trigger conditions and log field requirements | Complete — Section 5.4 |
| AC-6 | `reserved_future_sources` in config lists GRANTFOX_BOUNTY, TRUSTLESS_WORK, SCF_GRANT | Complete |
| AC-7 | Comments posted on #031, #032, #033, and #013 | Pending — post on merge |
| AC-8 | PR approved by at least two team members before merge | Pending |

---

*Issue #004 · Phase 0 · github.com/forgepass-xyz · MIT Licensed*
