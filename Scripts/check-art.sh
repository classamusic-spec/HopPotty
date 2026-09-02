#!/usr/bin/env bash
# Verifies that every illustration key referenced by the content layer has a
# source drawing on disk.
#
# Without this, a missing drawing is invisible until someone opens the app and
# sees a placeholder — and placeholders are easy to stop noticing. Run it in CI.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTENT="$ROOT/HopPottyKit/Sources/HopPottyCore/Content"

missing=0
found=0
while IFS= read -r key; do
  family="${key%%.*}"
  rest="${key#*.}"
  asset="${rest//./-}"
  case "$family" in
    scene) dir="scenes" ;;
    icon)  dir="icons" ;;
    character) dir="character" ;;
    pond)  dir="pond" ;;
    *) echo "UNKNOWN FAMILY: $key"; missing=$((missing + 1)); continue ;;
  esac
  if [[ -f "$ROOT/Art/$dir/$asset.svg" ]]; then
    found=$((found + 1))
  else
    echo "MISSING: $key  ->  Art/$dir/$asset.svg"
    missing=$((missing + 1))
  fi
# Two or more segments after the family, so a sprite key like
# "icon.games.fly.blue" is checked rather than silently skipped.
done < <(grep -rhoE '"(scene|icon|character)(\.[A-Za-z0-9]+){2,}"' "$CONTENT" | tr -d '"' | sort -u)

# Pond decorations are checked separately, because their keys are *derived*
# rather than written down: `HopIllustrationKey.pondItem(_:)` builds
# "pond.<PondItemID>" at the call site, so the grep above cannot see them. That
# is not a hypothetical gap — every one of the forty-one decorations resolved to
# a placeholder for a while because the generator wrote `item-<id>.svg` and the
# loader asked for `<id>.svg`, and nothing said so.
POND_MODEL="$ROOT/HopPottyKit/Sources/HopPottyCore/Models/PondItem.swift"
if [[ -f "$POND_MODEL" ]]; then
  while IFS= read -r id; do
    if [[ -f "$ROOT/Art/pond/$id.svg" ]]; then
      found=$((found + 1))
    else
      echo "MISSING: pond.$id  ->  Art/pond/$id.svg"
      missing=$((missing + 1))
    fi
  done < <(awk '/public enum PondItemID/,/^}/' "$POND_MODEL" \
    | grep -E '^\s*case ' \
    | sed -E 's/^[[:space:]]*case //; s/[[:space:]]//g' \
    | tr ',' '\n' \
    | grep -E '^[A-Za-z][A-Za-z0-9]*$' \
    | sort -u)
fi

echo "----"
echo "art keys resolved: $found   missing: $missing"
[[ $missing -eq 0 ]]
