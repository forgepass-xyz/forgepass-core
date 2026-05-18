# apps/web

**The ForgePass contributor dashboard; your Builder Passport, made visible**

This is the web application where contributors connect their Stellar wallet, view their Builder Passport, explore achievement badges, and browse the ecosystem's contributor network. It is also the public-facing interface through which any visitor can look up and verify a contributor's on-chain reputation.

> Lives in [`forgepass-core`](../../) — the ForgePass core monorepo.

---

## What This App Does

The app is the human-readable layer on top of the ForgePass system. Behind the scenes, reputation data lives in Soroban contracts and a PostgreSQL database. This application makes it accessible, navigable, and useful to contributors and projects alike, with no blockchain knowledge required.

### For Contributors

- **Connect your Stellar wallet** via the Freighter browser extension to claim and view your passport.
- **See your Trust Score** with a full breakdown of which signals contributed to it and how much each one weighs.
- **Browse your achievement badges** : soulbound NFTs minted on Stellar for milestones like your first merged PR, first deployed contract, or first completed bounty.
- **View your contribution timeline** : a chronological record of verified activity across GitHub, Soroban, SCF, GrantFox, and the Stellar network.
- **Manage your privacy settings** : choose which signals are publicly visible on your profile.

### For Projects & Visitors

- **Public contributor profiles** : any Stellar address can be looked up to view its verified passport, score, and badges.
- **Passport Explorer** : browse and filter contributors across the ecosystem by skill, Trust Score, project history, and region.
- **Ecosystem health dashboard** : an aggregate view of contributor growth, active hubs, and how the builder network is expanding over time.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Next.js (React) |
| Styling | Tailwind CSS |
| Wallet | Freighter Wallet SDK |
| Data | Fetched from [`apps/api`](../api) |

---

## Key Pages

| Route | What It Shows |
|---|---|
| `/` | Homepage and ecosystem overview |
| `/passport/:address` | Public contributor passport for any Stellar address |
| `/dashboard` | Authenticated contributor's own passport and settings |
| `/explore` | Contributor search and filtering |
| `/ecosystem` | Aggregate ecosystem health metrics |

---

## Development Setup

> Requires Node.js 18+ and the [Freighter wallet extension](https://www.freighter.app/) for local wallet testing. From the monorepo root, run `npm install` before starting.

```bash
# Make sure apps/api is running locally first (defaults to :3001)

# Set the API URL in your local env
# In .env.local: NEXT_PUBLIC_API_URL=http://localhost:3001

# Start the development server (runs on :3000 by default)
npm run dev --workspace=apps/web
```

Open [http://localhost:3000](http://localhost:3000) to view the app.

---

## Relationship to Other Packages

- All data is fetched from **[`apps/api`](../api)**.
- Wallet authentication triggers passport reads from **[`forgepass-contracts`](https://github.com/forgepass-xyz/forgepass-contracts)** via the API.

---

## Contributing

Design contributions are especially welcome here: the experience of navigating your own reputation should feel as polished as any professional product. Issues are labelled `good-first-issue` for accessible entry points.

All code is **MIT licensed**.
