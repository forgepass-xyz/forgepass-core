# apps/api

**The backend engine behind ForgePass — contribution indexing, Trust Score computation, and the public API**

This package is the off-chain backbone of ForgePass. It ingests contributor activity from GitHub, Horizon (Stellar's API), and ecosystem platforms; computes Trust Scores; writes verified credentials to the on-chain contracts; and serves all passport data through a free, open API that any Stellar project can consume.

> Lives in [`forgepass-core`](../../) — the ForgePass core monorepo.

---

## Core Responsibilities

**Contribution Ingestion**
Pulls and indexes contributor activity from multiple sources:
- GitHub (OAuth-authenticated): pull requests, code reviews, and commit history against Stellar ecosystem repositories
- Stellar Horizon API: on-chain account history, DEX trades, Aquarius LP positions, transaction volume

**Scoring Engine**
Runs the open Trust Score algorithm against each contributor's aggregated signals. The algorithm is versioned and fully documented: every weight and calculation is auditable. No black box.

**On-chain Writing**
After scoring, calls the [`forgepass-contracts`](https://github.com/forgepass-xyz/forgepass-contracts) Soroban contracts to anchor updated Trust Scores and write new verified credentials to the contributor's Builder Passport.

**Public API**
Exposes a REST and GraphQL API, free and open to any Stellar project. Returns passport data, Trust Scores, contributor graphs, and badge records at API speed using PostgreSQL as the read layer.

**Sybil Resistance**
Enforces verification gates during onboarding: Stellar account age checks, minimum XLM balance thresholds, and GitHub verification requirements to make it meaningfully harder to game contributor reputation.

---

## API Overview

The public API is versioned and freely accessible. No authentication required for read operations.

```
GET  /v1/passport/:stellarAddress     — Full passport for a contributor
GET  /v1/score/:stellarAddress        — Trust Score and signal breakdown
GET  /v1/badges/:stellarAddress       — Achievement badges earned
GET  /v1/graph/:stellarAddress        — Contributor graph (collaborators, shared projects)
GET  /v1/contributors                 — Paginated contributor index with filtering
```

Full API reference: [`docs/`](../../docs)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | NestJS (Node.js / TypeScript) |
| Database | PostgreSQL |
| Blockchain | Stellar SDK (JS) + Horizon API |
| Smart Contracts | Soroban SDK (writes to `forgepass-contracts`) |
| Auth | GitHub OAuth 2.0 |
| CI | GitHub Actions (automated contribution indexing on repo events) |
| AI (opt-in) | Anthropic API — generates human-readable contributor summaries |

---

## Development Setup

> Requires Node.js 18+, PostgreSQL, and a Stellar Horizon endpoint (testnet or mainnet). From the monorepo root, run `npm install` before starting.

```bash
# From the monorepo root
cp .env.example .env
# Fill in PostgreSQL connection, Horizon endpoint, GitHub OAuth credentials

# Run database migrations
npm run migrate --workspace=apps/api

# Start the development server (runs on :3001 by default)
npm run dev --workspace=apps/api
```

See [`docs/`](../../docs) for full environment variable reference and testnet configuration.

---

## Relationship to Other Packages

- Reads from and writes to **[`forgepass-contracts`](https://github.com/forgepass-xyz/forgepass-contracts)** (Soroban).
- Serves data consumed by **[`apps/web`](../web)** (the contributor dashboard).
- Powers the **[`forgepass-sdk`](https://github.com/forgepass-xyz/forgepass-sdk)** third-party projects use the SDK to call this API.

---

## Contributing

Issues are labelled `good-first-issue` for accessible entry points. TypeScript and NestJS familiarity is helpful but not required for many issues.

All code is **MIT licensed**.
