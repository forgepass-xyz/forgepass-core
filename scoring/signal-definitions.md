# ForgePass Trust Score — Signal Definitions v1.0

> This document defines the four confirmed v1 signal types used in the
> ForgePass Trust Score algorithm. It is the authoritative reference for
> raw value definitions, measurement units, and the rationale for each
> signal's inclusion. This file is the input reference for both
> algorithm-v1.0.json and the Trust Score engine (Issue #035).

---

## Signal Type Overview

| Signal | Category | Raw Value Unit | Scored in v1 |
|---|---|---|---|
| GITHUB_PR | Development | Merged PR count + review ratio | Yes |
| SOROBAN_CONTRACT | Development | Deployment count + invocation volume | Yes |
| STELLAR_DEX | Financial activity | Unique qualifying trading pairs | Yes |
| AQUARIUS_LP | Financial activity | Position size × active duration (weeks) | Yes |
| HACKATHON | Participation | Binary event credential | No — see note below |

---

## GITHUB_PR

**Category:** Development

**What it measures:**
Merged pull request activity into registered Stellar ecosystem
repositories for each authenticated contributor.

**Raw value unit:**
Merged PR count (integer), with review ratio stored as a separate
field. Review ratio = reviewed_prs / total_prs (0.0–1.0).

**What a high value means:**
Active, consistent contributor to Stellar open-source repositories.
A contributor with a high PR count and high review ratio is
demonstrably engaged with the ecosystem's builder community,
their work is being reviewed and merged by peers.

**Indexer fields captured (per FR-03.1):**
- pr_count: total merged PRs across registered Stellar repos
- review_count: total code reviews submitted
- reviewed_pr_count: PRs that received at least one peer review
- commit_frequency: commits over trailing 12 months
- repository_diversity: count of distinct repos contributed to
- merge_rate: merged PRs / total PRs submitted

**Design decisions:**
- All merged PRs are counted regardless of size (no trivial PR filter)
- Review count stored as a quality modifier applied at normalisation
- A single merged PR registers with no minimum threshold
- Cross-project indexing: all registered Stellar repos are scanned,
  not only repos the contributor has explicitly linked

---

## SOROBAN_CONTRACT

**Category:** Development

**What it measures:**
Soroban smart contract deployments authored by the contributor's
wallet, weighted by real-world usage via invocation volume.

**Raw value unit:**
Composite: deployment_count × (1 + log(total_invocations + 1)
× invocation_factor). Deployment count is the floor signal.
Invocation volume is a log-scaled multiplier.

**What a high value means:**
Demonstrates smart contract development capability on the Stellar
chain. A contributor with multiple deployed contracts receiving real
invocations has shipped production-grade on-chain code that other
users or contracts depend on.

**Indexer fields captured (per FR-03.3):**
- contract_count: number of distinct contracts deployed
- invocation_volume: cumulative calls received across all contracts
- wasm_size: WASM binary size as a complexity proxy (collected
  but not used in v1 scoring, reserved for future algorithm versions)
- deployment_date: timestamp of each contract deployment

**Design decisions:**
- Deployment count is the floor: zero invocations still scores
- Invocation volume boosts but never zeroes out the deployment score
- Invocation factor set conservatively at 0.3 for v1 given sparse
  invocation data at Soroban ecosystem launch
- No minimum deployment threshold: a single deployed contract
  is a genuine technical achievement at v1 ecosystem scale
- WASM size collected but excluded from v1 scoring: too gameable
  and too opaque to explain in contributor-facing score breakdowns

---

## STELLAR_DEX

**Category:** Financial activity

**What it measures:**
Breadth of engagement with the Stellar DEX, how many distinct
trading pairs a contributor has actively traded, above a minimum
volume threshold.

**Raw value unit:**
Count of unique trading pairs where at least one trade meets the
minimum volume threshold of 10 XLM equivalent.

**What a high value means:**
Active ecosystem participant with economic alignment to the
ecosystem's health. A contributor trading across multiple pairs
has skin in the game, they are financially engaged with the
assets the ecosystem produces. This is explicitly not a builder
signal; it is an ecosystem participation signal.

**Indexer fields captured (per FR-03.2):**
- trade_count: total DEX trades executed
- trade_volume_xlm: total volume in XLM equivalent
- unique_pairs: count of distinct trading pairs traded
- qualifying_pairs: unique pairs where at least one trade
  meets the 10 XLM minimum volume threshold

**Design decisions:**
- Raw value is qualifying_pairs, not total trade count or volume
- Unique pairs chosen over trade count: harder to game, rewards
  breadth of ecosystem engagement over repetitive activity
- Unique pairs chosen over total volume: avoids whale bias and
  privacy concerns around large wallet attribution
- Minimum threshold of 10 XLM per qualifying trade filters dust
  trades, low enough to include genuine small traders, high enough
  to make gaming economically irrational relative to the signal weight
- Intentionally weighted lower than development signals per
  FRD v1.2 design principle

---

## AQUARIUS_LP

**Category:** Financial activity

**What it measures:**
Sustained liquidity provision via Aquarius, capital committed to
trading pair pools over time, measured as the product of position
size and active duration.

**Raw value unit:**
sum(position_size_xlm × duration_weeks) for all positions above
the minimum size threshold of 50 XLM. Duration measured in active
weeks only; weeks the position was open and above the minimum
size threshold.

**What a high value means:**
Sustained ecosystem commitment. A contributor with large, long-held
LP positions has locked real capital in the ecosystem's liquidity
infrastructure over an extended period. This is a deeper commitment
signal than DEX trading, it requires both capital and time, not
just a transaction.

**Indexer fields captured (per FR-03.2):**
- active_positions: count of currently open LP positions
- position_size_xlm: size of each position in XLM equivalent
- position_open_date: timestamp when position was opened
- position_close_date: timestamp when position was closed (null
  if still open)
- cumulative_liquidity_xlm: total liquidity provided over all time

**Design decisions:**
- Raw value is size × duration composite, not position count alone
- Duration measured as active weeks only: positions that drop below
  50 XLM minimum stop accumulating duration score
- Square root normalisation chosen over log scaling for better score
  distribution across small and medium position sizes
- Minimum position size of 50 XLM (vs 10 XLM for DEX trades)
  reflects the higher commitment bar of locked capital vs episodic
  trading
- Treated as a distinct signal from STELLAR_DEX, rewards sustained
  commitment rather than trading breadth
- Weighted equal to DEX at 10%: higher weighting was considered but
  rejected to prevent financial signals from compensating for weak
  development signals in the mid-range score distribution

---

## HACKATHON — Excluded from v1 Scoring

**Category:** Participation event

**Scored in v1:** No.

**Rationale for exclusion:**
Hackathon participation is ingested as a credential per FR-03.7 and
triggers badge minting per FR-05.3, but it is not a scored weight
in v1. Hackathon participation is a binary event signal 'you either
attended or you did not' rather than a continuous contribution signal
that scales meaningfully with effort or quality.

Including it as a scored weight would create perverse incentives
around event farming: attending many hackathons with minimal output
would inflate Trust Scores without reflecting genuine builder
credibility. The badge system is the appropriate reward mechanism
for hackathon participation at v1.

This decision will be revisited when the signal source matures and
when quantitative hackathon outcome data (placement, project quality
scores) becomes available.

---

## Reserved Future Signal Types

The following signal types are planned for future versions pending
partnership confirmation. They are not scored in v1.

| Signal | Status | Dependency |
|---|---|---|
| SCF_GRANT | Roadmap | SCF partnership + ingestion method (Decision #009) |
| GRANTFOX_BOUNTY | Roadmap | GrantFox partnership confirmation (Decision #009) |
| TRUSTLESS_WORK | Roadmap | Trustless Work partnership confirmation (Decision #009) |

---

*v1.0 · github.com/forgepass-xyz · MIT Licensed*
*Based on FRD v1.1 · Issues v1.1 · Issue #001 Roadmap v1.0*
