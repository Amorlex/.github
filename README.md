# Amorlex/.github

Amorlex organization-level workflows and configuration templates. This repository contains reusable GitHub Actions workflows and standardized dependabot configurations for all Amorlex repositories.

## 📁 Repository Structure

```
Amorlex/.github/
├── .github/
│   └── workflows/
│       └── reusable-dependabot-auto-merge.yml      # Reusable auto-merge workflow
│
├── dependabot-templates/
│   ├── rails-cohort-a.yml                          # Monday schedule (5 Rails repos)
│   ├── rails-cohort-b.yml                          # Wednesday schedule (4 Rails repos)
│   ├── rails-cohort-c.yml                          # Friday schedule (3 Rails repos)
│   ├── rails-tallymark.yml                         # Friday + npm/sdk (1 special case)
│   └── gem-repo.yml                                # Gem repos (2 repos)
│
├── scripts/
│   └── sync-dependabot-config.sh                   # Sync script for pushing templates
│
└── README.md                                       # This file
```

## 🔄 Reusable Auto-Merge Workflow

The `.github/workflows/reusable-dependabot-auto-merge.yml` workflow implements intelligent, safe auto-merging of dependabot PRs with three gates:

### Gate 1: Block Major Version Bumps
Major version updates (e.g., Rails 7→8, Node 18→20) are blocked and require human review. These often contain breaking changes that need explicit testing.

### Gate 2: Block Security Scanner Updates
Updates to brakeman, bundler-audit, and ruby_audit are blocked. Scanner version changes are policy updates that need coordinated fleet-wide rollout.

### Gate 3: Block Production Dependencies
For bundler ecosystem, production runtime dependencies are blocked. GitHub Actions updates (low risk) are always auto-merged.

### What Gets Auto-Merged

✅ **GitHub Actions** — all versions  
✅ **Dev-tools minor/patch** — rspec, rubocop, factory_bot, faker, etc.  
❌ **Major version bumps** — Rails, Node, Python, etc.  
❌ **Security scanners** — brakeman, bundler-audit, ruby_audit  
❌ **Production runtime gems** — pg, sidekiq, redis, etc.

## 📋 Dependabot Templates

All Rails repositories are split into three cohorts for staggered updates:

### Cohort A (Monday)
- amorlex-rails
- formcatch-rails
- markwright-rails
- signet-rails
- slipsnap-rails

### Cohort B (Wednesday)
- shiplog-rails
- topdeck-rails
- hookshot-rails
- cronbell-rails

### Cohort C (Friday)
- quillpost-rails
- flagdrop-rails
- billsight-rails

### Special Cases
**tallymark-rails** (Friday + npm/sdk):
- Uses `rails-tallymark.yml` template which includes the main Friday Rails cohort config PLUS an npm ecosystem block for the `/sdk` directory containing a published TypeScript SDK with minimal dependencies (tsup, typescript, vitest).

**Gem Repositories** (amorlex-ui, amorlex-core):
- Use `gem-repo.yml` template with `versioning-strategy: "increase"` (not `lockfile-only`) to widen gemspec constraints for downstream consumers.

## 🚀 Sync Script

The `scripts/sync-dependabot-config.sh` script pushes templates to all 15 repositories and creates PRs for integration.

### Usage

```bash
# Sync all repositories (creates PRs)
./scripts/sync-dependabot-config.sh

# Preview changes without creating PRs
./scripts/sync-dependabot-config.sh --dry-run

# Sync a single repository
./scripts/sync-dependabot-config.sh --repo amorlex-rails

# Preview single repo
./scripts/sync-dependabot-config.sh --dry-run --repo amorlex-rails
```

### What the Script Does

For each target repository:
1. Clones a shallow copy to a temporary directory
2. Creates branch `chore/sync-dependabot-config`
3. Copies the appropriate dependabot template as `.github/dependabot.yml`
4. Copies the caller workflow as `.github/workflows/dependabot-auto-merge.yml`
5. Commits with message: `deps: sync dependabot config from Amorlex/.github`
6. Creates a PR assigned to MorganShowman with label `dependencies`
7. Cleans up temporary directories

### Caller Workflow

Each target repo gets this caller workflow that references the reusable workflow in this repository:

```yaml
name: Dependabot Auto-Merge
on: pull_request
permissions:
  contents: write
  pull-requests: write
jobs:
  auto-merge:
    uses: Amorlex/.github/.github/workflows/reusable-dependabot-auto-merge.yml@main
    secrets: inherit
```

## 📊 Configuration Features

All templates include:
- **Versioning Strategy**: `lockfile-only` for Rails (immutable Gemfile), `increase` for gems
- **Supply Chain Protection**: 7-day cooldown on bundler updates (security updates bypass this)
- **Grouping**: Rails framework, Sentry, dev-tools, all-actions
- **Assignees & Reviewers**: MorganShowman on all PRs
- **Labels**: `dependencies` + ecosystem-specific labels (`ruby`, `github-actions`, `npm`)
- **Commit Prefix**: `deps(scope):` for worklog tracking
- **PR Limit**: 3 concurrent updates per ecosystem
- **Schedule**: Staggered across cohorts (Mon/Wed/Fri) to distribute review load

## 🔒 Security & Design

### Why Cohort Staggering?

| Concern | Same-Day | Staggered |
|---------|----------|-----------|
| PR Storm | 26-40 PRs Monday | 9-13 PRs spread across week |
| Review Load | Overwhelming | Sustainable |
| CI Queue | Contention | Distributed |
| Canary Effect | All at once | Later cohorts benefit from early issues |

### Why No Cooldown on GitHub Actions?

Bug #14579 in dependabot causes permanent freezing of frequently-released actions when cooldown is enabled. GitHub Actions release multiple times per week, so cooldown logic breaks.

### Why `lockfile-only` for Rails?

- Gemfile.lock is the source of truth for dependency resolution
- Major version bumps (Rails 7→8) require deliberate Gemfile edits
- Prevents accidental framework major version drops
- Consistent with production Rails projects (Discourse, OpenStreetMap)

### Why `increase` for Gem Repos?

Published gems need to widen gemspec constraints so downstream consumers know the gem is tested against new versions. This differs from Rails apps which lock to specific versions for reproducibility.

## 📚 Related Documents

Source reports and planning documents (maintained outside this repo):
- **Dependabot Configuration Report** — Detailed design decisions, research findings, and rationale
- **Brakeman CI Strategy Report** — Why security scanner updates are not auto-merged
- **Execution Plan** — Phase 0-3 rollout plan with per-repo change matrices

## 🔧 Maintenance

### Adding a New Repository

1. Determine which cohort (A/Mon, B/Wed, C/Fri, or special case)
2. Add mapping to `scripts/sync-dependabot-config.sh`
3. Run sync script targeting the new repo
4. Merge the resulting PR

### Updating Templates

1. Edit template(s) in `dependabot-templates/`
2. Run sync script to push changes to all repos
3. Each repo gets a separate PR with the updated config

### Monitoring

Key queries for worklog detection:
```bash
# PRs assigned to Morgan
gh search prs --owner=Amorlex --assignee=MorganShowman --state=open

# Auto-merged PRs this week
gh search prs --owner=Amorlex --label=auto-merge --state=merged --merged=">2026-07-06"

# Dependabot PRs by ecosystem
gh search prs --owner=Amorlex --author=app/dependabot --label=ruby --state=open
```

## 📝 License

Part of the Amorlex organization standard configuration.
