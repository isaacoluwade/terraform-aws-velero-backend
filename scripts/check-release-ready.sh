#!/usr/bin/env bash
# Validates every release prerequisite. Exits non-zero if any fail.
#
# Usage: ./scripts/check-release-ready.sh
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(cat VERSION | tr -d '[:space:]')"
TAG="v${VERSION}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# 1. VERSION file is non-empty and looks like SemVer.
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "VERSION ($VERSION) must look like MAJOR.MINOR.PATCH"
fi

# 2. CHANGELOG has an entry for the current VERSION.
if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
  fail "CHANGELOG.md has no entry for $VERSION"
fi

# 3. Working tree clean.
if [ -n "$(git status --porcelain)" ]; then
  fail "Working tree has uncommitted changes"
fi

# 4. On main branch.
branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" != "main" ]; then
  fail "Must release from main; currently on $branch"
fi

# 5. No tag already exists with this version.
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  fail "Tag $TAG already exists"
fi

# 6. Static + unit tests pass locally.
echo "Running terraform fmt..."
terraform fmt -check -recursive

echo "Running terraform test..."
terraform test

echo "OK: ready to release $TAG"
