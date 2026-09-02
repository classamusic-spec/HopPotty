#!/usr/bin/env bash
# Verifies that every illustration key referenced by the content layer has a
# source drawing on disk.
#
# Without this, a missing drawing is invisible until someone opens the app and
# sees a placeholder — and placeholders are easy to stop noticing. Run it in CI.
#
# The key list itself lives in `Scripts/art-keys.sh`, shared with
# `build-assets.sh`. This script asks "does every key have a drawing?"; that one
# puts exactly those drawings in the catalog. Two greps for the same contract
# would eventually disagree, and the failure that produced would be a picture
# that exists on disk, passes this check, and still draws a placeholder.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=Scripts/art-keys.sh
source "$ROOT/Scripts/art-keys.sh"

missing=0
found=0
while read -r dir asset; do
  [[ -n "$asset" ]] || continue
  if [[ -f "$ROOT/Art/$dir/$asset.svg" ]]; then
    found=$((found + 1))
  else
    echo "MISSING: Art/$dir/$asset.svg"
    missing=$((missing + 1))
  fi
done < <(art_keys)

echo "----"
echo "art keys resolved: $found   missing: $missing"
[[ $missing -eq 0 ]]
