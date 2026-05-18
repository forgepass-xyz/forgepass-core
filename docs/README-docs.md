# docs

**Documentation for the ForgePass ecosystem; API reference, integration guides, and architecture**

This package contains everything needed to understand, integrate with, and contribute to ForgePass. It is the authoritative reference for the public API, the Trust Score algorithm, smart contract interfaces, and the SDK.

> Lives in [`forgepass-core`](../), the ForgePass core monorepo.

---

## Who This Is For

**Developers integrating ForgePass** : if you are building a Stellar project and want to surface contributor reputation, start with the API Reference and Integration Guides.

**Contributors to ForgePass** : if you are building or improving any package in this monorepo, the Architecture section explains how the system fits together and why each design decision was made.

**Anyone curious about how the Trust Score works** : the scoring algorithm is fully documented here. Every signal, weight, and version is explained openly.

---

## What's in Here

### API Reference
Complete documentation for the ForgePass public REST and GraphQL API : endpoints, parameters, response shapes, and authentication (reads are open; writes require Stellar wallet signing).

### Integration Guides
Step-by-step guides for the most common integration patterns:
- Ranking contributor applicants by Trust Score (GrantFox-style)
- Surfacing passport history alongside grant applications (SCF-style)
- Adding contribution-weighted governance voting (DAO-style)
- Auto-writing escrow completions to contributor passports (Trustless Work-style)
- Getting started with the [`forgepass-sdk`](https://github.com/forgepass-xyz/forgepass-sdk)

### Trust Score Algorithm
The full specification for the open Trust Score: which signals are measured, how they are weighted, how the algorithm is versioned, and how to read the per-signal breakdown returned by the API.

This section answers the question: *"How was this score calculated?"* completely and without ambiguity.

### Architecture
How the ForgePass system is designed end-to-end:
- What lives on-chain (Soroban) vs off-chain (API + PostgreSQL)
- How contribution signals flow from source to passport
- How sybil resistance is enforced
- How privacy controls work
- How new signal sources can be added without changing core contracts

### Smart Contract Reference
Interface documentation for the Soroban contracts in [`forgepass-contracts`](https://github.com/forgepass-xyz/forgepass-contracts), for projects that want to interact with passports directly on-chain rather than through the API.

### Contribution Guide
How to contribute to any ForgePass repository : setup, code standards, PR process, and how the good-first-issue labels are structured across repos.

---

## Running the Docs Locally

The documentation site is built with MDX.

```bash
# From the monorepo root, run npm install first, then:
npm run dev --workspace=docs
```

Open [http://localhost:3002](http://localhost:3002) to browse the docs locally.

---

## Contributing

Documentation improvements are always welcome: clearer explanations, better examples, and corrections are as valuable as code contributions.

If you find something confusing or missing while integrating ForgePass, please open an issue. The best documentation comes from people who just went through the experience of using something for the first time.

All content is **MIT licensed**.
