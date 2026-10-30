#!/usr/bin/env bash
# Copy content shared between the web and mobile apps. Run after editing it.
#   --check  fail if the copies differ (used in CI)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
pairs=("frontend/src/lib/terms.json:mobile/assets/terms.json")
for pair in "${pairs[@]}"; do
  src="$root/${pair%%:*}"; dst="$root/${pair##*:}"
  if [[ "${1:-}" == "--check" ]]; then
    cmp -s "$src" "$dst" || { echo "Out of sync: ${pair##*:} (run scripts/sync-shared.sh)"; exit 1; }
  else
    cp "$src" "$dst"; echo "synced ${pair##*:}"
  fi
done
