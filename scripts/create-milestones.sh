#!/bin/bash
# ForgePass milestone creation script -- v1.0
# Creates the 7 standard ForgePass milestones on a target repository.
# Run on both active repos so milestone names are identical across the project.
#
# Usage:   bash create-milestones.sh <org/repo>
# Example: bash create-milestones.sh forgepass-xyz/forgepass-contracts
#          bash create-milestones.sh forgepass-xyz/forgepass-core

REPO="${1:?Usage: $0 <org/repo>}"
echo "Creating ForgePass milestones on $REPO ..."

create_milestone() {
  local title="$1"
  local description="$2"
  if gh api "repos/$REPO/milestones" -f title="$title" -f state="open" -f description="$description" --silent 2>/dev/null; then
    echo "Milestone \"$title\" created in $REPO"
  else
    echo "Milestone \"$title\" already exists or failed in $REPO"
  fi
}

create_milestone "Phase 0: Foundation & Setup" "All decisions resolved, repos scaffolded, contract interfaces and DB schema designed. Issues #001-#015."
create_milestone "Phase 1: Smart Contracts" "All four Soroban contracts implemented, tested, and deployed to testnet. Issues #016-#022."
create_milestone "Phase 2: Backend API" "NestJS API operational: indexers, scoring engine, REST/GraphQL endpoints, admin tooling. Issues #023-#045."
create_milestone "Phase 3: Frontend" "Next.js web app: onboarding flow, contributor dashboard, public profiles, explorer. Issues #046-#059."
create_milestone "Phase 4: Integrations & AI" "Confirmed integrations, integrator registration, AI summaries, contributor graph. Issues #060-#078."
create_milestone "Phase 5: Mainnet & Launch" "Mainnet deployment, production environment, full docs, public launch. Issues #079-#087."
create_milestone "Roadmap: Epic 9 (Future Phase)" "Deferred SDK and future signal source issues, gated on #009 and #010. Issues R01-R10."

echo ""
echo "Done. 7 milestones created on $REPO"
echo "Run this script on both active repos:"
echo "  bash create-milestones.sh forgepass-xyz/forgepass-contracts"
echo "  bash create-milestones.sh forgepass-xyz/forgepass-core"