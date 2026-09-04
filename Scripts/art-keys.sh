#!/usr/bin/env bash
# The set of drawings the app can actually reach, from the content layer.
#
# Sourced by `check-art.sh` (does every key have a drawing?) and
# `build-assets.sh` (put exactly those drawings in the catalog). One
# implementation because the two questions are two ends of the same contract: a
# key with no drawing is a placeholder, and a drawing the catalog missed is the
# same placeholder from the other direction. Two greps drifting apart would let
# a file be in the answer to one question and not the other.
#
#   art_keys        prints "<family> <assetName>" per line, sorted, unique
#
# The rule it implements is `HopIllustrationKey.assetName`: drop the family
# segment, join the rest with hyphens. Case is preserved — asset catalogs are
# case-sensitive.

art_keys() {
    local root content
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    content="$root/HopPottyKit/Sources/HopPottyCore/Content"

    {
        # Written-down keys. Two or more segments after the family, so a sprite
        # key like "icon.games.fly.blue" is seen rather than silently skipped.
        #
        # `pond` is deliberately *not* in this list even though two written-down
        # keys draw from `Art/pond/`. This grep cannot tell an art key from a
        # copy key, and thirteen copy keys in this same directory begin
        # `pond.` — `pond.empty.title`, `pond.starCount.one` — so admitting the
        # family here would invent thirteen drawings that were never meant to
        # exist. The two backdrops are keyed `stage.` instead, which nothing else
        # in the content layer claims; `HopIllustrationKey.artDirectory` routes
        # the family back to `Art/pond/`, and this case statement agrees with it.
        grep -rhoE '"(scene|icon|character|stage)(\.[A-Za-z0-9]+){2,}"' "$content" \
            | tr -d '"' \
            | while IFS= read -r key; do
                local family="${key%%.*}" rest="${key#*.}"
                case "$family" in
                    scene) printf 'scenes %s\n' "${rest//./-}" ;;
                    icon) printf 'icons %s\n' "${rest//./-}" ;;
                    character) printf 'character %s\n' "${rest//./-}" ;;
                    stage) printf 'pond %s\n' "${rest//./-}" ;;
                esac
            done

        # Pond decorations, whose keys are *derived* rather than written down:
        # `HopIllustrationKey.pondItem(_:)` builds "pond.<PondItemID>" at the
        # call site, so no grep over the content layer can see them. That is not
        # a hypothetical gap — all forty-one resolved to placeholders for a
        # while because the generator wrote one name and the loader asked for
        # another, and nothing said so.
        local model="$root/HopPottyKit/Sources/HopPottyCore/Models/PondItem.swift"
        if [[ -f "$model" ]]; then
            awk '/public enum PondItemID/,/^}/' "$model" \
                | grep -E '^\s*case ' \
                | sed -E 's/^[[:space:]]*case //; s/[[:space:]]//g' \
                | tr ',' '\n' \
                | grep -E '^[A-Za-z][A-Za-z0-9]*$' \
                | sed 's/^/pond /'
        fi
    } | sort -u
}
