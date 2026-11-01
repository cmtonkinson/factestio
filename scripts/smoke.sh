#!/usr/bin/env bash
# Drives a real headless Factorio through the example scenarios `activate`
# scaffolds, covering what the specs mock: the scenario's tick scheduler, saves,
# CLI flags, script-output paths. Headless Factorio is Linux x86-64 only.
#
# CI runs this directly on its runner. Locally, run `make smoke`, which runs it
# with --container in a throwaway Linux container so your own Factorio install,
# mod list and symlinks are never touched.
set -euo pipefail

# Bump alongside info.json's factorio_version; the doctor step fails on a mismatch.
FACTORIO_VERSION="${FACTORIO_VERSION:-2.1.24}"

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--container" ]]; then
  # Provide what a GitHub runner already has, then run from a copy so the
  # container's Linux toolchain never lands in the host's .hererocks/.
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq build-essential curl git jq python3-venv unzip xz-utils >/dev/null
  python3 -m venv /opt/hererocks
  /opt/hererocks/bin/pip install -q hererocks
  export PATH="/opt/hererocks/bin:$PATH" HEREROCKS=hererocks
  mkdir -p /work
  tar -C "$PWD" --exclude=.hererocks --exclude=tmp --exclude=root-save.zip -cf - . | tar -C /work -xf -
  exec /work/scripts/smoke.sh
fi

# Factorio is unpacked to ~/.factorio, the Linux default factestio detects.
if [[ -e "$HOME/.factorio" ]]; then
  echo "Error: $HOME/.factorio already exists; refusing to overwrite it. Run \`make smoke\` instead." >&2
  exit 1
fi

root="$PWD"
make deps
export PATH="$root/.hererocks/bin:$PATH"

# Headless builds need no login.
curl -fsSL "https://factorio.com/get-download/${FACTORIO_VERSION}/headless/linux64" | tar -xJ -C "$HOME"
mv "$HOME/factorio" "$HOME/.factorio"
mkdir -p "$HOME/.factorio/mods"

bin/factestio doctor

mod="$(mktemp -d)/factestio-smoke"
mkdir -p "$mod"
jq '{name: "factestio-smoke", version: "0.0.1", title: "factestio smoke", author: "factestio", factorio_version}' \
  info.json >"$mod/info.json"
bin/factestio activate "$mod"

log="$(mktemp)"
(cd "$mod" && "$root/bin/factestio") | tee "$log"
# A run that discovers no scenarios also exits 0.
grep -qE '^Passed: [1-9]' "$log"
