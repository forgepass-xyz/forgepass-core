# forgepass-core
> Project board: https://github.com/orgs/forgepass-xyz/projects/2

**The core monorepo for ForgePass — backend API, contributor dashboard, and documentation**

This monorepo contains the three tightly coupled packages that form the operational heart of ForgePass. They share a Node.js 18+ toolchain, deploy together, and are maintained by the ForgePass core team.

> Part of the [ForgePass](https://github.com/forgepass-xyz) open-source ecosystem.

---

## What's in Here

| Package | Path | Description |
|---|---|---|
| **API** | `apps/api` | NestJS backend: contribution ingestion, Trust Score engine, public API |
| **App** | `apps/web` | Next.js frontend: contributor dashboard and passport explorer |
| **Docs** | `docs` | MDX documentation site: API reference, integration guides, architecture |

For the Soroban smart contracts, see [`forgepass-contracts`](https://github.com/forgepass-xyz/forgepass-contracts) (Rust, separate repo, separate toolchain).

For the third-party client SDK, see [`forgepass-sdk`](https://github.com/forgepass-xyz/forgepass-sdk) (separate npm package).

---

## Monorepo Structure

```
forgepass-core/
├── apps/
│   ├── api/          # NestJS backend
│   └── web/          # Next.js frontend
├── docs/             # MDX documentation site
├── package.json      # Root npm workspaces config
└── .env.example      # Shared environment variable reference
```

---

## Prerequisites

- Node.js 18+
- PostgreSQL
- A Stellar Horizon endpoint (testnet or mainnet)
- [Freighter wallet extension](https://www.freighter.app/) for local frontend testing

---

## Getting Started

```bash
# Clone the repo
git clone https://github.com/forgepass-xyz/forgepass-core
cd forgepass-core

# Install all workspace dependencies
npm install

# Copy and configure environment variables
cp .env.example .env
```

Then start each package; see the README in each `apps/` directory for package-specific setup (migrations, env vars, ports).

### Running everything locally

```bash
# Start the API (runs on :3001 by default)
npm run dev --workspace=apps/api

# Start the web app (runs on :3000 by default)
npm run dev --workspace=apps/web

# Start the docs site (runs on :3002 by default)
npm run dev --workspace=docs
```

---

## npm Workspaces

This repo uses [npm workspaces](https://docs.npmjs.com/cli/using-npm/workspaces). Dependencies are hoisted to the root `node_modules` where possible. Each package has its own `package.json` for scripts and package-specific deps.

To run a script in a specific workspace:

```bash
npm run <script> --workspace=apps/api
npm run <script> --workspace=apps/web
npm run <script> --workspace=docs
```

---

## Relationship to Other Repos

- **[`forgepass-contracts`](https://github.com/forgepass-xyz/forgepass-contracts)** — `apps/api` reads from and writes to these Soroban contracts.
- **[`forgepass-sdk`](https://github.com/forgepass-xyz/forgepass-sdk)** — third-party projects use the SDK to consume the API that `apps/api` serves.

---

## Contributing

Each package has its own `good-first-issue` labels scoped to its area. You do not need to understand the entire monorepo to contribute; pick the package that matches your skills and start there.

- **`apps/api`** — TypeScript, NestJS, PostgreSQL
- **`apps/web`** — TypeScript, Next.js, Tailwind CSS, Freighter SDK
- **`docs`** — MDX, documentation writing

All code is **MIT licensed**.
