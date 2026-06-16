git add scripts/create-labels.sh
git commit -m "phase-0: add label creation script (#015)

- 73 labels covering phase, scope, type, feature, and meta groups
- sdk label created as reserved (pale blue #C5DEF5)
- Idempotent via --force flag, safe to re-run

Step 2 of 4 in progress"
git push origin phase-0/015-project-board-setup#!/bin/bash
# ForgePass label creation script -- v1.0
# Creates the complete ForgePass label set (73 labels) on a target repository.
# The --force flag updates existing labels (idempotent -- safe to re-run).
#
# Usage:   bash create-labels.sh <org/repo>
# Example: bash create-labels.sh forgepass-xyz/forgepass-contracts
#          bash create-labels.sh forgepass-xyz/forgepass-core

REPO="${1:?Usage: $0 <org/repo>}"
echo "Creating ForgePass label set on $REPO ..."

# --- Phase labels (7) ---
gh label create "phase-0"  --color "0052CC" --description "Phase 0: Foundation & Setup"         --repo "$REPO" --force
gh label create "phase-1"  --color "1A68C5" --description "Phase 1: Smart Contracts"            --repo "$REPO" --force
gh label create "phase-2"  --color "1A80CF" --description "Phase 2: Backend API"                --repo "$REPO" --force
gh label create "phase-3"  --color "1A97D4" --description "Phase 3: Frontend"                   --repo "$REPO" --force
gh label create "phase-4"  --color "7B61FF" --description "Phase 4: Integrations & AI"          --repo "$REPO" --force
gh label create "phase-5"  --color "5E35B1" --description "Phase 5: Mainnet & Launch"           --repo "$REPO" --force
gh label create "roadmap"  --color "6E6E6E" --description "Future Phase: Epic 9 Roadmap"        --repo "$REPO" --force

# --- Scope labels (6) ---
gh label create "contracts"  --color "E6A817" --description "forgepass-contracts (Rust/Soroban)"                  --repo "$REPO" --force
gh label create "api"        --color "5319E7" --description "forgepass-core/apps/api (NestJS)"                    --repo "$REPO" --force
gh label create "frontend"   --color "0075CA" --description "forgepass-core/apps/web (Next.js)"                   --repo "$REPO" --force
gh label create "sdk"        --color "C5DEF5" --description "RESERVED: forgepass-sdk (activate after #010)"       --repo "$REPO" --force
gh label create "docs"       --color "0E8A16" --description "Documentation (forgepass-core/docs)"                 --repo "$REPO" --force
gh label create "org"        --color "D4C5F9" --description "Organisation-level or cross-repo"                    --repo "$REPO" --force

# --- Type labels (9) ---
gh label create "decision"          --color "D93F0B" --description "DECISION NEEDED -- blocks phase gate"           --repo "$REPO" --force
gh label create "bug"               --color "D73A49" --description "Something is broken"                            --repo "$REPO" --force
gh label create "enhancement"       --color "A2EEEF" --description "New feature or improvement"                     --repo "$REPO" --force
gh label create "setup"             --color "BFDADC" --description "Scaffolding or initial configuration"           --repo "$REPO" --force
gh label create "architecture"      --color "F9D0C4" --description "Architecture or design decision"                --repo "$REPO" --force
gh label create "testing"           --color "C2E0C6" --description "Test coverage or test infrastructure"           --repo "$REPO" --force
gh label create "security"          --color "B60205" --description "Security-related issue or review"               --repo "$REPO" --force
gh label create "devops"            --color "E99695" --description "CI/CD, deployment, or infrastructure"           --repo "$REPO" --force
gh label create "good-first-issue"  --color "7057FF" --description "Good entry point for new contributors"          --repo "$REPO" --force

# --- Feature area labels (48) ---
gh label create "trust-score"       --color "1D76DB" --description "Trust Score engine and algorithm"              --repo "$REPO" --force
gh label create "sybil-resistance"  --color "E8442D" --description "Sybil resistance checks (onboarding gates)"   --repo "$REPO" --force
gh label create "passport"          --color "0052CC" --description "Builder Passport lifecycle"                    --repo "$REPO" --force
gh label create "badges"            --color "E4B429" --description "Achievement badge system"                      --repo "$REPO" --force
gh label create "nft"               --color "7048D8" --description "Soulbound NFT contract"                        --repo "$REPO" --force
gh label create "credentials"       --color "4C54FF" --description "Credential store and anchoring"                --repo "$REPO" --force
gh label create "indexer"           --color "006B75" --description "Signal ingestion indexers"                     --repo "$REPO" --force
gh label create "github"            --color "24292F" --description "GitHub signal source"                          --repo "$REPO" --force
gh label create "horizon"           --color "00AFBC" --description "Stellar Horizon signal source"                 --repo "$REPO" --force
gh label create "soroban"           --color "3F51B5" --description "Soroban-specific implementation"               --repo "$REPO" --force
gh label create "scoring"           --color "1B6FC8" --description "Trust Score computation"                       --repo "$REPO" --force
gh label create "ai"                --color "8B5CF6" --description "AI summary (Anthropic API)"                    --repo "$REPO" --force
gh label create "privacy"           --color "E36209" --description "Privacy controls and signal visibility"        --repo "$REPO" --force
gh label create "graph"             --color "0075CA" --description "Contributor graph construction and query"      --repo "$REPO" --force
gh label create "ecosystem"         --color "2EA44F" --description "Ecosystem health metrics and stats"            --repo "$REPO" --force
gh label create "integrations"      --color "6A737D" --description "Third-party integrations"                      --repo "$REPO" --force
gh label create "dao"               --color "0EBBCF" --description "DAO governance weight integration"             --repo "$REPO" --force
gh label create "grantfox"          --color "F6C519" --description "GrantFox integration (roadmap)"                --repo "$REPO" --force
gh label create "trustless-work"    --color "C9A227" --description "Trustless Work integration (roadmap)"          --repo "$REPO" --force
gh label create "scf"               --color "0078D7" --description "SCF integration (roadmap)"                     --repo "$REPO" --force
gh label create "auth"              --color "5319E7" --description "Authentication (wallet JWT, GitHub OAuth)"     --repo "$REPO" --force
gh label create "onboarding"        --color "84B6EB" --description "Contributor onboarding flow"                   --repo "$REPO" --force
gh label create "onchain"           --color "3F51B5" --description "On-chain Soroban write operations"             --repo "$REPO" --force
gh label create "storage"           --color "006B75" --description "IPFS/Arweave decentralised storage"            --repo "$REPO" --force
gh label create "graphql"           --color "E535AB" --description "GraphQL API endpoint"                          --repo "$REPO" --force
gh label create "rest"              --color "7048D8" --description "REST API endpoints"                             --repo "$REPO" --force
gh label create "rate-limiting"     --color "F0C8A0" --description "Rate limiting implementation"                  --repo "$REPO" --force
gh label create "disputes"          --color "E99695" --description "Dispute submission and resolution"              --repo "$REPO" --force
gh label create "hackathons"        --color "D4A017" --description "Hackathon event ingestion"                     --repo "$REPO" --force
gh label create "dashboard"         --color "C5DEF5" --description "Authenticated contributor dashboard"           --repo "$REPO" --force
gh label create "profile"           --color "BFD4F2" --description "Public contributor profile page"               --repo "$REPO" --force
gh label create "explorer"          --color "84B6EB" --description "Passport explorer and search"                  --repo "$REPO" --force
gh label create "responsive"        --color "0096CC" --description "Responsive design and mobile support"          --repo "$REPO" --force
gh label create "freighter"         --color "6B48FF" --description "Freighter wallet SDK integration"              --repo "$REPO" --force
gh label create "webhooks"          --color "0D8A8A" --description "Webhook delivery (inbound and outbound)"       --repo "$REPO" --force
gh label create "admin"             --color "8B0000" --description "Admin tooling and moderation"                  --repo "$REPO" --force
gh label create "database"          --color "C8901A" --description "Database schema and migrations"                --repo "$REPO" --force
gh label create "project-management" --color "0064B4" --description "Project coordination and board setup"         --repo "$REPO" --force
gh label create "ci"                --color "5C5C5C" --description "CI/CD pipeline configuration"                  --repo "$REPO" --force
gh label create "observability"     --color "F9A825" --description "Monitoring, alerting, and logging"             --repo "$REPO" --force
gh label create "performance"       --color "FBCA04" --description "Performance optimisation and load testing"     --repo "$REPO" --force
gh label create "accessibility"     --color "0E8A16" --description "Accessibility (WCAG 2.1 AA)"                  --repo "$REPO" --force
gh label create "e2e"               --color "C2E0C6" --description "End-to-end and system tests"                  --repo "$REPO" --force
gh label create "data-integrity"    --color "E6B000" --description "Data integrity and deduplication tests"        --repo "$REPO" --force
gh label create "mainnet"           --color "B60205" --description "Mainnet deployment and operations"             --repo "$REPO" --force
gh label create "launch"            --color "1A7A3F" --description "Public launch actions"                         --repo "$REPO" --force
gh label create "audit"             --color "D73A49" --description "Security audit (internal or external)"         --repo "$REPO" --force
gh label create "release"           --color "0E8A16" --description "SDK or API release"                            --repo "$REPO" --force

# --- Meta labels (3) ---
gh label create "blocked"    --color "E11D48" --description "Blocked on another issue or dependency" --repo "$REPO" --force
gh label create "duplicate"  --color "CFD3D7" --description "Duplicate of another issue"            --repo "$REPO" --force
gh label create "wontfix"    --color "EEEEEE" --description "Will not be addressed in this phase"   --repo "$REPO" --force

echo ""
echo "Done. 73 labels created/updated on $REPO"
echo "Run this script on both active repos:"
echo "  bash create-labels.sh forgepass-xyz/forgepass-contracts"
echo "  bash create-labels.sh forgepass-xyz/forgepass-core"
