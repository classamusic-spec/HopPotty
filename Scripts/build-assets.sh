#!/usr/bin/env bash
# Builds the app's illustration assets from `Art/` into the asset catalog.
#
# ## Why this exists
#
# `HopArtwork` draws `Image(key.assetName)`, and an asset catalog is the only
# thing that answers to a name. `Art/` held every drawing and the catalog held
# none of them, so *every* illustration in the app — the forty-one pond
# decorations, the quiz pictures, the eight game backdrops, every routine scene
# — resolved to `HopArtworkPlaceholder`. The app ran, nothing errored, and the
# whole product drew coloured blobs. That is exactly the kind of gap a build
# does not notice, so it gets a script and a check rather than a note in a doc.
#
# ## What goes in, and what does not
#
# Exactly the drawings a `HopIllustrationKey` can reach — the same set
# `check-art.sh` verifies, from `Scripts/art-keys.sh` so the two cannot drift.
# Nothing in the app names an asset any other way: there is not one literal
# `Image("…")` or `UIImage(named:)` in the app or the extensions, so a drawing
# no key reaches is unreachable, not merely unused.
#
# The rest of `Art/` is not app art. Hop's fifteen pose sheets feed the pose
# generator, the widget-face extraction and the screen renders — in the app he
# is drawn as SwiftUI shapes from the rig, not loaded as a picture. The
# `pond-base-*` layers feed the render harness; the app composes that scene in
# three canvases. Shipping them would put two megabytes of unreachable vectors
# in the bundle and quietly imply the app loads Hop from a file.
#
# ## Why generated rather than committed
#
# Same reason `HopPotty.xcodeproj` is: the SVGs are the source, and a hundred
# hand-maintained `Contents.json` files are a hundred chances for a drawing to
# be renamed and its entry not to be. `Scripts/bootstrap.sh` runs this, so the
# catalog is rebuilt from the art on every setup, and the generated directory is
# git-ignored. The three hand-authored entries — AccentColor, AppIcon,
# LaunchBackground — are not generated and sit beside it untouched.
#
# ## Why SVG rather than PNG
#
# Xcode compiles SVG into an asset catalog and preserves the vector data, so one
# file serves every scale, Hop stays sharp on an iPad at 320pt, and the app
# carries kilobytes instead of a hundred triples of PNGs. The art is drawn by
# our own generators from a narrow feature set — paths, ellipses, circles,
# lines, gradients, clips, opacity — which is well inside what `actool` accepts.
#
#   Scripts/build-assets.sh          rebuild
#   Scripts/build-assets.sh --check  verify the catalog matches Art/, change nothing
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=Scripts/art-keys.sh
source "$ROOT/Scripts/art-keys.sh"

ART="$ROOT/Art"
CATALOG="$ROOT/HopPotty/Resources/Assets.xcassets"
# One namespace-free folder, so `Image("routine-try")` still finds the drawing
# and the generated entries never mix with the three hand-authored ones.
OUT="$CATALOG/Illustrations"

check_only=0
[[ "${1:-}" == "--check" ]] && check_only=1

[[ -d "$ART" ]] || { echo "build-assets: no Art/ directory at $ART" >&2; exit 1; }

if [[ $check_only -eq 0 ]]; then
    rm -rf "$OUT"
    mkdir -p "$OUT"
    cat > "$OUT/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "Scripts/build-assets.sh",
    "version" : 1
  }
}
JSON
fi

built=0
problems=0
declare -a wanted=()

while read -r family name; do
    [[ -n "$name" ]] || continue
    svg="$ART/$family/$name.svg"
    wanted+=("$name")
    if [[ ! -f "$svg" ]]; then
        # `check-art.sh` is the script that reports this properly, with the key
        # that asked for it. Here it is only a reason not to write an imageset
        # pointing at a file that is not there.
        echo "build-assets: no drawing for $family/$name.svg — see Scripts/check-art.sh"
        problems=$((problems + 1))
        continue
    fi
    set="$OUT/$name.imageset"
    if [[ $check_only -eq 1 ]]; then
        if [[ ! -f "$set/$name.svg" ]]; then
            echo "MISSING FROM CATALOG: $name"
            problems=$((problems + 1))
        elif ! cmp -s "$svg" "$set/$name.svg"; then
            echo "STALE IN CATALOG: $name"
            problems=$((problems + 1))
        fi
    else
        mkdir -p "$set"
        cp "$svg" "$set/$name.svg"
        # `preserves-vector-representation` is what keeps it a vector at runtime
        # rather than a raster baked at whatever size Xcode felt like.
        cat > "$set/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$name.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "Scripts/build-assets.sh",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
JSON
    fi
    built=$((built + 1))
done < <(art_keys)

# Two families claiming one name would silently overwrite each other, and the
# loser would draw a placeholder with nothing to say why.
dupes="$(printf '%s\n' "${wanted[@]}" | sort | uniq -d)"
if [[ -n "$dupes" ]]; then
    echo "build-assets: two keys resolve to the same asset name:" >&2
    printf '  %s\n' $dupes >&2
    exit 1
fi

if [[ $check_only -eq 1 ]]; then
    if [[ ! -d "$OUT" ]]; then
        echo "MISSING: the generated catalog does not exist — run Scripts/build-assets.sh"
        problems=$((problems + 1))
    else
        # Entries no key reaches any more. An unreachable asset in the bundle is
        # dead weight, and more often it is the fossil of a rename that half
        # happened.
        while IFS= read -r set; do
            name="$(basename "$set" .imageset)"
            printf '%s\n' "${wanted[@]}" | grep -qxF "$name" || {
                echo "ORPHAN IN CATALOG: $name — no key reaches it"
                problems=$((problems + 1))
            }
        done < <(find "$OUT" -maxdepth 1 -name '*.imageset' | sort)
    fi
    echo "----"
    echo "catalog entries checked: $built   problems: $problems"
else
    echo "----"
    echo "illustration assets: $built   problems: $problems"
fi
[[ $problems -eq 0 ]]
