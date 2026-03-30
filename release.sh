#!/usr/bin/env zsh
set -euo pipefail

HOMEBREW_TAP_DIR="${HOMEBREW_TAP_DIR:-$HOME/repo/homebrew-tap}"
FORMULA="$HOMEBREW_TAP_DIR/Formula/factestio.rb"

usage() {
  echo "Usage: $0 [--use-last-commit] --patch|--minor|--major" >&2
  exit 1
}

# Parse args
USE_LAST_COMMIT=false
BUMP=''
for arg in "$@"; do
  case "$arg" in
    --use-last-commit) USE_LAST_COMMIT=true ;;
    --patch|--minor|--major) [[ -n "$BUMP" ]] && { echo "Error: specify exactly one of --patch, --minor, --major" >&2; exit 1; }; BUMP="${arg#--}" ;;
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

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

VERSION="v${MAJOR}.${MINOR}.${PATCH}"
echo "Releasing $VERSION ..."

# Tag and push — GitHub Actions (or just the push) creates the release
git tag "$VERSION"
git push origin "$VERSION"

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
  [[ -n "$SHA256" && "$SHA256" != "da39a3ee5e6b4b0d3255bfef95601890afd80709" ]] && break
  echo "  Attempt $attempt failed, retrying in 3s..."
  sleep 3
done
if [[ -z "$SHA256" || "$SHA256" == "da39a3ee5e6b4b0d3255bfef95601890afd80709" ]]; then
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
python3 - "$FORMULA" "$VERSION" "${VERSION#v}" "$SHA256" "$TARBALL_URL" <<'EOF'
import re, sys

formula_path, tag, ver, sha256, url = sys.argv[1:]

with open(formula_path) as f:
  src = f.read()

# Remove existing head line if present
src = re.sub(r'\n\s*head\s+"[^"]*"[^\n]*\n', '\n', src)

# Remove existing url/sha256/version lines if present
src = re.sub(r'\n\s*url\s+"https://github\.com/cmtonkinson/factestio/archive[^"]*"[^\n]*\n', '\n', src)
src = re.sub(r'\n\s*sha256\s+"[a-f0-9]+"[^\n]*\n', '\n', src)
src = re.sub(r'\n\s*version\s+"[^"]*"[^\n]*\n', '\n', src)

# Insert after the license line
insert = f'\n  url "{url}"\n  sha256 "{sha256}"\n  version "{ver}"'
src = re.sub(r'(\n\s*license\s+"[^"]*")', r'\1' + insert, src)

with open(formula_path, 'w') as f:
  f.write(src)

print(f"Updated formula: {formula_path}")
EOF

ruby -c "$FORMULA" > /dev/null || { echo "Error: formula syntax check failed" >&2; exit 1; }

# Commit and push the tap
cd "$HOMEBREW_TAP_DIR"
git add Formula/factestio.rb
git commit -m "factestio ${VERSION}"
git push

echo ""
echo "Done. Install with:"
echo "  brew update && brew install cmtonkinson/tap/factestio"
