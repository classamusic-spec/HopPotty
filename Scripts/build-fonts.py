#!/usr/bin/env python3
"""Instances the app's static font faces from the variable sources.

## Why this exists

`Scripts/fonts/` holds the two variable fonts the render harness embeds:
Fredoka and Nunito, both SIL Open Font License. The app used to ship neither —
it drew the system font's rounded design as a stand-in — which meant every
screen in the app was set in a different typeface from the design render that
specified it.

The app now ships the same faces. It cannot ship the variable files directly,
because **their weight axis defaults to the lightest instance**: Fredoka's
`wght` runs 300–700 and defaults to 300, Nunito's runs 200–1000 and defaults to
200. `Font.custom("Fredoka", size:)` resolves that default, so bundling the
variable file would render every heading Light. A browser avoids this because
CSS declares the axis range; iOS has no equivalent for a plain `Font.custom`.

So this writes one static face per weight the type scale actually asks for.

    python3 Scripts/build-fonts.py           regenerate
    python3 Scripts/build-fonts.py --check   verify, change nothing

Requires `fonttools` (pip install fonttools). The `--check` path does not:
`Scripts/check-fonts.py` verifies the shipped faces with no dependencies, and
that is what CI runs.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Scripts", "fonts")
OUT = os.path.join(ROOT, "HopPotty", "Resources", "Fonts")

# The weights `HopTypography` asks for, and nothing else. Fredoka's axis stops
# at 700, so the scale's `heavy` (800) clamps to Bold — which is exactly what
# the render harness gets from its `font-weight: 300 700` face, so the app and
# the render land on the same instance rather than quietly diverging.
JOBS = [
    ("Fredoka.ttf", "Fredoka", {"wght": 600, "wdth": 100}, "SemiBold"),
    ("Fredoka.ttf", "Fredoka", {"wght": 700, "wdth": 100}, "Bold"),
    ("Nunito.ttf", "Nunito", {"wght": 400}, "Regular"),
    ("Nunito.ttf", "Nunito", {"wght": 500}, "Medium"),
    ("Nunito.ttf", "Nunito", {"wght": 600}, "SemiBold"),
    ("Nunito.ttf", "Nunito", {"wght": 700}, "Bold"),
    ("Nunito.ttf", "Nunito", {"wght": 800}, "ExtraBold"),
]


def main() -> int:
    check = "--check" in sys.argv
    try:
        from fontTools.ttLib import TTFont
        from fontTools.varLib import instancer
    except ImportError:
        print("build-fonts: needs fonttools — pip install fonttools", file=sys.stderr)
        return 1

    os.makedirs(OUT, exist_ok=True)
    problems = 0
    total = 0

    for src_name, family, axes, style in JOBS:
        src = os.path.join(SRC, src_name)
        if not os.path.exists(src):
            print(f"build-fonts: missing source {src}", file=sys.stderr)
            problems += 1
            continue

        font = TTFont(src)
        inst = instancer.instantiateVariableFont(
            font, axes, updateFontNames=True, inplace=False
        )
        dest = os.path.join(OUT, f"{family}-{style}.ttf")
        post = inst["name"].getDebugName(6)

        if check:
            if not os.path.exists(dest):
                print(f"MISSING: {family}-{style}.ttf")
                problems += 1
            continue

        inst.save(dest)
        total += os.path.getsize(dest)
        print(f"  {family}-{style}.ttf  postscript={post}  {os.path.getsize(dest) // 1024} KB")

    if check:
        print(f"----\nfaces checked: {len(JOBS)}   problems: {problems}")
    else:
        print(f"----\nwrote {len(JOBS)} faces, {total // 1024} KB total")
        print("run Scripts/check-fonts.py to verify they match the app's declarations")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
