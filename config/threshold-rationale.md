# ForgePass Sybil Resistance Thresholds — Rationale v1.0

> This document explains the reasoning behind every threshold value and
> design decision in sybil-thresholds.json. It is the internal record
> of how values were arrived at and serves as the primary reference for
> any future team member unfamiliar with the original decision process.
> It is also the reference document for the dispute and appeal pathway
> when contributors challenge a gate rejection.

---

## Purpose of the Sybil Resistance Gates

The three onboarding gates exist for a single reason: a ForgePass
Builder Passport is a permanent, non-revocable on-chain record. Once
created, it cannot be deleted. A sybil account that successfully
creates a passport pollutes the registry permanently and undermines
the credibility of every legitimate passport in the system.

The gates are not designed to be an elite filter. They are designed
to make bulk account creation expensive enough in time, capital, and
effort that it becomes irrational relative to any conceivable benefit.
A genuine developer who is new to Stellar and new to open source
should be able to qualify within a reasonable period. The gates should
never feel like an impossible bar to a real human being.

The two failure modes we explicitly designed against:

**Too loose:** Thresholds set too low allow sybil farms to create large
numbers of qualifying accounts cheaply. The Trust Score distribution
becomes meaningless. Every legitimate passport loses credibility
because the registry is full of fake ones.

**Too strict:** Thresholds set too high exclude legitimate new
contributors. A developer who just discovered Stellar and wants to
build should not be permanently blocked because they have not yet
accumulated years of ecosystem history.

Every threshold in sybil-thresholds.json sits between these two
failure modes, deliberately.

---

## Why These Thresholds Are Not Publicly Documented

The existence of the gates and the general criteria (account age,
balance, GitHub activity) are documented publicly in the ForgePass
onboarding flow. The specific numeric values are not published in
any user-facing documentation beyond what appears in rejection
messages.

This is a deliberate security design choice. Publishing exact threshold
values gives adversarial actors the precise targets they need to
calibrate bulk account creation. A sybil operator who knows the exact
minimum XLM average and the exact minimum GitHub account age can
engineer accounts that pass all three gates at minimum cost.

The rejection messages tell contributors exactly what they need to do
to qualify. That is sufficient for a legitimate contributor. It is
not sufficient for a sybil operator to reverse-engineer a bulk farming
strategy, because the messages reveal only the contributor's own
current values, not the system-wide thresholds.

This decision was made deliberately and is documented here so future
team members understand it is a security choice, not an oversight.

---

## Gate Design Decisions

### Why Three Gates

Three gates were chosen because each measures a fundamentally different
dimension of identity and commitment:

Gate 1 measures time commitment to the Stellar network.
Gate 2 measures financial commitment to the Stellar network.
Gate 3 measures builder identity and GitHub presence.

No single gate is sufficient on its own. A financially active wallet
with no GitHub presence should not get a Builder Passport. A strong
GitHub developer with a brand new Stellar wallet should wait until
their wallet has aged. The three gates together create a composite
picture that is much harder to fake than any single signal.

### Why Gates Run in Sequence

Gates run in strict sequence and halt on the first failure. This is
deliberate for two reasons.

First, it minimises unnecessary external API calls. If a wallet fails
Gate 1 on account age, there is no point querying Horizon for balance
history or GitHub for activity. The contributor cannot proceed
regardless of what those checks return.

Second, it produces cleaner rejection messages. A contributor who
fails Gate 1 gets one specific message about one specific thing they
need to fix. A system that runs all gates in parallel and returns
multiple failures at once is harder to act on.

### Gate Execution Order Rationale

Gate 1 and Gate 2 both use the same Horizon API call and are evaluated
together. Gate 3 requires a separate GitHub API call and runs after
the Stellar checks pass. Gate 4 is a local database check and runs
last because it is the cheapest operation and is only meaningful once
identity and activity are confirmed.

---

## Gate 1: Stellar Account Age — 60 Days

### What it measures

The number of days elapsed since the contributor's Stellar wallet was
activated on the network. Sourced from the `created_at` field in the
Horizon accounts endpoint.

### Why 60 days

The precedent range across comparable Stellar ecosystem projects for
wallet age requirements is 30 to 90 days. We evaluated all three
anchor points before settling on 60.

**30 days** is one monthly cycle. Any organised sybil operation running
on a monthly cadence absorbs this trivially. Accounts are created one
month in advance and the threshold is planned around with minimal
effort. 30 days filters purely opportunistic attacks but not organised
ones.

**90 days** starts to risk excluding genuine new contributors who
discovered Stellar recently and want to get involved quickly. The
Stellar ecosystem is still growing and we do not want to create a 3-
month waiting period for developers who are genuinely new to the chain.

**60 days** is two monthly cycles. It meaningfully deters opportunistic
and lightly organised sybil attempts without creating a painful waiting
period for legitimate contributors. A developer who discovers Stellar
today and wants a ForgePass passport needs to wait two months. That
is a reasonable ask and not a significant barrier.

Critically, the account age gate does not work in isolation. A 60-day-
old wallet that has also maintained a 10 XLM rolling average and has
a real GitHub presence is a much stronger signal than account age
alone. The three gates together produce resistance that is greater than
the sum of their parts.

### Why not higher or lower

Lower than 60 days makes the gate too easy to plan around for organised
sybil operations. Higher than 60 days risks excluding too many genuine
new contributors for a period that does not meaningfully increase
resistance beyond what 60 days already provides.

### Borderline cases

The legitimate new developer profile in the synthetic validation has a
wallet that is 45 to 90 days old. Wallets at the lower end of this
range (45 to 59 days) will fail Gate 1 and be asked to wait. This is
an acceptable outcome. The rejection message tells them exactly how
many days remain. They are not excluded permanently, they are asked
to wait briefly. This is the gate working correctly.

---

## Gate 2: Minimum XLM Balance — 10 XLM 30-Day Rolling Average

### What it measures

The average native XLM balance in the contributor's Stellar wallet over
the preceding 30 days. Reconstructed from the Horizon effects history
rather than read as a point-in-time snapshot.

### Why a rolling average rather than point-in-time

A point-in-time balance check reads the wallet balance at the exact
moment of onboarding. The weakness is obvious: a contributor could
temporarily fund their wallet with the minimum required balance, pass
the gate, and drain the wallet immediately afterward. This costs
nothing beyond the brief capital commitment.

A 30-day rolling average requires sustained balance maintenance. A
contributor who funded their wallet yesterday and drained it for the
preceding 29 days will not pass. The average has to hold across the
entire window. This makes temporary funding attacks irrational because
the contributor would need to maintain the balance for 30 days, which
is the same cost as being a legitimate wallet holder for that period.

### Why 10 XLM

The 10 XLM threshold was chosen for three reasons.

First, consistency with the Trust Score algorithm. The DEX signal
minimum trade threshold established in signal-definitions.md is 10 XLM
per qualifying trade. The onboarding balance gate aligning with this
value is internally consistent and explainable. It would be strange to
require a 20 XLM average balance for onboarding when the DEX signal
only requires 10 XLM per qualifying trade.

Second, the farm cost calculation. Creating 1000 fake accounts that
each maintain a 10 XLM rolling average requires committing 10,000 XLM
in sustained average balance across those accounts for 30 days. That
is a real and meaningful capital cost relative to any conceivable
benefit from inflating the passport registry. The attack becomes
economically irrational.

Third, accessibility. 10 XLM is well above the Stellar base reserve
(currently 1 XLM per account) but is accessible to any genuine
developer regardless of economic background. We explicitly did not
want this gate to function as a wealth filter. It should be a cost
multiplier for farms, not a barrier for individuals.

### Why the Stellar base reserve is not sufficient

The Stellar base reserve (currently 1 XLM) is the absolute minimum to
keep an account open. A threshold at or near the base reserve provides
essentially no resistance. Any account that exists at all meets a 1 XLM
bar. The threshold must be meaningfully above the base reserve to
create any cost-of-entry signal.

### Re-verification

The XLM balance gate is the only gate with a live re-verification
condition. Stellar account age and GitHub activity can only increase
after passport creation and cannot fall below their thresholds. The
XLM balance can drop at any time.

If the 30-day rolling average drops below 10 XLM after passport
creation, the passport is flagged per FR-01.8 and the contributor is
notified. The flag does not revoke the passport. Passport revocation
is not permitted under FR-02.3 and the non-revocability guarantee is
not affected by re-verification.

---

## Gate 3: GitHub Activity — 180 Days Account Age, 1 Public Repo or 1 Merged Stellar PR

### What it measures

Two things in sequence. First, whether the contributor's GitHub account
is at least 180 days old. Second, whether the contributor has at least
one public repository or one merged pull request into a registered
Stellar ecosystem repository.

### Why AND logic between age and activity

AND logic means a contributor must pass both the age check and the
activity check. OR logic would mean either one is sufficient.

The case against OR logic is clear. A very old GitHub account with
zero activity could pass on age alone under OR logic. That lets in
the active DeFi-only wallet profile: someone who created a GitHub
account years ago, never used it, but has a strong Stellar financial
presence. That profile should not receive a Builder Passport. AND
logic closes that path.

### Why 180 days for GitHub account age

GitHub account age is a weaker signal than Stellar wallet age. A
Stellar wallet requires active decision-making to maintain: it must
be funded, used, and kept alive. A GitHub account can sit dormant
indefinitely without any cost to the owner. Age alone on GitHub
proves less than age on Stellar.

This weakness is an argument for a higher age threshold, not lower.
At 180 days, a sybil operator would need to create GitHub accounts
6 months in advance. Combined with the AND logic requiring activity
to also pass, this creates a meaningful combined barrier.

Gitcoin Passport uses 90 days for their GitHub stamp as a reference
point. ForgePass uses 180 days because our gate is a hard filter
with no composite fallback. Gitcoin's stamp system is additive: a
low-quality GitHub stamp is offset by other stamps. ForgePass gates
are binary: fail and you cannot proceed. A harder gate is warranted.

180 days is not an unreasonable bar for a genuine developer. Anyone
who has been coding publicly on GitHub for 6 months has a real
presence. New developers who just created their GitHub account will
need to wait, but they will not wait forever.

### Why 1 public repo as the minimum

The public repo minimum is deliberately low because the Stellar
contribution alternative path is the preferred qualifying route and
the age gate is doing the primary filtering on the default path.

A single public repository on a 180-day-old GitHub account is a
credible signal of a real developer. It requires at least one
deliberate act of public creation. Combined with 180 days of account
age, this is not a profile that a sybil farm produces cheaply.

### Why a merged Stellar PR is a valid alternative path

A contributor who works primarily by contributing to others'
repositories rather than maintaining their own should not be excluded.
Some of the strongest open source developers have few or zero public
repos of their own but have contributed meaningfully to major projects.

A merged pull request into a registered Stellar ecosystem repository
is a peer-reviewed contribution. It is harder to fake than creating
a public repository. It requires submitting work that was reviewed
and accepted by the maintainers of a real Stellar project. If someone
has already contributed to the ecosystem we are building for, the
gate has done its job.

The Stellar contribution check uses `github_user_id` not
`github_username` for the uniqueness check, because GitHub usernames
can be changed while user IDs cannot. This prevents username change
attacks that could otherwise circumvent Gate 4.

### Why the activity check has a dispute pathway

The GitHub API occasionally returns stale or incorrect data,
particularly for public repo counts on accounts that have recently
created or deleted repositories. A contributor who genuinely has a
public repo or a merged Stellar PR but fails the activity check due
to a data issue has a legitimate basis for admin review. The
ONBOARDING_GATE_REJECTION dispute type exists for this reason.

Age-based failures (both Stellar account age and GitHub account age)
do not have a dispute pathway because they are deterministic checks
with no data ambiguity. The contributor simply needs to wait.

---

## Gate 4: Duplicate Identity

### What it measures

Whether the contributor's GitHub account is already linked to a
different Stellar wallet, or whether their Stellar wallet is already
linked to a different GitHub account.

### Why this gate exists

Without a duplicate identity check, a contributor could link the same
GitHub account to multiple Stellar wallets, creating multiple passports
from a single real identity. This undermines the one-person-one-
passport guarantee that ForgePass's credibility depends on.

### Why it uses github_user_id not github_username

GitHub usernames can be changed by the account owner at any time. A
contributor could link their GitHub account to one wallet, change
their username, and then attempt to link the same account to a second
wallet. Using the immutable `github_user_id` integer closes this
attack vector.

### Why it has a dispute pathway

Two legitimate scenarios exist where a contributor may hit this gate
incorrectly. First, a contributor who has multiple Stellar wallets
may have linked their GitHub account to the wrong one and needs to
transfer their passport identity to a different wallet. Second, a
contributor's GitHub account may have been compromised and linked to
an unknown wallet without their knowledge. Both scenarios warrant
admin review and cannot be self-resolved by the contributor.

---

## Synthetic Profile Validation

Four archetypal contributor profiles were modelled against the final
threshold values to confirm correct pass/fail outcomes before
ratification. These profiles are documented in sybil-thresholds.json
and summarised here.

### Profile 1: Legitimate New Developer

**Description:** Genuine contributor new to Stellar but active on
GitHub. Stellar wallet 45 to 90 days old. XLM average 10 to 30.
GitHub account 1 to 2 years old. 3 to 5 public repos.

**Expected outcome:** PASS all three gates.

**Actual outcome:** CONDITIONAL PASS. Wallets at 60 days or older pass
Gate 1. Wallets at 45 to 59 days are asked to wait, which is an
acceptable outcome. Gates 2 and 3 pass cleanly across the full range.

**Assessment:** Correct. The most borderline cases wait briefly. No
legitimate new developer is permanently excluded.

### Profile 2: Sybil Farm Account

**Description:** Adversarial account created specifically for passport
farming. Stellar wallet 1 to 7 days old. XLM balance 1.5 to 2 XLM.
GitHub account created recently with zero public repos and zero Stellar
contributions.

**Expected outcome:** FAIL at least two gates.

**Actual outcome:** FAIL all three gates. No path through any gate.

**Assessment:** Best possible outcome. A sybil farm account has no
qualifying path under any threshold combination we evaluated.

### Profile 3: Active DeFi-Only Wallet

**Description:** Genuine Stellar user but not a developer. Stellar
wallet 1 to 2 years old. XLM average 500 to 1000. GitHub account
minimal or non-existent.

**Expected outcome:** FAIL the GitHub gate.

**Actual outcome:** Gates 1 and 2 pass. Gate 3 fails because no GitHub
account meets the 180-day age requirement or the activity criteria.

**Assessment:** Correct. This profile represents a real ecosystem
participant who is not a builder. The GitHub gate distinguishes this
case precisely as designed.

### Profile 4: Abandoned and Recovered Wallet

**Description:** Developer with a long-standing Stellar wallet that
went inactive and was recently re-funded. Stellar wallet 2 to 3 years
old. XLM recently re-funded to 10 to 20. GitHub active with Stellar
contributions.

**Expected outcome:** PASS all three gates.

**Actual outcome:** Gates 1 and 3 pass cleanly. Gate 2 is conditional
on re-funding timing. A contributor who re-funded 30 or more days ago
passes. A contributor who re-funded recently has a 30-day average
dragged down by the preceding near-zero period and needs to wait out
the rolling average window.

**Assessment:** Correct. This is the rolling average doing exactly what
it was designed to do. The contributor who re-funded recently is not
permanently excluded, they are asked to maintain their balance for 30
days and retry. The rejection message explains this clearly.

---

## Adjustment History

No threshold adjustments were made between the initial proposal and
ratification. The proposed values passed all four synthetic profile
validations on the first attempt. The one design decision that
required deliberation was the XLM balance measurement method:
rolling average was chosen over point-in-time after discussing the
temporary funding attack vector.

---

## Review Schedule

These thresholds are considered stable at v1.0 until a deliberate
threshold change is initiated by the ForgePass core team. A review
is recommended 6 months after mainnet launch to assess whether real
contributor distribution data suggests recalibration is needed.

Factors that would warrant an earlier review:

- Evidence of organised sybil attacks that are successfully passing
  the gates at scale
- Evidence that legitimate new contributors are being excluded at
  a rate that is materially harming ecosystem growth
- A significant change in the XLM fiat value that makes the 10 XLM
  balance threshold either trivial or prohibitive in real-world terms
- A significant change in the Stellar ecosystem contributor base that
  makes the GitHub age threshold too high or too low

Any threshold change must follow the same process as this document:
gate logic confirmed, numeric values deliberated, synthetic profiles
re-validated, internal review completed, and a new version committed
to sybil-thresholds.json with a changelog entry.

---

## Review Summary

| Item | Detail |
|---|---|
| Decision process | Steps 1 through 5 per Issue #002 Roadmap v1.0 |
| Gate logic decisions | Step 1 |
| Numeric threshold proposals | Step 2 |
| Config draft and dispute pathway | Step 3 |
| Internal review | Step 4 |
| Ratification | Step 5 |
| Public RFC conducted | No — sybil resistance thresholds are enforcement values. Publishing exact values is a security anti-pattern. Internal review substitutes for community comment per the rationale documented in Issue #002 Roadmap v1.0 Section 2. |
| Synthetic profiles validated | 4 of 4 produce correct outcomes |
| Threshold adjustments from initial proposal | None |
| Ratification date | 2026-05-23 |
| Companion documents | sybil-thresholds.json · gate-specifications.md |

---

*v1.0 · github.com/forgepass-xyz · MIT Licensed*
*Based on FRD v1.1 · Issues v1.1 · Issue #002 Roadmap v1.0*
