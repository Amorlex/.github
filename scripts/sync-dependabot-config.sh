#!/bin/bash
# Sync dependabot configuration from Amorlex/.github to all target repositories
# Usage: ./sync-dependabot-config.sh [--dry-run] [--repo REPO]

set -euo pipefail

# Configuration
REPO_MAPPING=(
  # Rails Cohort A (Monday) — 5 repos
  "amorlex-rails:rails-cohort-a.yml"
  "formcatch-rails:rails-cohort-a.yml"
  "markwright-rails:rails-cohort-a.yml"
  "signet-rails:rails-cohort-a.yml"
  "slipsnap-rails:rails-cohort-a.yml"
  
  # Rails Cohort B (Wednesday) — 4 repos
  "shiplog-rails:rails-cohort-b.yml"
  "topdeck-rails:rails-cohort-b.yml"
  "hookshot-rails:rails-cohort-b.yml"
  "cronbell-rails:rails-cohort-b.yml"
  
  # Rails Cohort C (Friday) — 3 repos
  "quillpost-rails:rails-cohort-c.yml"
  "flagdrop-rails:rails-cohort-c.yml"
  "billsight-rails:rails-cohort-c.yml"
  
  # Rails Special Case (Friday + npm/sdk) — 1 repo
  "tallymark-rails:rails-tallymark.yml"
  
  # Gem Repos — 2 repos
  "amorlex-ui:gem-repo.yml"
  "amorlex-core:gem-repo.yml"
)

# Caller workflow content (exact copy from dependabot-configuration-report.md:439-449)
CALLER_WORKFLOW='name: Dependabot Auto-Merge
on: pull_request_target
permissions:
  contents: write
  pull-requests: write
  issues: write
jobs:
  auto-merge:
    uses: Amorlex/.github/.github/workflows/reusable-dependabot-auto-merge.yml@main
    secrets: inherit
'

# Parse arguments
DRY_RUN=false
TARGET_REPO=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --repo)
      TARGET_REPO="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--dry-run] [--repo REPO]"
      exit 1
      ;;
  esac
done

# Helper functions
log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

log_success() {
  echo "[SUCCESS] $1"
}

cleanup_temp_dir() {
  if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

# Set up trap to clean up on exit
trap cleanup_temp_dir EXIT

# Get the templates directory (same directory as this script, relative path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/dependabot-templates"

if [[ ! -d "$TEMPLATES_DIR" ]]; then
  log_error "Templates directory not found: $TEMPLATES_DIR"
  exit 1
fi

# Process each repository
sync_repo() {
  local repo_name="$1"
  local template_name="$2"
  local template_path="$TEMPLATES_DIR/$template_name"
  
  if [[ ! -f "$template_path" ]]; then
    log_error "Template not found: $template_path"
    return 1
  fi
  
  log_info "Processing: $repo_name (template: $template_name)"
  
  # Create temporary directory for this repo
  TEMP_DIR=$(mktemp -d)
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] Would clone Amorlex/$repo_name to $TEMP_DIR"
    log_info "[DRY-RUN] Would create branch: chore/sync-dependabot-config"
    log_info "[DRY-RUN] Would copy template: $template_name → .github/dependabot.yml"
    log_info "[DRY-RUN] Would create workflow: .github/workflows/dependabot-auto-merge.yml"
    log_info "[DRY-RUN] Would commit: 'deps: sync dependabot config from Amorlex/.github'"
    log_info "[DRY-RUN] Would create PR with title: 'deps: sync dependabot config from Amorlex/.github'"
    rm -rf "$TEMP_DIR"
    TEMP_DIR=""
    return 0
  fi
  
  # Clone the repository (shallow clone for speed)
  if ! gh repo clone "Amorlex/$repo_name" "$TEMP_DIR" -- --depth=1 2>/dev/null; then
    log_error "Failed to clone Amorlex/$repo_name"
    return 1
  fi
  
  cd "$TEMP_DIR"
  
  # Create and checkout the sync branch
  git checkout -b chore/sync-dependabot-config 2>/dev/null || {
    log_error "Failed to create branch for $repo_name"
    return 1
  }
  
  # Create .github directory if it doesn't exist
  mkdir -p .github/workflows
  
  # Copy the dependabot template
  cp "$template_path" .github/dependabot.yml
  
  # Write the caller workflow
  echo "$CALLER_WORKFLOW" > .github/workflows/dependabot-auto-merge.yml
  
  # Stage changes
  git add .github/dependabot.yml .github/workflows/dependabot-auto-merge.yml
  
  # Check if there are changes to commit
  if ! git diff --cached --quiet; then
    # Commit changes
    git commit -m "deps: sync dependabot config from Amorlex/.github" || {
      log_error "Failed to commit changes for $repo_name"
      return 1
    }
    
    # Push to remote
    git push -u origin chore/sync-dependabot-config || {
      log_error "Failed to push branch for $repo_name"
      return 1
    }
    
    # Create pull request
    if gh pr create \
      --title "deps: sync dependabot config from Amorlex/.github" \
      --body "Automated sync from Amorlex/.github dependabot templates." \
      --assignee "MorganShowman" \
      --label "dependencies" \
      2>/dev/null; then
      log_success "PR created for $repo_name"
    else
      log_error "Failed to create PR for $repo_name (PR may already exist)"
      return 1
    fi
  else
    log_info "No changes to commit for $repo_name (already synced?)"
  fi
  
  cd - > /dev/null
  rm -rf "$TEMP_DIR"
  TEMP_DIR=""
  return 0
}

# Main execution
main() {
  local success_count=0
  local failure_count=0
  
  log_info "Dependabot Config Sync Script"
  log_info "=============================="
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Running in DRY-RUN mode (no changes will be made)"
  fi
  
  log_info ""
  
  for mapping in "${REPO_MAPPING[@]}"; do
    repo_name="${mapping%:*}"
    template_name="${mapping#*:}"
    
    # Filter by --repo flag if provided
    if [[ -n "$TARGET_REPO" ]] && [[ "$repo_name" != "$TARGET_REPO" ]]; then
      continue
    fi
    
    # Run sync_repo and capture exit code explicitly.
    # NOTE: Do NOT use 'if sync_repo ...; then' — that suppresses
    # errexit inside the function call (standard bash behavior).
    sync_repo "$repo_name" "$template_name" && rc=0 || rc=$?
    if [[ $rc -eq 0 ]]; then
      success_count=$((success_count + 1))
    else
      failure_count=$((failure_count + 1))
    fi
    
    log_info ""
  done
  
  # Summary
  log_info "=============================="
  log_info "Summary: $success_count succeeded, $failure_count failed"
  
  if [[ $failure_count -gt 0 ]]; then
    exit 1
  fi
}

main
