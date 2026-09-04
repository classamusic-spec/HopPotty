#!/usr/bin/env python3
"""Verifies the app can actually draw the type scale it declares.

## Why this exists

HopPotty has already shipped one whole class of this bug: `Art/` held a hundred
drawings that no key reached, so the app silently drew placeholders and nothing
said so. Fonts fail the same way and even more quietly — a `Font.custom` with a
name iOS cannot resolve does not throw, does not warn, and does not draw a
placeholder. It falls back to the system font, which looks *almost right*, so
the failure is invisible in review and obvious only to whoever opens the app.

Three things have to agree, and each is edited in a different file by a
different kind of change:

  1. `HopFontFamily.postScriptName(for:)` — the name the code asks for
  2. `HopPotty/Resources/Fonts/*.ttf`     — the face on disk
  3. `Info.plist` `UIAppFonts`            — the file iOS is told to register

This reads all three and fails if they disagree. It also reads the PostScript
name out of each TTF's own name table, because a file called `Nunito-Bold.ttf`
that internally calls itself something else resolves to nothing at runtime.

No third-party dependency: CI runs this, and it parses the name table directly
so it cannot be defeated by a missing `pip install`.

    python3 Scripts/check-fonts.py
"""
import os
import plistlib
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_DIR = os.path.join(ROOT, "HopPotty", "Resources", "Fonts")
PLIST = os.path.join(ROOT, "HopPotty", "App", "Info.plist")
FAMILY_SWIFT = os.path.join(
    ROOT, "HopPottyKit", "Sources", "HopPottyDesignTokens", "HopTypeScale.swift"
)


def postscript_name(path):
    """Name ID 6 from the TTF name table, which is what CoreText resolves."""
    with open(path, "rb") as handle:
        data = handle.read()
    if len(data) < 12:
        return None
    count = struct.unpack(">H", data[4:6])[0]
    table = None
    for index in range(count):
        offset = 12 + 16 * index
        if data[offset : offset + 4] == b"name":
            table = struct.unpack(">II", data[offset + 8 : offset + 16])
            break
    if table is None:
        return None
    start, _ = table
    fmt, records, string_offset = struct.unpack(">HHH", data[start : start + 6])
    for index in range(records):
        rec = start + 6 + 12 * index
        platform, encoding, _lang, name_id, length, off = struct.unpack(
            ">HHHHHH", data[rec : rec + 12]
        )
        if name_id != 6:
            continue
        begin = start + string_offset + off
        raw = data[begin : begin + length]
        # Platform 3 (Windows) is UTF-16BE; platform 1 (Mac) is single-byte.
        try:
            return raw.decode("utf-16-be" if platform == 3 else "latin-1").strip("\x00")
        except UnicodeDecodeError:
            continue
    return None


def names_the_code_asks_for():
    """Every string returned by `HopFontFamily.postScriptName(for:)`."""
    with open(FAMILY_SWIFT, encoding="utf-8") as handle:
        source = handle.read()
    start = source.find("func postScriptName(")
    if start < 0:
        print("check-fonts: postScriptName(for:) not found — did the token layer move?")
        return None
    end = source.find("\n    }", start)
    body = source[start:end]
    return sorted(set(re.findall(r'return "([^"]+)"', body)))


def main():
    problems = 0

    wanted = names_the_code_asks_for()
    if wanted is None:
        return 1

    # 2 — the faces on disk, by the name they call themselves
    on_disk = {}
    if os.path.isdir(FONT_DIR):
        for entry in sorted(os.listdir(FONT_DIR)):
            if entry.endswith(".ttf") or entry.endswith(".otf"):
                on_disk[entry] = postscript_name(os.path.join(FONT_DIR, entry))

    # 3 — what Info.plist registers
    with open(PLIST, "rb") as handle:
        declared = plistlib.load(handle).get("UIAppFonts", [])

    by_postscript = {ps: filename for filename, ps in on_disk.items() if ps}

    for name in wanted:
        filename = by_postscript.get(name)
        if filename is None:
            print(f"NO FACE: the code asks for '{name}', no bundled font reports that name")
            print("         iOS would silently fall back to the system font.")
            problems += 1
            continue
        if filename not in declared:
            print(f"NOT REGISTERED: {filename} ('{name}') is missing from Info.plist UIAppFonts")
            problems += 1

    for filename, ps in on_disk.items():
        if ps is None:
            print(f"UNREADABLE: {filename} has no PostScript name in its name table")
            problems += 1
        elif ps not in wanted:
            print(f"UNUSED: {filename} ('{ps}') is bundled but no style asks for it")
            problems += 1

    for filename in declared:
        if filename not in on_disk:
            print(f"DECLARED BUT ABSENT: Info.plist registers {filename}, which is not in Resources/Fonts")
            problems += 1

    # The OFL requires the licence travel with the font.
    for licence in ("OFL-Fredoka.txt", "OFL-Nunito.txt"):
        if not os.path.exists(os.path.join(FONT_DIR, licence)):
            print(f"LICENCE MISSING: {licence} must ship beside the fonts (SIL OFL 1.1)")
            problems += 1

    print("----")
    print(f"faces required: {len(wanted)}   bundled: {len(on_disk)}   problems: {problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
