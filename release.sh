#!/usr/bin/env zsh
set -euo pipefail

# NOTE: this script is non-portable / macOS-specific (mostly due to `sed`
# syntax) so while factestio is meant to offer Linux support, this maintainer
# tooling makes no such effort at this time.

HOMEBREW_TAP_DIR="${HOMEBREW_TAP_DIR:-$HOME/repo/homebrew-tap}"
FORMULA="$HOMEBREW_TAP_DIR/Formula/factestio.rb"

usage() {
  echo "Usage: $0 [--use-last-commit] --patch|--minor|--major" >&2
  exit 1
}

replace_formula_field() {
  local file="$1"
  local key="$2"
  local value="$3"

  sed -i '' "s#^  ${key} '.*'#  ${key} '${value}'#" "$file"
}

latest_tag_for_bump() {
  local major="$1"
  local minor="$2"
  local bump="$3"
  local pattern

  case "$bump" in
  patch) pattern="v${major}.${minor}.*" ;;
  minor) pattern="v${major}.*" ;;
  major) pattern="v*" ;;
  *)
    echo "Error: unsupported bump level '$bump'" >&2
    exit 1
    ;;
  esac

  git tag --list "$pattern" --sort=-version:refname | head -1
}

# Parse args
USE_LAST_COMMIT=false
BUMP=''
for arg in "$@"; do
  case "$arg" in
  --use-last-commit) USE_LAST_COMMIT=true ;;
  --patch | --minor | --major)
    [[ -n "$BUMP" ]] && {
      echo "Error: specify exactly one of --patch, --minor, --major" >&2
      exit 1
    }
    BUMP="${arg#--}"
    ;;
  *) usage ;;
  esac
done
[[ -z "$BUMP" ]] && usage

# Abort on dirty tree unless --use-last-commit
if [[ "$USE_LAST_COMMIT" == false ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: working tree is dirty. Commit your changes or pass --use-last-commit." >&2
    exit 1
  fi
fi

# Derive next version from latest tag
LATEST=$(git tag --list 'v*' --sort=-version:refname | head -1)
if [[ -z "$LATEST" ]]; then
  CURRENT="0.0.0"
else
  CURRENT="${LATEST#v}"
fi

IFS='.' read -r MAJOR MINOR PATCH <<<"$CURRENT"

LAST_LEVEL_TAG=$(latest_tag_for_bump "$MAJOR" "$MINOR" "$BUMP")
if [[ -n "$LAST_LEVEL_TAG" ]]; then
  COMMITS_SINCE_LEVEL_TAG=$(git rev-list --count "${LAST_LEVEL_TAG}..HEAD")
  if [[ "$COMMITS_SINCE_LEVEL_TAG" -eq 0 ]]; then
    echo "Error: no commits since ${LAST_LEVEL_TAG}; refusing ${BUMP} release." >&2
    exit 1
  fi
fi

case "$BUMP" in
major)
  MAJOR=$((MAJOR + 1))
  MINOR=0
  PATCH=0
  ;;
minor)
  MINOR=$((MINOR + 1))
  PATCH=0
  ;;
patch) PATCH=$((PATCH + 1)) ;;
esac

VERSION="v${MAJOR}.${MINOR}.${PATCH}"
echo "Releasing $VERSION ..."

# Bump version in info.json and rockspec before tagging
VER="${VERSION#v}"
jq --indent 2 --arg version "$VER" '.version = $version' info.json >info.json.tmp
mv info.json.tmp info.json
echo "  info.json -> $VER"

ROCKSPEC_OLD=$(echo factestio-*.rockspec)
ROCKSPEC_NEW="factestio-${VER}-0.rockspec"
sed -i '' "s/^version = .*/version = \"${VER}-0\"/" "$ROCKSPEC_OLD"
if [[ "$ROCKSPEC_OLD" != "$ROCKSPEC_NEW" ]]; then
  git mv "$ROCKSPEC_OLD" "$ROCKSPEC_NEW"
fi
echo "  rockspec -> $ROCKSPEC_NEW"

git add info.json "$ROCKSPEC_NEW"
git commit -m "Release $VERSION"

# Tag and push — GitHub Actions (or just the push) creates the release
git tag "$VERSION"
git push origin main "$VERSION"

# Create GitHub release from the tag
gh release create "$VERSION" \
  --title "$VERSION" \
  --generate-notes

# Compute sha256 of the source tarball GitHub generates
TARBALL_URL="https://github.com/cmtonkinson/factestio/archive/refs/tags/${VERSION}.tar.gz"
echo "Fetching tarball for sha256: $TARBALL_URL"
SHA256=''
for attempt in {1..10}; do
  SHA256=$(curl -fsSL "$TARBALL_URL" 2>/dev/null | shasum -a 256 | awk '{print $1}')
  [[ -n "$SHA256" && "$SHA256" != "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]] && break
  echo "  Attempt $attempt failed, retrying in 3s..."
  sleep 3
done
if [[ -z "$SHA256" || "$SHA256" == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]]; then
  echo "Error: could not fetch tarball after 10 attempts." >&2
  exit 1
fi
echo "sha256: $SHA256"

# Update the Homebrew formula
if [[ ! -f "$FORMULA" ]]; then
  echo "Error: formula not found at $FORMULA" >&2
  exit 1
fi

# Replace or insert url/sha256/version in formula (works whether head-only or versioned)
replace_formula_field "$FORMULA" "url" "$TARBALL_URL"
replace_formula_field "$FORMULA" "sha256" "$SHA256"
replace_formula_field "$FORMULA" "version" "${VERSION#v}"
sed -i '' "/^  head '/d" "$FORMULA"
echo "Updated formula: $FORMULA"

ruby -c "$FORMULA" >/dev/null || {
  echo "Error: formula syntax check failed" >&2
  exit 1
}

# Commit and push the tap
cd "$HOMEBREW_TAP_DIR"
git add Formula/factestio.rb
git commit -m "factestio ${VERSION}"
git push

echo ""
echo "Done. Install with:"
echo "  brew update && brew install cmtonkinson/tap/factestio"
