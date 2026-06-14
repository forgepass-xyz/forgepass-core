# AI Summary Prompt Specification

**Issue:** #007 - Resolve: AI Summary Prompt Fields & Privacy Review
**Phase:** 0 | **Repo:** core/api
**Status:** Complete
**Reviewed by:** [Reviewer 1 - Anthropic API experience] | [Reviewer 2 - Designated privacy reviewer]

---

## 1. Overview

This document specifies the complete data-disclosure boundary for the ForgePass AI-generated contributor summary feature. It defines which passport data fields may be passed to the Anthropic API, how the privacy-safe data fetch layer enforces that boundary at the database layer, what the PromptContext object looks like in every privacy configuration, and the exact system prompt text and output validation rules that govern the model's behaviour.

This document satisfies FRD requirements FR-12-A (AI summary prompt field privacy review), FR-12.1 (opt-in gate), FR-12.2 (Anthropic API integration), FR-12.3 (summary content constraints), FR-02.6 (per-signal privacy controls), FR-02.7 (AI summary opt-in), and NFR 16.4 (privacy). It unblocks Issues #063 (AI summary generation service), #064 (AI summary caching and regeneration), and #065 (AI summary opt-out and deletion).

The Anthropic API is the only point in the ForgePass system where structured internal passport data crosses an external trust boundary to a third-party model outside ForgePass infrastructure. A private signal that enters the prompt context is transmitted to the Anthropic API regardless of whether the model references it in the final output. That transmission cannot be corrected by a cache invalidation or a post-generation hotfix. The privacy filter must operate before the prompt is built, not after.

---

## 2. Field Classification Table

All 42 fields across the five FRD Section 17 data models are classified into one of three buckets.

**Classification definitions:**

| Classification | Definition |
|---|---|
| ALWAYS-INCLUDE | Safe to include regardless of privacy settings. Contains no PII, no financial activity data, and no information whose disclosure could harm the contributor. |
| COND-INCLUDE | May appear in the prompt context only when the corresponding signal type in `privacy_settings` is set to `true`. If the signal type is private, the field is absent from the context object, not null, not zeroed, absent. |
| NEVER-INCLUDE | Must never appear in the Anthropic API prompt under any circumstances. Reasons include: internal system state, authentication data, PII beyond what the contributor explicitly submitted, or fields consumed by the data fetch layer itself. |

**Passport (10 fields):**

| Field | Classification | Reason |
|---|---|---|
| wallet_address | NEVER-INCLUDE | The model does not need the wallet address to produce a meaningful summary. `github_username` serves as the identity anchor. The full public key is unnecessary and constitutes gratuitous PII exposure to a third-party API. |
| github_username | ALWAYS-INCLUDE | Explicitly linked by the contributor as their public GitHub identity. Safe, meaningful, and the natural subject anchor for a professional contribution summary. |
| created_at | ALWAYS-INCLUDE | Passed as a derived value (`ecosystem_tenure_days`) rather than the raw timestamp. Non-sensitive; communicates ecosystem longevity, which provides meaningful contribution context. |
| algorithm_version | NEVER-INCLUDE | Internal system versioning reference. No value to a summary reader and reveals internal system state to a third-party model. |
| trust_score | ALWAYS-INCLUDE | The core public quantitative output of the system. Always visible on public profiles; its inclusion is expected and meaningful in any summary. |
| ipfs_metadata_cid | NEVER-INCLUDE | Internal content-addressed storage reference. No narrative value in a readable summary. |
| sybil_flag | NEVER-INCLUDE | Internal moderation state flag. Must never be disclosed to any external system under any circumstances. |
| privacy_settings | NEVER-INCLUDE | Consumed entirely by the data fetch layer to filter the prompt context. It governs which other fields are included; it is never itself included in the context it governs. |
| ai_summary_opt_in | NEVER-INCLUDE | Internal gate flag used to authorise generation before the data fetch runs. Not a content field. |
| ai_summary_cache | NEVER-INCLUDE | A previously generated summary. Including it would create circular inputs and may amplify errors from prior generation runs into the new summary. |

**Credential (10 fields):**

| Field | Classification | Reason |
|---|---|---|
| id (UUID) | NEVER-INCLUDE | Internal primary key. No reader value. |
| wallet_address | NEVER-INCLUDE | Redundant when the Passport model already identifies the contributor. Adding it increases surface area without clarity benefit. |
| signal_type | COND-INCLUDE | Appears only in aggregated form (e.g. total merged PRs) and only when that signal type is marked public in `privacy_settings`. Entirely absent from the context when private. |
| source_id | NEVER-INCLUDE | Raw external reference (GitHub PR number, contract address, transaction hash). Too granular, potentially identifying, and has no narrative value in a professional summary. |
| source_platform | COND-INCLUDE | Platform name (e.g. "GitHub", "Stellar network") is narratively useful. Excluded when the parent signal type is private. |
| event_date | COND-INCLUDE | Included only at the date-range level (earliest and latest across all credentials of a given signal type), not per-credential. Excluded when the parent signal type is private. |
| ingested_at | NEVER-INCLUDE | Internal system timestamp marking when ForgePass recorded the signal. No contributor value. |
| data_hash | NEVER-INCLUDE | Internal cryptographic artefact. Reveals internal data structure without providing any summary value. |
| on_chain_tx | NEVER-INCLUDE | Stellar transaction ID. Internal system reference not needed in a summary context. |
| is_private | NEVER-INCLUDE | Derived field consumed by the SQL WHERE clause that governs conditional inclusion. Never passed through to the prompt context. |

**TrustScoreSnapshot (8 fields):**

| Field | Classification | Reason |
|---|---|---|
| id | NEVER-INCLUDE | Internal primary key. |
| wallet_address | NEVER-INCLUDE | Redundant. |
| score | ALWAYS-INCLUDE | The most recent snapshot score matches the Passport `trust_score` field; always public. |
| algorithm_version | NEVER-INCLUDE | Internal versioning reference. No summary reader value and reveals system internals. |
| computed_at | ALWAYS-INCLUDE | Date of the most recent score computation. Communicates data currency: a score from 18 months ago carries different context than one computed last week. |
| signal_hash | NEVER-INCLUDE | Internal hash of the input signal set. Cryptographic artefact with no narrative value. |
| breakdown | COND-INCLUDE | Per-signal contribution percentages. Included only when ALL four signal types are public in `privacy_settings`. Absent entirely when any signal type is private (see Decision: score_breakdown omission policy). |
| on_chain_tx | NEVER-INCLUDE | Internal transaction reference. |

**Badge (7 fields):**

| Field | Classification | Reason |
|---|---|---|
| id | NEVER-INCLUDE | Internal primary key. |
| wallet_address | NEVER-INCLUDE | Redundant. |
| milestone_type | ALWAYS-INCLUDE | Badge types are always public per FR-05.5. Their existence is not a privacy-sensitive disclosure under any privacy settings combination. |
| minted_at | ALWAYS-INCLUDE | The date a badge was earned is non-sensitive and communicates meaningful milestone history in the summary. |
| nft_address | NEVER-INCLUDE | Technical Stellar NFT address. Internal system reference with no narrative value. |
| ipfs_metadata_cid | NEVER-INCLUDE | Internal content-addressed storage reference. |
| on_chain_tx | NEVER-INCLUDE | Internal transaction reference. |

**ContributorEdge (7 fields):**

| Field | Classification | Reason |
|---|---|---|
| id | NEVER-INCLUDE | Internal primary key. |
| from_address | NEVER-INCLUDE | Third-party wallet address. PII for the collaborator, disclosed without their consent. |
| to_address | NEVER-INCLUDE | Third-party wallet address. Same reasoning as `from_address`. |
| collaboration_type | COND-INCLUDE | Collaboration type (e.g. co-authored PRs) is narratively useful but excluded when the source credential signal type is private. Included only as an aggregated count, not per-collaborator detail. |
| project_name | NEVER-INCLUDE | Individual repository names from collaboration edges may reveal information about collaborators who have not opted into AI summaries. Repository context from the contributor's own credentials is sufficient. |
| first_collaborated | NEVER-INCLUDE | The specific date of first collaboration is too granular and may reveal information about collaborators. Aggregated counts are sufficient context. |
| edge_weight | NEVER-INCLUDE | Numerical collaboration frequency metric. Too granular for a summary and may reveal activity patterns beyond what credential counts communicate. |

**Decisions recorded against this table:**

- `score_breakdown` (TrustScoreSnapshot.breakdown): full omission when any signal type is private. The SQL WHERE clause enforces this: all four `privacy_settings` keys must be `true` or the query returns zero rows and the `score_breakdown` key is absent from PromptContext. Partial percentages that do not sum to 100 would allow a reader to infer the existence of private signals. Re-normalised percentages would misrepresent the contributor's actual score composition. Full omission is the only clean guarantee.
- Absent sections use silent omission throughout. No absence markers, no null values, no empty objects. A key that is absent from the context cannot leak the existence of a private signal to the model or to the Anthropic API.
- When all signal types are private, the service generates a minimal summary from contributor metadata and badges. It does not skip generation or return a placeholder. A contributor who opted in made an active choice to have a summary displayed; skipping contradicts that choice without warning.

---

## 3. Data Fetch Layer Specification

### Function interface

`AiSummaryDataService.fetchPromptContext` is the sole gateway between the database and the prompt builder. The prompt builder receives a `PromptContext` object and may trust every field present in it. It performs no additional filtering.

```typescript
interface PromptContext {
  contributor: {
    github_username: string | null;
    ecosystem_tenure_days: number;       // derived from passport.created_at
    trust_score: number;                 // 0-100
    score_computed_at: string;           // ISO 8601
  };
  credentials?: {                        // absent when all signal types are private
    github_prs?: {                       // absent when privacy_settings.github = false
      total_merged: number;
      repository_count: number;
      date_range: { earliest: string; latest: string };
    };
    soroban_contracts?: {                // absent when privacy_settings.soroban = false
      total_deployed: number;
      total_invocations: number;
      date_range: { earliest: string; latest: string };
    };
    stellar_dex?: {                      // absent when privacy_settings.dex = false
      total_trades: number;
      date_range: { earliest: string; latest: string };
    };
    hackathons?: {                       // absent when privacy_settings.hackathon = false
      total_participated: number;
      events: string[];                  // event name only, no dates or identifiers
    };
  };
  badges: Array<{                        // always present, may be empty array
    milestone_type: string;
    minted_at: string;                   // ISO 8601
  }>;
  collaborations?: {                     // absent when all signal types are private
    co_pr_count?: number;                // absent when privacy_settings.github = false
    co_contract_count?: number;          // absent when privacy_settings.soroban = false
  };
  score_breakdown?: {                    // absent when ANY signal type is private
    github_pct: number;
    soroban_pct: number;
    dex_pct: number;
    hackathon_pct: number;
  };
}

class OptInRequiredError extends Error {}

async function fetchPromptContext(walletAddress: string): Promise<PromptContext>
```

**Contract:**
- Throws `OptInRequiredError` before any database read if `ai_summary_opt_in = false`.
- All five queries execute inside a single database transaction.
- Returns a typed `PromptContext` containing only ALWAYS-INCLUDE and COND-INCLUDE fields that passed the runtime privacy check.
- Never returns a NEVER-INCLUDE field at any nesting level.

### SQL privacy filter patterns

**Credentials (privacy filter at WHERE clause level):**

```sql
SELECT
  c.signal_type,
  c.source_platform,
  MIN(c.event_date) AS earliest,
  MAX(c.event_date) AS latest,
  COUNT(*)          AS total
FROM credentials c
JOIN passports p ON p.wallet_address = c.wallet_address
WHERE c.wallet_address = $1
  AND (
    (c.signal_type = 'GITHUB_PR'
      AND (p.privacy_settings->>'github')::boolean   = true)
    OR (c.signal_type = 'SOROBAN_CONTRACT'
      AND (p.privacy_settings->>'soroban')::boolean  = true)
    OR (c.signal_type = 'STELLAR_DEX'
      AND (p.privacy_settings->>'dex')::boolean      = true)
    OR (c.signal_type = 'HACKATHON'
      AND (p.privacy_settings->>'hackathon')::boolean = true)
  )
GROUP BY c.signal_type, c.source_platform;
```

**Score breakdown (Option B: all four keys must be true or zero rows returned):**

```sql
SELECT tss.breakdown
FROM trust_score_snapshots tss
JOIN passports p ON p.wallet_address = tss.wallet_address
WHERE tss.wallet_address = $1
  AND (p.privacy_settings->>'github')::boolean   = true
  AND (p.privacy_settings->>'soroban')::boolean  = true
  AND (p.privacy_settings->>'dex')::boolean      = true
  AND (p.privacy_settings->>'hackathon')::boolean = true
ORDER BY tss.computed_at DESC
LIMIT 1;
```

**Contributor edges (filtered by source signal type privacy):**

```sql
SELECT
  ce.collaboration_type,
  COUNT(*) AS count
FROM contributor_edges ce
JOIN passports p ON p.wallet_address = $1
WHERE ce.from_address = $1
  AND (
    (ce.collaboration_type = 'CO_PR'
      AND (p.privacy_settings->>'github')::boolean   = true)
    OR (ce.collaboration_type = 'CO_CONTRACT'
      AND (p.privacy_settings->>'soroban')::boolean  = true)
  )
GROUP BY ce.collaboration_type;
```

**Badges (no privacy filter, ALWAYS-INCLUDE per FR-05.5):**

```sql
SELECT milestone_type, minted_at
FROM badges
WHERE wallet_address = $1
ORDER BY minted_at DESC
LIMIT 10;
```

**Passport contributor metadata (ALWAYS-INCLUDE fields only):**

```sql
SELECT
  github_username,
  EXTRACT(DAY FROM NOW() - created_at)::integer AS ecosystem_tenure_days,
  trust_score,
  ai_summary_opt_in
FROM passports
WHERE wallet_address = $1;
```

### Edge case handling

| Scenario | fetchPromptContext returns | Prompt builder behaviour |
|---|---|---|
| All signal types private | `contributor` + `badges` array only. `credentials`, `collaborations`, and `score_breakdown` are all absent. | Generates a minimal summary noting ecosystem tenure, Trust Score as a computed metric, and any earned badges. No contribution activity described. |
| Zero credentials (new passport) | `contributor` with `trust_score = 0` + empty `badges` array. `credentials`, `collaborations`, and `score_breakdown` are all absent. | Generates a summary noting the contributor recently joined the Stellar ecosystem. No contribution claims made. |
| Partial signals private | `contributor` + public-signal credential sections + full `badges` + public-signal collaborations. `score_breakdown` absent because any private signal triggers full omission. | Generates a summary covering public signals only. Does not reference or acknowledge absent signal types. |

---

## 4. PromptContext Schema Reference

### Annotated schema

See `config/ai-summary-prompt-context-schema.json` for the machine-readable version. The JSON below shows all sections with inline annotation comments.

```json
{
  "contributor": {
    "github_username": "string | null",
    "ecosystem_tenure_days": "number",
    "trust_score": "number (0-100)",
    "score_computed_at": "ISO 8601 date string"
  },
  "credentials": {
    "github_prs": {
      "total_merged": "number",
      "repository_count": "number",
      "date_range": {
        "earliest": "ISO 8601 date string",
        "latest": "ISO 8601 date string"
      }
    },
    "soroban_contracts": {
      "total_deployed": "number",
      "total_invocations": "number",
      "date_range": { "earliest": "...", "latest": "..." }
    },
    "stellar_dex": {
      "total_trades": "number",
      "date_range": { "earliest": "...", "latest": "..." }
    },
    "hackathons": {
      "total_participated": "number",
      "events": ["string -- event name only, no wallet addresses or identifiers"]
    }
  },
  "badges": [
    {
      "milestone_type": "string (e.g. FIRST_PR, FIRST_CONTRACT)",
      "minted_at": "ISO 8601 date string"
    }
  ],
  "collaborations": {
    "co_pr_count": "number",
    "co_contract_count": "number"
  },
  "score_breakdown": {
    "github_pct": "number",
    "soroban_pct": "number",
    "dex_pct": "number",
    "hackathon_pct": "number"
  }
}
```

**Absence rules summary:**

| Key | Absent when |
|---|---|
| `credentials` | All four signal types are private |
| `credentials.github_prs` | `privacy_settings.github = false` |
| `credentials.soroban_contracts` | `privacy_settings.soroban = false` |
| `credentials.stellar_dex` | `privacy_settings.dex = false` |
| `credentials.hackathons` | `privacy_settings.hackathon = false` |
| `collaborations` | All four signal types are private |
| `collaborations.co_pr_count` | `privacy_settings.github = false` |
| `collaborations.co_contract_count` | `privacy_settings.soroban = false` |
| `score_breakdown` | ANY signal type is private |
| `badges` | Never absent (always an array, may be empty) |

**Absent means the key is not present in the object. Not null. Not `{}`. Not `[]`. The key does not exist.**

### Token budget

| Section | Approx. tokens | Notes |
|---|---|---|
| System prompt | ~320 | Fixed cost per generation |
| Contributor metadata | ~40 | Four fields, stable size |
| Credentials (all 4 public) | ~150 | Maximum size for credentials section |
| Credentials (all private) | ~0 | Section absent |
| Badges (up to 10) | ~80 | Capped at 10 most recent badges |
| Collaborations | ~20 | Two numeric fields |
| Score breakdown (all public) | ~30 | Four percentage values |
| Instruction suffix | ~25 | Fixed close |
| **Total: all signals public** | **~665** | Well within claude-sonnet-4-6 context window |
| **Total: all signals private** | **~385** | Contributor metadata and badges only |
| Expected output (150-250 words) | ~200-350 | Bounded by system prompt word count rule |
| **Round-trip ceiling** | **~1,015** | Comfortable. Monitor via Anthropic usage dashboard post-launch. |

Badge cap: 10 most recent badges. Sufficient for the Phase 1 milestone set (FIRST_PR, FIRST_CONTRACT, HACKATHON_PARTICIPANT, compound milestones from #008). Review cap in a future phase if the milestone set expands significantly.

### Edge case PromptContext shapes

**Edge case 1: all signal types private**

```json
{
  "contributor": {
    "github_username": "octocat",
    "ecosystem_tenure_days": 280,
    "trust_score": 42,
    "score_computed_at": "2026-05-15T10:00:00Z"
  },
  "badges": [
    { "milestone_type": "FIRST_PR", "minted_at": "2025-10-01T00:00:00Z" }
  ]
}
```

**Edge case 2: zero credentials (new passport)**

```json
{
  "contributor": {
    "github_username": "newbuilder",
    "ecosystem_tenure_days": 4,
    "trust_score": 0,
    "score_computed_at": "2026-06-10T08:00:00Z"
  },
  "badges": []
}
```

**Edge case 3: partial signals private (github public, dex private)**

```json
{
  "contributor": {
    "github_username": "partialbuilder",
    "ecosystem_tenure_days": 190,
    "trust_score": 55,
    "score_computed_at": "2026-05-20T14:30:00Z"
  },
  "credentials": {
    "github_prs": {
      "total_merged": 18,
      "repository_count": 4,
      "date_range": {
        "earliest": "2025-09-01T00:00:00Z",
        "latest": "2026-05-18T00:00:00Z"
      }
    }
  },
  "badges": [
    { "milestone_type": "FIRST_PR", "minted_at": "2025-09-03T00:00:00Z" },
    { "milestone_type": "MULTI_REPO_CONTRIBUTOR", "minted_at": "2026-01-12T00:00:00Z" }
  ],
  "collaborations": {
    "co_pr_count": 7
  }
}
```

`score_breakdown` is absent because DEX is private. `soroban_contracts`, `stellar_dex`, and `hackathons` are absent from `credentials`. `co_contract_count` is absent from `collaborations`.

---

## 5. System Prompt Template

The following text is reproduced verbatim as it will be passed to the Anthropic API. It must not be paraphrased or described by reference in any implementation. The exact text is the specification.

```
You are generating a professional third-person summary of a Stellar
ecosystem contributor's verified on-chain and open-source contribution
history for display on their public ForgePass Builder Passport profile.

Rules you must follow without exception:

1. Write only about contributions that are present in the structured
   data provided below. Do not infer, speculate, or add context not
   present in the data.

2. Write in third person. Do not use "I", "you", or "we".

3. The summary must be between 150 and 250 words. Do not exceed 250
   words. Do not write fewer than 150 words.

4. Do not make claims about skills, expertise, or personal qualities.
   Describe only verifiable contribution events shown in the data.

5. Do not mention wallet addresses, transaction hashes, contract
   addresses, or any blockchain identifiers in the summary text.

6. If a Trust Score is present in the data, describe it as a computed
   contribution metric, not a grade, ranking, or personal judgment.

7. If the structured data contains no credential information (because
   all signals are private or no contributions have been indexed yet),
   produce a minimal summary noting that the contributor holds an
   active Builder Passport on the Stellar network and stating their
   ecosystem tenure. Do not fabricate contribution claims.

8. Do not describe the absence of data. If a signal type is not
   present in the context, do not mention that it is missing or that
   the contributor has no recorded activity in that area.

9. End the summary by referencing the contributor's GitHub username,
   if one is provided in the structured data.

The summary will appear publicly on the contributor's profile page.
It must be accurate, professional, and derived exclusively from the
structured data provided below.
```

**Rule consistency notes:**

- Rules 7 and 8 are non-contradictory. Rule 7 covers the case where no credential data exists at all: the model describes what it has (tenure, passport, badges). Rule 8 covers the case where some signal types are absent because they are private: the model does not acknowledge their absence.
- Rule 9 uses "if one is provided" to handle the edge case where `github_username` is null in the contributor metadata.
- The GitHub username appears only in the JSON context, not in the instruction text. The instruction layer contains no string interpolation and no template variables.

---

## 6. Output Validation Rules

All validation is applied to the raw model output before it is stored in `passports.ai_summary_cache`. A summary that fails validation and is not recovered by one retry is never served via any API response.

| Rule | Parameters | Failure behaviour |
|---|---|---|
| Word count check | 150 words minimum, 250 words maximum. Space-delimited tokens. Hyphenated terms count as one word. Numbers count as one word. | Retry once with the original prompt plus appended instruction: "Your previous response was [N] words. The required range is 150-250 words. Please rewrite within that range." If the second attempt also fails: store with `validation_failed: true`, raise admin alert, do not serve via any API response. |
| Content safety check | Regex applied to raw output: Stellar address format `G[0-9A-Z]{55}`, hex transaction hash `[0-9a-fA-F]{64}`, and Soroban contract address patterns. | On detection: discard and retry once with no instruction change. If the second attempt also triggers: discard, log full raw response (redacted for privacy review), store error state, raise admin alert. |
| Maximum retries | 1 retry attempt per generation cycle across all failure types combined. | After one retry that also fails any check: escalate to admin alert, log failure reason, return no summary for this generation cycle. The next scheduled regeneration trigger attempts a fresh generation. |
| Opt-in gate check | `ai_summary_opt_in` must equal `true` in the passports table before `AiSummaryService.generateSummary` is called. | If called without confirmed opt-in: throw `OptInRequiredError` before any data fetch begins. No database read. No Anthropic API call. No tokens consumed. |

**Regex pattern notes:**

- Stellar public key: `G[0-9A-Z]{55}` matches the 56-character format (G followed by 55 uppercase alphanumeric characters). No realistic false positives in standard English prose.
- Hex hash: `[0-9a-fA-F]{64}` matches 64 consecutive hex characters. Extremely unlikely in natural language output.
- Word count computation: consistent between system prompt Rule 3 and validation code. Space-delimited, hyphens treated as word-internal, numerals count as one word.

---

## 7. Open Questions at Close

| Question | Resolution |
|---|---|
| Should GitHub username appear in the instruction text or only in the JSON context? | Resolved: JSON context only. Instruction layer is fully static with no interpolation. Rule 9 handles the closing reference from context. |
| When all signal types are private, generate a minimal summary or return a placeholder? | Resolved: generate a minimal summary (Option A). Skipping generation contradicts the contributor's opt-in decision. Rule 7 handles model behaviour. |
| Does the score_breakdown create an indirect privacy leak when some signals are private? | Resolved: full omission when any signal type is private (Option B). Partial percentages or re-normalised values both leak information about private signals. |
| Should the prompt context explicitly note absent signals or omit silently? | Resolved: silent omission. The system prompt governs model behaviour via Rule 8. Absence markers in the context would confirm signal type existence to the Anthropic API without a corresponding benefit. |
| Does this issue require formal legal or privacy counsel review before merge? | Deferred: the PR proceeds with the standard two-reviewer engineering sign-off (Anthropic API experience + designated privacy reviewer). A formal legal and privacy counsel review covering data disclosure obligations (GDPR, NDPR, and equivalent) is deferred to a future phase when resources allow. This deferral is documented here as an open risk. |

---

*v1.0 - 2026-06-13 - github.com/forgepass-xyz - MIT Licensed*
