# Contributing to ForgePass

## Getting Started
1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/forgepass-core`
3. Install dependencies: `npm install` from root
4. Copy environment variables: `cp apps/api/.env.example apps/api/.env`
5. Start all packages: `npm run dev`

## Branch Naming
- `feat/issue-number-short-description`
- `fix/issue-number-short-description`
- `chore/description`

## Commit Format
Conventional commits:
- `feat(api): add passport read endpoint`
- `fix(web): correct badge IPFS loading`
- `chore(docs): update integration guide`

## Running the Full Stack Locally
- PostgreSQL must be running locally
- apps/api runs on port 3001
- apps/web runs on port 3000
- docs runs on port 3002

## PR Requirements
- CI must be passing
- At least one review required
- Issue must be linked (Closes #NUMBER)
- No direct pushes to main

## Issue Labels
- `phase-0` through `phase-5` — development phase
- `good-first-issue` — accessible entry points
- `bug` — something is broken
- `feat` — new feature

## Packages
- `apps/api` — TypeScript, NestJS, PostgreSQL
- `apps/web` — TypeScript, Next.js, Tailwind CSS
- `docs` — MDX, documentation writing

## Project Board
 
All active work is tracked on the
[ForgePass Development Board](https://github.com/orgs/forgepass-xyz/projects/2).
New issues are auto-added to the **Backlog** column. Opening a pull request
moves the linked issue to **In Progress**; marking the PR ready for review
moves it to **Review**; closing the issue moves it to **Done**.
 
When creating an issue, set the **Phase**, **Effort**, **Repo**, and **Epic**
custom fields on the board so the issue is correctly grouped in views and
reports.
 
## Cross-Repo Issue Linking Convention
 
ForgePass spans three repositories: `forgepass-contracts`, `forgepass-core`,
and (once activated) `forgepass-sdk`. Many issues depend on or are blocked by
issues in a different repository. Follow this convention so dependencies are
traceable across repos:
 
- Reference issues in another repo using the full form:
  `forgepass-xyz/forgepass-contracts#42` (not just `#42`, which only
  resolves within the current repo).
- In an issue description, list cross-repo dependencies under a
  **Depends on** heading using the full cross-repo reference form above.
- When a PR closes an issue that lives in a different repo, use a PR
  description comment referencing the full cross-repo issue rather than a
  GitHub closing keyword, since closing keywords (`Closes #N`) only work
  within the same repository.
- Issue numbers are never reused across repos. `forgepass-contracts` and
  `forgepass-core` issues share the same numbering sequence as defined in
  *ForgePass Issues v1.1* (`#001`-`#087`, plus roadmap issues `R01`-`R10`
  held in `forgepass-sdk` once activated).
## Branch Naming Convention
 
All branches follow the pattern:
 
```
phase-N/[issue-number]-[short-description]
```
 
Where `N` is the phase number (`0` through `5`) the issue belongs to, or
`future` for Epic 9 roadmap issues. Examples:
 
```
phase-0/015-project-board-setup
phase-1/016-passport-contract
phase-2/035-trust-score-engine
future/r01-sdk-scaffold
```
 
## SDK Repository Status
 
The `forgepass-sdk` repository is a roadmap item and is **not** connected to
the project board, the label set, or the milestone list described above. Its
activation is gated on issue **#010 (FR-10-A)**, which decides the target
development phase and resource allocation for the SDK.
 
Once `#010` is resolved:
 
- `forgepass-sdk/ROADMAP.md` will be updated to record the confirmed phase.
- `scripts/create-labels.sh` and `scripts/create-milestones.sh` (this repo)
  will be run against `forgepass-sdk` to bring it into line with the other
  active repos.
- The `forgepass-sdk` repo will be added to the project board.
- Epic 9 SDK issues (`R01`-`R04`) will be promoted to the confirmed phase.
Until then, no issues should be opened against `forgepass-sdk` and no PRs
should target it.