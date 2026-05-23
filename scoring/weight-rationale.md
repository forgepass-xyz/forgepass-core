# ForgePass Trust Score — Weight Rationale v1.0

> This document explains the reasoning behind every weight value and
> normalisation parameter in algorithm-v1.0.json. It is the public-facing
> explanation of why each weight is what it is and serves as the primary
> reference for the RFC community comment process.

---

## Design Principle

ForgePass is a Builder Passport, not a DeFi participation tracker.
The fundamental constraint on the weight distribution is:

```
w_github_pr + w_soroban_contract > w_stellar_dex + w_aquarius_lp
```

A contributor who merges ten pull requests into Stellar ecosystem
repositories is demonstrably more credible as a builder than one who
executes ten DEX swaps. The weighting encodes that distinction
clearly and publicly.

Final distribution: development signals 80% / financial signals 20%.
Constraint satisfied: 80% > 20% ✓

---

## Precedent Research

Five comparable reputation and credibility systems were surveyed
before proposing the v1.0 weight distribution:

**Gitcoin Passport**
Weights on-chain financial stamps significantly lower than
contribution stamps. Implicit ratio approximately 70% contribution
activity / 30% financial activity. Directly validates the FRD v1.2
design constraint and informed our starting anchor.

**SourceCred (used by MakerDAO)**
Separates quality signals (reviewed/accepted work) from quantity
signals (total output) and weights quality higher. Directly informed
our decision to include review ratio as a quality modifier on the
GITHUB_PR signal rather than counting raw PR volume alone.

**Stack Overflow reputation**
Applies aggressive diminishing returns via log scaling. The gap
between 1 answer and 10 answers is large; the gap between 100 and
110 is negligible. Validated our log scaling approach for GITHUB_PR
and SOROBAN_CONTRACT normalisation.

**Stellar Quest**
Distinguishes development tasks from financial participation tasks
explicitly. Development tasks carry 2-3x the point value of
financial tasks. Strong ecosystem-specific precedent for our
weight ratio.

**DeWork**
Completed bounties weighted lower than code contributions in
contributor rankings even when bounty payout value is high.
Confirmed that financial output should not proxy for builder
credibility.

**Consistent signal across all five systems:**
A roughly 70/30 split between development activity and financial
or participation activity. This became our anchor for the initial
draft weight distribution.

---

## Weight Rationale by Signal

### GITHUB_PR — 50%

**Why 50%:**
GitHub pull request activity is the primary builder signal in the
ForgePass system. It is the signal with the broadest coverage across
the expected v1 contributor base. Most builders will have GitHub
activity even if they have not yet deployed Soroban contracts.

At 50%, GitHub PRs are the dominant factor in the Trust Score.
A contributor with strong GitHub activity will score meaningfully
even with zero financial signals. A contributor with zero GitHub
activity cannot compensate with financial signals alone. The
maximum possible score from non-GitHub signals is 50 points,
and reaching that ceiling requires near-perfect Soroban, DEX,
and LP scores simultaneously.

**Why not higher (e.g. 60%):**
SOROBAN_CONTRACT at 30% needs enough weight to meaningfully
differentiate contributors who have deployed on-chain code from
those who have not. Pushing GITHUB_PR above 50% would compress
the Soroban signal to the point where contract deployment barely
moves the needle. That would misrepresent the depth of technical
contribution that on-chain deployment represents.

**Why not lower (e.g. 40%):**
Initial draft had GITHUB_PR at 45%. Synthetic profile validation
revealed that at 45% a pure DeFi participant scored nearly
identically to a contributor with 5 merged PRs. The adjustment
to 50% restored correct ordering. See adjustment history below.

---

### SOROBAN_CONTRACT -- 30%

**Why 30%:**
Soroban contract deployment is the strongest individual signal of
technical depth in the system. It requires writing, testing, and
deploying actual on-chain code. At 30% it carries enough weight to
meaningfully separate contributors who have shipped on-chain code
from those who have not.

**Why not higher (e.g. 40%):**
Contract deployment is a narrower signal than GitHub activity.
Not every contributor will have deployed Soroban contracts at v1
launch, especially newer ecosystem participants. Pushing the weight
above 30% would create a cliff between contributors with and without
deployments that is too steep relative to the genuine difference in
builder credibility. GitHub contributions at various scales should
still produce a meaningful score.

**Why not lower (e.g. 20%):**
20% would make Soroban deployment feel like a minor bonus rather
than a core credibility signal. A contributor who has shipped
production smart contracts should be clearly differentiated from
one who has not. 30% produces that differentiation without
dominating the score.

---

### STELLAR_DEX -- 10%

**Why 10%:**
DEX activity represents ecosystem skin-in-the-game. It is worth
including because a contributor who actively trades on the Stellar
DEX has a financial stake in the ecosystem's success. But it is
intentionally weighted low because financial participation alone
does not make someone a builder.

At 10%, a contributor who maxes out the DEX signal gains at most
10 points. The cost of gaming the DEX signal (acquiring 10 XLM
minimum per qualifying trade across 10 pairs) exceeds the marginal
score benefit at this weight level.

**Why not higher:**
Increasing DEX weight increases the ability of financially active
but technically inactive participants to inflate their scores.
The builder identity of ForgePass requires that financial signals
remain clearly secondary.

**Why not lower (e.g. 5%):**
At 5% the signal becomes noise. Not worth indexing or explaining
to contributors. 10% keeps it meaningful while maintaining the
correct hierarchy.

---

### AQUARIUS_LP -- 10%

**Why 10%:**
Aquarius LP positions represent a deeper commitment signal than
DEX trading. They require sustained capital allocation over time
rather than episodic transactions. A minimum position size of 50
XLM held for multiple weeks represents genuine ecosystem alignment.

**Why equal to DEX rather than higher:**
Initial draft had AQUARIUS_LP at 15%. Synthetic profile validation
revealed that at 15% the combined financial signal weight (25%)
allowed a pure DeFi participant to score nearly identically to a
genuine new contributor with 5 merged PRs. Reducing AQUARIUS_LP
to 10% restored correct ordering while preserving the commitment
signal's presence in the score.

The argument for weighting LP higher than DEX is acknowledged.
Sustained capital commitment is harder to fake than trading breadth.
However, both remain financial rather than builder signals. Equal
weighting at 10% each reflects that distinction while keeping the
combined financial ceiling at a defensible 20%.

---

## Normalisation Parameter Rationale

### GITHUB_PR cap: 50 merged PRs

50 merged PRs represents genuinely prolific contribution at Stellar
ecosystem scale at v1 launch. Setting the cap at 50 provides good
score discrimination across the 1-30 PR range where most v1
contributors will sit, with saturation only for highly active
contributors. Adjustable in v1.1 if real data shows most contributors
clustering below 20 PRs.

### GITHUB_PR review factor: 0.25

A contributor whose PRs are all reviewed scores up to 25% higher
on the GitHub signal than one whose PRs are all unreviewed. This
rewards quality without penalising solo contributors working on
smaller repos with less review culture. 0.25 was chosen as the
smallest multiplier that produces a visible quality differentiation
in the score breakdown.

### SOROBAN_CONTRACT invocation factor: 0.3

Set conservatively for v1 given sparse invocation data at Soroban
ecosystem launch. A recently deployed contract has had no time to
accumulate call volume, and the ecosystem has not yet reached the
adoption level where invocation counts are reliably discriminating.
At 0.3, invocations provide a meaningful boost without overwhelming
the deployment floor. Target for increase to 0.5 in v1.1 once
ecosystem invocation data matures.

### SOROBAN_CONTRACT normalisation max: 10

A highly active v1 Soroban developer with 5 contracts and moderate
invocation volume produces a raw composite value of approximately
9.0. Normalisation max of 10 maps this to 0.9, close to but not
at the ceiling, preserving discrimination at the top end.

### STELLAR_DEX minimum threshold: 10 XLM

Low enough to include genuine small traders in emerging markets
where 10 XLM represents a real trade. High enough that opening
dozens of fake qualifying pairs costs 100+ XLM, making it
economically irrational relative to the 10% signal weight.

### STELLAR_DEX soft cap: 10 pairs

On the Stellar DEX there are a finite number of meaningful trading
pairs. 10 qualifying pairs represents genuine ecosystem breadth
at v1 launch. Log scaling below 10 provides good discrimination
across the 1-8 pair range where most contributors will sit.
Cap was considered at 15 pairs but reduced to 10 to better reflect
the realistic v1 contributor distribution.

### AQUARIUS_LP minimum position: 50 XLM

Higher than the DEX threshold (10 XLM) to reflect the higher
commitment bar of locked capital versus episodic trading. 50 XLM
locked in an LP position represents genuine economic participation.
Opening dozens of 50 XLM positions to game duration requires
significant capital commitment relative to the 10% signal weight.

### AQUARIUS_LP normalisation max: 30,000

Derived from a realistic highly committed LP contributor profile:
3 active positions averaging 500 XLM each held for 20 weeks gives
a raw value of 30,000. Square root normalisation maps this to 1.0.
A moderately committed contributor (2 x 200 XLM x 10 weeks = 4,000)
normalises to 0.37, meaningfully below the ceiling without being
compressed toward zero.

### AQUARIUS_LP normalisation function: square root

Square root chosen over log scaling after testing revealed log
scaling compressed small LP participants too aggressively toward
zero while being too generous at the low end under other
parameterisations. Square root provides the best distribution
across small (0.12), moderate (0.37), and high (1.0) commitment
levels. This is the one departure from log scaling used elsewhere
in the algorithm. It is documented here to ensure it is not treated
as an inconsistency but as a deliberate parameter choice.

---

## Adjustment History

### Draft v0.1 to Final v1.0

**Initial proposed distribution:**
GITHUB_PR 45% · SOROBAN_CONTRACT 30% · STELLAR_DEX 10% ·
AQUARIUS_LP 15%
Development total: 75% / Financial total: 25%

**Problem identified in synthetic profile validation:**
At 75/25 distribution, the Active DeFi Participant profile scored
24.6, nearly identical to the New Ecosystem Contributor profile
scoring 24.1. A pure DeFi participant with maxed financial signals
scored almost the same as a contributor who had merged 5 real PRs
into Stellar repositories. This directly contradicts ForgePass's
builder identity.

**Root cause:**
AQUARIUS_LP at 15% was too generous. In the mid-to-high range,
strong LP scores compensated for weak development signals to a
degree that undermined the score ordering.

**Adjustment made:**
AQUARIUS_LP reduced from 15% to 10%.
GITHUB_PR increased from 45% to 50%.
Development total: 80% / Financial total: 20%.

**Result after adjustment:**
Active DeFi Participant: 19.6 (down from 24.6)
New Ecosystem Contributor: 26.4 (up from 24.1)
Correct ordering restored. Maximum financial-only score: 20 points.

This adjustment is documented transparently because the RFC process
should show our reasoning, not just our conclusions.

---

## Synthetic Profile Validation

Four archetypal contributor profiles modelled against final v1.0
weights. These profiles are committed as golden file tests in
algorithm-v1.0.json and must be reproduced by the scoring engine
(Issue #035) to within rounding tolerance.

| Profile | Score | Rank |
|---|---|---|
| Senior Stellar Developer | 67.8 | 1st |
| Balanced Ecosystem Participant | 64.7 | 2nd |
| New Ecosystem Contributor | 26.4 | 3rd |
| Active DeFi Participant | 19.6 | 4th |

**Note on Senior Developer vs Balanced Participant gap (3.1 points):**
This gap is intentionally modest and correct. The balanced
participant has strong development signals: 20 PRs and 2 deployed
contracts. The financial signals contribute modestly but do not
distort the ordering. This is the system working as intended and
is not a bug. Community feedback questioning this gap should be
directed to this note.

---

## RFC Summary

*(To be completed after the community comment period closes)*

- RFC published: TBD
- Comment window: TBD to TBD (7 days minimum)
- Total feedback items received: TBD
- Incorporated (values changed): TBD
- Incorporated (rationale clarified): TBD
- Declined with documented reasoning: TBD
- Ratification date: TBD
- Final PR merged by: TBD

---

*v1.0 · github.com/forgepass-xyz · MIT Licensed*
*Based on FRD v1.1 · Issues v1.1 · Issue #001 Roadmap v1.0*
