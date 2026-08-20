#!/usr/bin/env bash
#
# Publish the version tags and their GitHub Releases.
#
# Release notes are extracted from CHANGELOG.md, so the changelog stays the
# single source of truth and the releases can never drift from it.
#
# Usage:
#   ./scripts/publish-releases.sh --dry-run    # show what would happen
#   ./scripts/publish-releases.sh              # push tags, create releases
#
# Requires: git, and the GitHub CLI (https://cli.github.com) authenticated
# with `gh auth login`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
REMOTE="${REMOTE:-origin}"
LATEST_TAG="v2.0.0"

TAGS=(v1.0.0 v1.1.0 v1.2.0 v1.3.0 v1.4.0 v2.0.0)

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

info()  { printf '\033[1;34m▸\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m!\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

run() {
  if $DRY_RUN; then
    printf '  \033[2mwould run:\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

# --- preflight ---------------------------------------------------------------

command -v git >/dev/null || die "git not found"
if $DRY_RUN; then
  command -v gh >/dev/null || warn "GitHub CLI not installed — dry run will not check existing releases"
else
  command -v gh >/dev/null || die "GitHub CLI not found — see https://cli.github.com"
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run: gh auth login"
fi
[[ -f "$CHANGELOG" ]] || die "CHANGELOG.md not found at $CHANGELOG"

cd "$REPO_ROOT"

for tag in "${TAGS[@]}"; do
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null \
    || die "Tag $tag does not exist locally. Create the tags before running this."
done

# --- notes extraction --------------------------------------------------------

# Pull one version's section out of CHANGELOG.md, stopping at the next heading.
extract_notes() {
  local version="${1#v}"
  awk -v want="$version" '
    /^## \[/ {
      if (inside) exit
      # Match "## [1.4.0] — 2025-12-12 · Build 6"
      line = $0
      sub(/^## \[/, "", line)
      sub(/\].*$/, "", line)
      if (line == want) { inside = 1; next }
    }
    # Stop at the link-reference block at the foot of the changelog.
    inside && /^\[[^]]+\]:[[:space:]]*http/ { exit }
    inside && /^---[[:space:]]*$/ { next }
    inside { print }
  ' "$CHANGELOG"
}

# --- push tags ---------------------------------------------------------------

info "Pushing tags to $REMOTE"
run git push "$REMOTE" "${TAGS[@]}"
ok "Tags pushed"

# --- create releases ---------------------------------------------------------

for tag in "${TAGS[@]}"; do
  if command -v gh >/dev/null && gh release view "$tag" >/dev/null 2>&1; then
    warn "Release $tag already exists — skipping"
    continue
  fi

  notes_file="$(mktemp)"
  {
    extract_notes "$tag"
    printf '\n---\n\n'
    printf 'Full changelog: [CHANGELOG.md](https://github.com/nickjlamb/PosterLens/blob/main/CHANGELOG.md)\n'
  } > "$notes_file"

  if [[ ! -s "$notes_file" ]]; then
    warn "No changelog section found for $tag — skipping"
    rm -f "$notes_file"
    continue
  fi

  title="PosterLens ${tag#v}"
  args=(release create "$tag" --title "$title" --notes-file "$notes_file")
  [[ "$tag" != "$LATEST_TAG" ]] && args+=(--latest=false)

  info "Creating release $tag"
  if $DRY_RUN; then
    printf '  \033[2mwould run:\033[0m gh %s\n' "${args[*]}"
    printf '  \033[2m--- notes preview ---\033[0m\n'
    sed 's/^/  /' "$notes_file" | head -20
    printf '  \033[2m---------------------\033[0m\n'
  else
    gh "${args[@]}"
    ok "Released $tag"
  fi
  rm -f "$notes_file"
done

echo
if $DRY_RUN; then
  ok "Dry run complete. Re-run without --dry-run to publish."
else
  ok "Done. https://github.com/nickjlamb/PosterLens/releases"
fi
