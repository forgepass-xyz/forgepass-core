# Governance weight blending — strategy & endpoint design

**Status:** DRAFT — pending DAO partnership confirmation via #009 (FR-09-B)  
**Issue:** #006 · Resolve: DAO governance weight blending ratio (DECISION NEEDED FR-09-A)  
**Resolves:** FR-09-A  
**Referenced by:** #060 (implement DAO governance weight endpoint)  
**Date:** 2026-06-12  

---

## 1. Context

The ForgePass governance weight endpoint (`GET /v1/governance/weight/:address`) allows
Stellar DAOs to incorporate contributor credibility into their voting weight calculations.
It returns two fields:

- `contribution_weight` — the contributor's normalised Trust Score (0.0–1.0)
- `suggested_blend_weight` — the contribution component pre-weighted by the blend ratio,
  ready to add to the DAO's normalised token weight

ForgePass provides the **contribution side only**. The DAO is responsible for normalising
their own token weight and combining both values. The `suggested_blend_weight` is advisory —
DAOs may ignore it and work directly with `contribution_weight` if they prefer.

---

## 2. Decision A — Default blend ratio

**Decision: 70% token / 30% contribution (global default)**

The default `contribution_ratio` is **0.30**.

### Rationale

- Conservative entry point: a new DAO adopting ForgePass can apply the default without
  internal governance debate about disrupting existing token-holder dynamics.
- Still materially impactful: a contributor with Trust Score 74 contributes a
  `suggested_blend_weight` of 0.222 — meaningful signal, not a rounding error.
- Consistent with the FRD v1.1 explicit suggestion (FR-09.3).
- Precedent survey: five systems surveyed (Gitcoin, Optimism, SCF NQG, MakerDAO, Uniswap).
  70/30 sits at the conservative end of the hybrid range but is correct for a v1 additive
  signal on an ecosystem where DAOs have existing token governance.
- Stellar context: SCF uses pure reputation governance (NQG — 0% token / 100% contribution),
  signalling the Stellar ecosystem is comfortable with high contribution weight. DAOs that
  want to move toward the SCF model can raise their ratio via per-DAO configuration (Decision B).

### Blend formula

```
contribution_weight   = trust_score / 100
suggested_blend_weight = contribution_weight × contribution_ratio
```

Example at default 0.30 ratio, Trust Score 74:

```
contribution_weight    = 74 / 100 = 0.74
suggested_blend_weight = 0.74 × 0.30 = 0.222
```

DAO computes final vote weight:

```
final_vote_weight = (token_holdings / total_token_supply × 0.70) + 0.222
```

---

## 3. Decision B — Fixed vs configurable

**Decision: Configurable per DAO at integrator registration, with global default fallback**

### How it works

1. At integrator registration (`POST /integrators/register`), an optional
   `contribution_ratio` field may be submitted (float, range 0.10–0.70).
2. If provided, it is stored in the `integrators` table alongside the wallet address
   and project name.
3. If omitted, it defaults to `null` in the database, and the global default (0.30)
   is applied at query time — not stored — so a future change to the global default
   automatically applies to all unset integrators.
4. At query time:
   - With `?dao=<integrator_id>`: load that integrator's `contribution_ratio`; fall back
     to global default if null.
   - Without `?dao=` param: use global default (0.30). This covers unauthenticated callers
     and any caller that does not need DAO-specific blending.

### Bounds constraint

`contribution_ratio` must be in the range **0.10–0.70** (inclusive).

- **Floor 0.10:** prevents a DAO registering with near-zero contribution weight, which
  would make the endpoint meaningless and waste a registered integrator slot.
- **Ceiling 0.70:** prevents a DAO pushing contribution weight above token weight via
  the ForgePass endpoint in a way that could not be audited by their own token holders.
  DAOs that want contribution-only governance (e.g. SCF-style) should build that
  independently using the raw `contribution_weight` field.

Validation returns `400 Bad Request` with a clear message if the value is out of range.

### Rationale for configurable over fixed

- Different Stellar DAOs have fundamentally different governance goals:
  - A grant DAO (e.g. GrantFox-style) may want 50/50 — builder credibility matters as
    much as economic stake.
  - A protocol upgrade DAO may want 80/20 — token holders bear the economic risk of
    upgrades and should dominate.
  - A community fund DAO may want 60/40.
- Fixing the ratio at 70/30 would force every DAO to post-process `contribution_weight`
  manually to apply their preferred ratio, which defeats the purpose of `suggested_blend_weight`.
- Implementation overhead is minimal: one extra nullable column on the integrators table,
  one optional query param, one lookup per request.

---

## 4. API endpoint contract

```
GET /v1/governance/weight/:address[?dao=<integrator_id>]
```

### Response shape

```json
{
  "address": "GXYZ...",
  "contribution_weight": 0.74,
  "suggested_blend_weight": 0.222,
  "blend_ratio": {
    "contribution": 0.30,
    "token": 0.70,
    "source": "global_default"
  },
  "score_version": "1.1",
  "computed_at": "2026-06-12T10:00:00Z"
}
```

### Field definitions

| Field | Type | Description |
|---|---|---|
| `contribution_weight` | float (0.0–1.0) | Trust Score / 100. Raw contribution score before blending. |
| `suggested_blend_weight` | float (0.0–0.70) | `contribution_weight × contribution_ratio`. Add to normalised token weight. |
| `blend_ratio.contribution` | float | The `contribution_ratio` applied in this response. |
| `blend_ratio.token` | float | `1 - contribution_ratio`. Informational — DAO applies this to their token weight. |
| `blend_ratio.source` | string | `"global_default"` or `"dao_config"`. Tells callers whether a DAO-specific ratio was applied. |
| `score_version` | string | Algorithm version that produced the Trust Score. For DAO audit trail. |
| `computed_at` | ISO 8601 | When the Trust Score snapshot was last computed. |

### Error cases

| Condition | Status | Response |
|---|---|---|
| Address has no passport | 404 | `{ "error": "PASSPORT_NOT_FOUND" }` |
| Address has sybil flag | 404 | Same as not found — do not reveal flag status |
| `?dao=` param references unknown integrator | 400 | `{ "error": "UNKNOWN_INTEGRATOR" }` |
| Passport exists but score not yet computed | 200 | `contribution_weight: 0`, `suggested_blend_weight: 0` |

---

## 5. Integrators table change

Add one nullable column to the `integrators` table (migration in #030):

```sql
ALTER TABLE integrators
  ADD COLUMN contribution_ratio NUMERIC(4,3) DEFAULT NULL
  CONSTRAINT contribution_ratio_range CHECK (
    contribution_ratio IS NULL OR
    (contribution_ratio >= 0.10 AND contribution_ratio <= 0.70)
  );
```

- `NULL` = use global default at query time.
- Constraint enforced at the database layer in addition to application-layer validation.
- No migration required for existing integrator rows — `NULL` defaults to global default.

---

## 6. Global default config

The global default is stored in `core/api/config/rate-limit-config.json`... no — it belongs
in its own config file so it can be updated independently of rate limits.

Store in `core/api/config/governance-config.json`:

```json
{
  "version": "1.0",
  "default_contribution_ratio": 0.30,
  "contribution_ratio_min": 0.10,
  "contribution_ratio_max": 0.70,
  "changelog": [
    {
      "version": "1.0",
      "date": "2026-06-12",
      "changes": "Initial governance weight config. Default 70/30 blend ratio. Per-DAO configurable range 0.10–0.70."
    }
  ]
}
```

Updating `default_contribution_ratio` in this file takes effect for all integrators
with `contribution_ratio IS NULL` on the next API deploy, with no database migration.

---

## 7. Open questions carried forward

### OQ-1 — DAO consultation (gated on #009)

The issue tasks require consulting at least one Stellar DAO about their preferred blending
approach before this document is finalised. This consultation is blocked on #009 (FR-09-B)
confirming at least one DAO partnership.

**Status:** Open. Resolution path: #009 confirms a Stellar DAO partner → ForgePass team
presents this document's defaults to that DAO for feedback → update `default_contribution_ratio`
in `governance-config.json` if the DAO strongly prefers a different default before launch.

**Non-blocking:** All implementation work in #060 can proceed against this document's
decisions. The `contribution_ratio` is a config value — changing the default before mainnet
requires only a config file update, not a code change.

---

## 8. Precedent research summary

Five governance systems surveyed as anchor:

| System | Token | Contribution | Notes |
|---|---|---|---|
| Gitcoin | 0% | 100% | Pure contribution |
| Optimism | 50% | 50% | Bicameral — separate houses |
| SCF NQG ★ | 0% | 100% | Stellar-native; reputation neurons align with ForgePass |
| MakerDAO / Compound | 100% | 0% | Pure token |
| Uniswap + delegates | ~85% | ~15% | Token-dominant hybrid |

Industry signal (2024–2025): 73% of contentious DAO votes influenced by top 30% of holders.
Average DAO participation: 17%. Strong shift toward contribution-weighted governance.

---

## 9. Implementation reference

This document is the primary input for:

- **#060** — Implement DAO governance weight endpoint
  - Reads: Section 4 (endpoint contract), Section 3 (query param logic), Section 6 (config file)
- **#030** — Database migrations
  - Reads: Section 5 (integrators table column addition)
- **#061** — Integrator registration flow
  - Reads: Section 3 (contribution_ratio field at registration, bounds validation)
- **#083** — Publish full API documentation
  - Reads: Section 4 (endpoint contract for OpenAPI spec)
- **#084** — DAO governance integration go-live
  - Reads: Entire document — requires OQ-1 resolved via #009 before finalisation

---

*ForgePass · core/api/docs/governance-weight.md · FR-09-A resolved · Issue #006*
