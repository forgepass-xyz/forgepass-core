# ForgePass API Rate Limiting Strategy

**Version:** 1.0  
**Date:** 2026-06-12  
**Issue:** #005 — Resolve: Rate limit tiers (DECISION NEEDED FR-07-A)  
**Status:** Decided — closed  
**FRD coverage:** FR-07-A · FR-07.5 · FR-07.6 · NFR 16.1 · NFR 16.2  
**Unblocks:** #040 (rate limiting implementation) · Phase 2 gate (FR-07-A must be resolved before Phase 2 begins)

---

## 1. Overview

This document records every decision made in issue #005 about the ForgePass API rate limit strategy: which caller types exist, what limits apply to each, what window algorithm is used, how the batch score endpoint is counted, and what the 429 response body looks like. It is the specification that issue #040 (rate limiting implementation) builds against.

Two FRD requirements directly depend on this document. FR-07.5 states the API must enforce rate limits on unauthenticated requests to prevent abuse and that authenticated requests should receive higher limit tiers. FR-07-A (DECISION NEEDED) requires the exact tier values to be defined before Phase 2 begins. Both are resolved here.

The config file that codifies all numeric values is at `forgepass-core/apps/api/config/rate-limit-config.json`. Every value in that file has a rationale field. This document provides the full reasoning behind each.

---

## 2. Benchmark Summary

Five comparable public APIs were surveyed before any ForgePass-specific values were proposed. The goal was to establish a reference range and anchor ForgePass's limits against expectations developers in the Stellar and Web3 ecosystem already have.

| API | Unauthenticated | Authenticated / registered | Window type |
|---|---|---|---|
| Stellar Horizon (SDF public) | 3,600/hr (60/min) per IP | N/A — no auth model | GCRA (leaky bucket) |
| GitHub REST API | 60/hr (~1/min) per IP | 5,000/hr PAT; 15,000/hr GitHub App | Rolling hour |
| CoinGecko Demo plan | 30/min stable (key required) | 500/min (Analyst); 1,000/min (Pro) | Rolling minute |
| Blockscout REST API | ~10 RPS per IP | PRO plan; 5 RPS free floor | Per-IP |
| Etherscan | ~300/min (free key required) | ~600/min free key | Per-second |

The Stellar Horizon public limit (60/min per IP) is the most relevant reference for the ForgePass unauthenticated tier. Horizon is the infrastructure layer ForgePass contributors interact with daily. Its limit is well understood by Stellar developers and sets a credible floor. The CoinGecko model (free tier at 30/min, paid tier at 500-1,000/min) is the closest structural analogue to the ForgePass two-tier model and validated the integrator tier range.

**Window type comparison:**

Four window algorithms were evaluated: fixed window, sliding window log, sliding window counter, and token bucket.

Fixed window was ruled out. It allows boundary bursting — a caller can exhaust the full quota at :59 and again at :00, effectively doubling the real limit for a scraper that knows the reset interval.

Sliding window log was ruled out. It stores a Redis ZADD timestamp entry per request per caller key. At scale (many concurrent unauthenticated callers), the memory cost is disproportionate to the precision benefit over the counter approach.

Token bucket was ruled out for the unauthenticated tier. The burst cap adds configuration complexity and is harder to explain to API consumers who expect a simple req/min ceiling. Token bucket is the right choice if ForgePass later needs per-request cost weighting (e.g. the batch endpoint costing more than a single GET), but that is not a v1 requirement.

**Recommended and adopted: sliding window counter.** Two Redis counters are maintained per caller key — one for the current window and one for the previous window. The effective count at any moment is blended by the fraction of the current window that has elapsed. This prevents boundary bursting in practice, is Redis-native via the standard `nestjs-throttler-storage-redis` package, and requires only a ~30-line extension of the standard `@nestjs/throttler` guard. No additional library dependency is introduced.

NestJS compatibility note: `@nestjs/throttler` does not natively implement sliding window counter. The `nestjs-throttler-storage-redis` package provides Redis-backed storage. Issue #040 must implement the two-counter blend logic as a custom ThrottlerGuard extension on top of this storage layer. This is a well-understood pattern with multiple reference implementations available.

---

## 3. Traffic Model

### 3.1 Unauthenticated callers

Three realistic unauthenticated use cases were modelled:

A developer testing an endpoint from a browser or curl generates fewer than 10 req/min. A visitor actively browsing the passport explorer, applying filters, and paginating generates 2-8 req/min during active browsing. A third-party application rendering a contributor leaderboard on page load may burst to 20 req/min before going idle.

The threat model the unauthenticated limit must stop is a scraper attempting to harvest the full contributor index. At 10,000 contributors and a 60/min limit, scraping the full index from a single IP takes approximately 167 minutes (10,000 / 60 ≈ 167 min) of sustained effort. This makes casual scraping impractical without IP rotation. IP rotation is a CDN and WAF concern — the rate limiter's job is to stop unsophisticated scrapers, not adversarial infrastructure.

### 3.2 Integrator-authenticated callers

Four integrator workflows were modelled:

A GrantFox-style batch ranker submits 1 POST to `/v1/scores/batch` per applicant cohort. This generates 1-3 req/min even during active campaign processing — far below any meaningful limit. The constraint for this caller is the batch endpoint's 100-address ceiling, not the rate limit.

A Stellar DAO reading governance weights for 50 voters before a vote generates 50 individual requests if calling `/v1/governance/weight/:address` per voter, or 1 request if calling the batch endpoint. The individual call pattern (50 req/min burst) is the stress case and drove the lower bound for the integrator tier.

A Trustless Work milestone credential feed generates 1-2 requests per escrow completion event, typically fewer than 5 req/min. The rate limit is irrelevant for this caller.

A leaderboard-polling integrator querying 200 contributors every 5 minutes generates 40 req/min via individual GET calls, or fewer than 1 req/min if using the batch endpoint with 2 calls of 100 addresses each. The individual polling pattern is the most demanding legitimate workflow identified in v1.

### 3.3 Batch endpoint counting decision

The batch endpoint (`POST /v1/scores/batch`, up to 100 addresses per request) counts as **1 request** against the caller's quota.

The alternative — counting as N addresses — would require setting the integrator limit above 100 purely to handle a single full-batch call, which defeats the purpose of the batch endpoint. A motivated abuser can already call 100 individual GET endpoints in sequence to retrieve the same data. The batch endpoint is an efficiency feature for legitimate integrators. Rapid repeated full-batch calls by a misconfigured integrator are caught by the integrator tier limit regardless of the per-request weight.

---

## 4. Tier Definitions

### 4.1 Unauthenticated

**Limit:** 60 requests per 60-second sliding window  
**Identification:** IP address, read from `X-Forwarded-For` header when behind a load balancer  
**Scope:** Per-IP global (not per-IP-per-endpoint)  
**Applies to:** All `GET /v1/*` endpoints and `POST /v1/scores/batch`

60 req/min was chosen over 30 (CoinGecko's free floor) because ForgePass's core value proposition is public verifiability — anyone should be able to check a contributor's credentials without friction. The leaderboard burst use case reaches 20 req/min, leaving only 10 req/min of headroom at 30. At 30 there is a real risk of 429-ing a legitimate third-party application on page load. 60 covers all legitimate patterns with 3x headroom above the highest identified burst rate, matches Horizon's public floor, and is a number Stellar ecosystem developers will recognise as reasonable.

Per-IP global scope was chosen over per-IP-per-endpoint because per-endpoint would allow a single IP to consume 60/min against `/v1/passport/:address` and 60/min against `/v1/score/:address` simultaneously, effectively doubling the real limit for multi-endpoint workflows.

**Load balancer note:** NestJS must be configured with `app.set('trust proxy', 1)` or equivalent in the HTTP adapter to read the real client IP from `X-Forwarded-For` when deployed behind a load balancer. Without this, every unauthenticated request appears to originate from the load balancer's IP and a single 429 fires after 60 total requests across all users. This configuration belongs in issue #023 (NestJS application core setup). Issue #040 must verify this is in place before deploying the rate limiter to staging.

### 4.2 Integrator-authenticated

**Limit:** 600 requests per 60-second sliding window  
**Identification:** `X-ForgePass-Key` header (API key issued after admin approval via #061)  
**Applies to:** All `GET /v1/*` and `POST /v1/*` endpoints

600 req/min provides 6x headroom above the most demanding identified legitimate integrator workflow (40 req/min individual leaderboard polling). It covers a DAO reading 50 governance weights in rapid succession with substantial room to spare.

600 was chosen over 1,000 for two reasons. First, raising a limit is easier than lowering one after integrators are live — lowering causes immediate breakage for any caller whose workflow fits between the old and new ceiling. Second, at 1,000 req/min a single integrator key could theoretically query 1,000 × 100 = 100,000 addresses per minute via the batch endpoint, which is infrastructure load not yet validated by load testing (#072). The integrator limit should be revisited alongside Phase 4 load test results and updated in a config v1.1 if real usage data shows legitimate patterns approaching the ceiling.

### 4.3 SDK-authenticated (reserved)

**Limit:** null — not active in v1  
**Identification:** To be defined when #010 resolves  

The ForgePass SDK is a roadmap item. All FR-10 requirements are deferred in FRD v1.1. The SDK tier config slot is reserved here so that activating it requires only adding a numeric value to `rate-limit-config.json`, not a schema change. The limit and identification method will be defined in the issue spawned by #010 (FR-10-A). The provisional assumption is that SDK-authenticated callers will share the integrator tier limit or receive a distinct tier at or above 600 req/min, but this is not committed until #010 resolves.

---

## 5. 429 Response Schema

All 429 responses from the ForgePass API use the following body structure, consistent with the structured error format defined in issue #023 (NestJS global exception filter):

```json
{
  "statusCode": 429,
  "error": "Too Many Requests",
  "message": "Rate limit exceeded. See Retry-After header.",
  "tier": "<unauthenticated | integrator>",
  "limit": 60,
  "window_seconds": 60,
  "retry_after_seconds": 14,
  "requestId": "<correlation ID from X-Request-ID header>"
}
```

**Field definitions:**

`statusCode` — always 429.  
`error` — always "Too Many Requests".  
`message` — human-readable string. May be localised in future but is English in v1.  
`tier` — the rate limit tier that fired. Useful for integrators debugging whether they are hitting the unauthenticated or integrator ceiling.  
`limit` — the tier limit that applies to this caller.  
`window_seconds` — always 60 in v1. Included so callers do not need to read the docs to understand the window duration.  
`retry_after_seconds` — the number of seconds until the oldest request in the caller's current window expires (sliding window semantics). For a sliding window this is not a fixed reset time — it is the actual time until the caller can make their next request without being blocked. This is also set in the `Retry-After` response header.  
`requestId` — the correlation ID assigned to this request by the NestJS correlation ID middleware (#023). Used by integrators when reporting rate limit issues to ForgePass support.

**Response headers on 429:**

| Header | Value |
|---|---|
| `Retry-After` | Seconds until the caller's oldest in-window request expires |
| `X-RateLimit-Limit` | The tier limit value for this caller |
| `X-RateLimit-Remaining` | Always 0 on a 429 response |
| `X-RateLimit-Reset` | Unix timestamp (seconds) at which the full window capacity is restored |

Note on `retry_after_seconds` for sliding window: the value is the time until the single oldest request in the window expires, not the full window duration. For a caller who has been making steady requests, this will often be a small number (1-5 seconds) rather than the full 60-second window. This is intentional — it gives callers an accurate wait time and avoids unnecessary backoff.

---

## 6. Batch Endpoint Policy

`POST /v1/scores/batch` accepts up to 100 Stellar wallet addresses per request and returns Trust Scores for all of them in a single response.

**Request weight: 1.** A single batch call counts as 1 request against the caller's quota regardless of the number of addresses in the batch (up to the 100-address ceiling).

This decision is documented in Section 3.3. The 100-address ceiling per request is a hard limit enforced at the input validation layer (#023 global validation pipe). It is not a rate limit mechanism. The rate limit and the batch ceiling are independent controls.

---

## 7. SDK Reserved Slot

The `sdk` tier in `rate-limit-config.json` is a placeholder object with `limit: null` and `status: "reserved — not active in v1"`. It is gated on issue #010 (FR-10-A — SDK development phase and resource allocation decision).

When #010 resolves and SDK development begins, the following must be added to `rate-limit-config.json` as a config v1.1 update:
- `sdk.limit` — a numeric value (suggested: match or exceed the integrator tier)
- `sdk.identification` — the header or mechanism used to identify SDK-authenticated callers
- `sdk.applies_to` — the endpoint set

A comment has been posted on issue #010 referencing this reserved slot so the SDK planning issue knows the config structure is already prepared.

---

## 8. Misconfigured Integrator Alerting

A single 429 from an integrator is expected and handled by the SDK's automatic retry logic (FR-10.6) or the integrator's own backoff implementation. It does not warrant an alert.

Sustained rate limit hits across 3 consecutive 60-second windows from the same integrator key indicate a misconfigured tight loop, not a legitimate burst. In this case an `INTEGRATOR_RATE_LIMIT_SUSTAINED` alert is raised (consistent with the 3-consecutive-failure alert threshold established in #004 for the indexer pipeline). The alert does not block the integrator beyond the standard 429 — it gives the ForgePass team visibility to proactively contact the integrator before they file a support request. This alert type must be registered in the observability setup (#078).

---

## 9. Open Questions at Close

The following questions were open when this issue started and are now resolved:

| Question | Resolution |
|---|---|
| Does `@nestjs/throttler` support sliding window counter natively? | No. Requires `nestjs-throttler-storage-redis` plus a ~30-line custom ThrottlerGuard extension implementing the two-counter blend. Detailed in issue #040. |
| Should `POST /v1/scores/batch` count as 1 request or N requests? | 1 request. Documented in Section 3.3 and `rate-limit-config.json batch_endpoint.request_weight`. |
| Per-IP global vs per-IP-per-endpoint for unauthenticated tier? | Per-IP global. Documented in Section 4.1. |
| Does X-Forwarded-For trust need explicit NestJS configuration for load balancer deployment? | Yes. `app.set('trust proxy', 1)` required in #023. Flagged as a cross-reference requirement in #040. |
| Should a misconfigured integrator silently receive 429s or also trigger an alert? | Alert after 3 consecutive window cycles. Documented in Section 8. |
| What `retry_after_seconds` value should the 429 return for a sliding window? | Time until the oldest in-window request expires (not the full window reset). Documented in Section 5. |

No questions are carried forward as unresolved. This issue is closed.

---

## 10. Revision History

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-06-12 | Initial release. Issue #005 resolved. Unauthenticated: 60 req/min per IP global. Integrator: 600 req/min per X-ForgePass-Key. Batch weight: 1. Window: sliding window counter 60s. SDK tier: null reserved pending #010. All six open questions resolved. |
