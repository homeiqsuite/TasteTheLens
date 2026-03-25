#!/bin/bash
# version-bump.sh — Increment the app marketing version and create a release branch + git tag
#
# Usage:
#   ./Scripts/version-bump.sh patch   # 1.0.0 → 1.0.1
#   ./Scripts/version-bump.sh minor   # 1.0.0 → 1.1.0
#   ./Scripts/version-bump.sh major   # 1.0.0 → 2.0.0
#
# This script:
#   1. Must be run from the development branch (clean working tree)
#   2. Reads the current version from Config/Version.xcconfig
#   3. Increments the specified component
#   4. Creates and checks out release/vX.X.X from development
#   5. Writes the new version back and commits it
#   6. Creates an annotated git tag

set -euo pipefail

# Resolve project root (parent of Scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/Taste The Lens/Config/Version.xcconfig"

# Validate arguments
BUMP_TYPE="${1:-}"
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
    echo "Usage: $0 <major|minor|patch>"
    echo ""
    echo "  major  — Breaking changes (1.2.3 → 2.0.0)"
    echo "  minor  — New features (1.2.3 → 1.3.0)"
    echo "  patch  — Bug fixes (1.2.3 → 1.2.4)"
    exit 1
fi

# Must be on development branch
CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "development" ]]; then
    echo "Error: Must be run from the development branch (currently on '$CURRENT_BRANCH')."
    exit 1
fi

# Check for uncommitted changes
if ! git -C "$PROJECT_ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
    echo "Error: You have uncommitted changes. Commit or stash them first."
    echo "   This keeps version tags clean and tied to specific commits."
    exit 1
fi

# Read current version from Version.xcconfig
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Error: $VERSION_FILE not found"
    exit 1
fi

CURRENT_VERSION=$(grep 'MARKETING_VERSION' "$VERSION_FILE" | sed 's/.*= *//' | tr -d '[:space:]')

if [[ -z "$CURRENT_VERSION" ]]; then
    echo "Error: Could not read MARKETING_VERSION from $VERSION_FILE"
    exit 1
fi

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Default to 0 if not present
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"

# Increment
case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
RELEASE_BRANCH="release/v$NEW_VERSION"

echo "Version bump: $CURRENT_VERSION -> $NEW_VERSION ($BUMP_TYPE)"

# Check release branch doesn't already exist
if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH"; then
    echo "Error: Branch '$RELEASE_BRANCH' already exists."
    exit 1
fi

# Create and checkout release branch from development
cd "$PROJECT_ROOT"
git checkout -b "$RELEASE_BRANCH"
echo "Created and checked out $RELEASE_BRANCH"

# Write new version to Version.xcconfig
cat > "$VERSION_FILE" << EOF
// App Version — Single source of truth
// Use Scripts/version-bump.sh to increment (major, minor, or patch)
MARKETING_VERSION = $NEW_VERSION
EOF

echo "Updated $VERSION_FILE"

# Git commit and tag
git add "$VERSION_FILE"
git commit -m "Bump version to $NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

echo "Created git commit and tag v$NEW_VERSION"
echo ""
echo "To push the release branch and tag to remote:"
echo "  git push origin $RELEASE_BRANCH"
echo "  git push origin v$NEW_VERSION"
