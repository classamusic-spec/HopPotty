#!/usr/bin/env bash
#
# bootstrap.sh — turn a fresh clone into an Xcode project you can open.
#
# HopPotty.xcodeproj is a build artefact, not a source file. It is generated from
# project.yml by XcodeGen, it is git-ignored, and deleting it costs nothing. Run
# this script after cloning, after switching branches, and after anyone adds,
# moves or renames a file — the project is a function of the file system, so it
# goes stale the moment the file system changes.
#
# Safe to run as many times as you like. It never overwrites Config/Secrets.xcconfig,
# it never touches your working tree, and it regenerates the project from scratch
# every time, so there is no state to get wrong.
#
# Usage:
#   Scripts/bootstrap.sh            generate the project and print the manual steps
#   Scripts/bootstrap.sh --check    run the configuration checks only; generate nothing
#   Scripts/bootstrap.sh --help

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; OFF=""
fi

step  () { printf '\n%s==>%s %s%s%s\n' "$BLUE" "$OFF" "$BOLD" "$1" "$OFF"; }
ok    () { printf '    %sok%s   %s\n' "$GREEN" "$OFF" "$1"; }
warn  () { printf '    %swarn%s %s\n' "$YELLOW" "$OFF" "$1"; }
die   () {
    printf '\n%s%sbootstrap failed:%s %s\n' "$BOLD" "$RED" "$OFF" "$1" >&2
    shift || true
    for line in "$@"; do printf '  %s\n' "$line" >&2; done
    printf '\n'
    exit 1
}

CHECK_ONLY=0
case "${1:-}" in
    --check) CHECK_ONLY=1 ;;
    --help|-h) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    "") : ;;
    *) die "unknown argument: $1" "Run Scripts/bootstrap.sh --help." ;;
esac

# ---------------------------------------------------------------------------
step "Environment"
# ---------------------------------------------------------------------------

case "$(uname -s)" in
    Darwin) ok "macOS $(sw_vers -productVersion 2>/dev/null || echo '?')" ;;
    *)      warn "not macOS. The project can be generated here, but only macOS with Xcode can build it." ;;
esac

if command -v xcodebuild >/dev/null 2>&1; then
    ok "$(xcodebuild -version 2>/dev/null | head -1)"
    # Swift 6 language mode and the iOS 17 SDK. Xcode 16 is the floor; the exact
    # version is not enforced here because a newer Xcode is always fine and an
    # older one fails loudly at the first `SWIFT_VERSION = 6.0` build.
else
    warn "xcodebuild not found. Install Xcode 16 or newer from the App Store before building."
fi

if command -v swift >/dev/null 2>&1; then
    ok "$(swift --version 2>&1 | head -1)"
else
    warn "no swift toolchain on PATH — 'swift test' in HopPottyKit/ will not run here."
fi

# ---------------------------------------------------------------------------
step "Local signing configuration"
# ---------------------------------------------------------------------------

if [ -f Config/Secrets.xcconfig ]; then
    ok "Config/Secrets.xcconfig exists (left untouched)"
else
    cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
    ok "created Config/Secrets.xcconfig from the template"
fi

TEAM="$(sed -n 's/^[[:space:]]*HOPPOTTY_DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' Config/Secrets.xcconfig | head -1 | tr -d '[:space:]')"
if [ -z "$TEAM" ]; then
    warn "HOPPOTTY_DEVELOPMENT_TEAM is empty in Config/Secrets.xcconfig — see the manual steps below"
else
    ok "development team configured (${#TEAM} characters)"
fi

if git rev-parse --git-dir >/dev/null 2>&1 && git ls-files --error-unmatch Config/Secrets.xcconfig >/dev/null 2>&1; then
    die "Config/Secrets.xcconfig is tracked by git." \
        "It must never be committed. Fix with:" \
        "    git rm --cached Config/Secrets.xcconfig"
fi

# ---------------------------------------------------------------------------
step "Configuration checks"
# ---------------------------------------------------------------------------

if ! Scripts/verify-config.sh; then
    die "the configuration checks above failed." \
        "Every one of them catches something that is invisible at build time and" \
        "total at runtime. Fix them before generating the project."
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
    printf '\n%sChecks only — nothing was generated.%s\n' "$GREEN" "$OFF"
    exit 0
fi

# ---------------------------------------------------------------------------
step "XcodeGen"
# ---------------------------------------------------------------------------

if ! command -v xcodegen >/dev/null 2>&1; then
    die "XcodeGen is not installed." \
        "HopPotty.xcodeproj is generated from project.yml; there is no project to open without it." \
        "" \
        "Install it with one of:" \
        "    brew install xcodegen                       # Homebrew" \
        "    mint install yonaskolb/XcodeGen             # Mint" \
        "    make install                                # from a clone of github.com/yonaskolb/XcodeGen" \
        "" \
        "Then run Scripts/bootstrap.sh again."
fi

XCODEGEN_VERSION="$(xcodegen --version 2>/dev/null | tr -dc '0-9.\n' | tr -d '\n')"
REQUIRED="$(sed -n 's/^[[:space:]]*minimumXcodeGenVersion:[[:space:]]*"\{0,1\}\([0-9.]*\)"\{0,1\}.*/\1/p' project.yml | head -1)"
ok "xcodegen ${XCODEGEN_VERSION:-unknown} (project.yml requires >= ${REQUIRED:-?})"

# Sort-based comparison: correct for the dotted numeric versions XcodeGen uses.
if [ -n "$XCODEGEN_VERSION" ] && [ -n "$REQUIRED" ]; then
    LOWEST="$(printf '%s\n%s\n' "$XCODEGEN_VERSION" "$REQUIRED" | sort -V | head -1)"
    if [ "$LOWEST" != "$REQUIRED" ] && [ "$XCODEGEN_VERSION" != "$REQUIRED" ]; then
        die "XcodeGen $XCODEGEN_VERSION is older than the required $REQUIRED." \
            "project.yml uses 'optional: true' on the source files shared by all four" \
            "targets, which older versions reject. Upgrade with 'brew upgrade xcodegen'."
    fi
fi

# ---------------------------------------------------------------------------
step "Building the illustration assets"
# ---------------------------------------------------------------------------

# `Art/` is the source; the asset catalog is what `Image(_:)` can actually find.
# Generated rather than committed for the same reason the project file is — a
# hundred hand-maintained Contents.json files are a hundred chances for a
# drawing to be renamed and its entry not to be. Skipping this step is not
# cosmetic: without it every illustration in the app draws a placeholder, and
# nothing errors to say so.
if ! "$(dirname "$0")/build-assets.sh"; then
    die "Could not build the illustration assets from Art/." \
        "The error above says which drawing it objected to."
fi
ok "illustration assets built from Art/"

# The same failure mode as the assets above, one layer over: a face the app
# cannot resolve falls back to the system font silently, so the app looks
# almost right and nobody finds out until they open it.
if ! python3 "$(dirname "$0")/check-fonts.py"; then
    die "The bundled typefaces do not match what the app asks for." \
        "Scripts/build-fonts.py regenerates them from Scripts/fonts/."
fi
ok "bundled typefaces resolve"

# ---------------------------------------------------------------------------
step "Generating HopPotty.xcodeproj"
# ---------------------------------------------------------------------------

if ! xcodegen generate --spec project.yml --project .; then
    die "XcodeGen could not generate the project." \
        "The error above names the key or path it objected to. project.yml is the" \
        "only thing to fix — never edit the generated .xcodeproj."
fi

[ -d HopPotty.xcodeproj ] || die "XcodeGen reported success but HopPotty.xcodeproj does not exist."
ok "HopPotty.xcodeproj generated"

# ---------------------------------------------------------------------------
# What a human still has to do. None of this can be scripted: it all happens in
# Xcode's UI or in an Apple Developer account this machine may not be signed in
# to, and some of it waits on Apple.
# ---------------------------------------------------------------------------

cat <<MANUAL

$(printf '%s' "$BOLD")Generated. Now the parts no script can do.$(printf '%s' "$OFF")

  Read Docs/Entitlements.md before starting — it has the citations for all of
  this and the App Review notes. This is the short form.

$(printf '%s' "$BOLD")1. Team ID$(printf '%s' "$OFF")
   Put your ten-character Team ID in Config/Secrets.xcconfig:

       HOPPOTTY_DEVELOPMENT_TEAM = A1B2C3D4E5

   Find it at https://developer.apple.com/account under Membership details, or
   in Xcode: Settings > Accounts > your account > the Team ID column.
   That file is git-ignored and must stay that way.

$(printf '%s' "$BOLD")2. Bundle identifiers$(printf '%s' "$OFF")
   The four identifiers are placeholders under a domain nobody here owns:

       com.hoppotty                  the app
       com.hoppotty.monitor          Device Activity Monitor extension
       com.hoppotty.shieldconfig     Shield Configuration extension
       com.hoppotty.shieldaction     Shield Action extension

   To change them, edit HOPPOTTY_APP_BUNDLE_ID in Config/Base.xcconfig (or
   override it in Config/Secrets.xcconfig for a personal build) AND the matching
   literals in HopPotty/Services/ScreenTime/ScreenTimeIdentifiers.swift. Then run
   this script again — Scripts/verify-config.sh fails if the two disagree.

   Register all four App IDs in Certificates, Identifiers & Profiles, and enable
   Family Controls on each of the four. An extension whose App ID lacks the
   capability builds, installs, and then never shields anything.

$(printf '%s' "$BOLD")3. App Group$(printf '%s' "$OFF")
   Create ONE App Group and add all four App IDs to it:

       group.com.hoppotty

   (Identifiers > App Groups > +. It must begin with "group.".)
   This is the channel the extensions use to see the app's pause state. If it is
   missing or misspelled, nothing fails at build time: UserDefaults(suiteName:)
   returns nil, the container URL is unavailable, and shields stop coming down.

$(printf '%s' "$BOLD")4. Family Controls entitlement — start this today$(printf '%s' "$OFF")
   Development signing works as soon as the capability is enabled on the App IDs.
   DISTRIBUTION — TestFlight included — does not, and cannot be unblocked by
   anything in this repository:

     * Your Apple Developer $(printf '%s' "$BOLD")Account Holder$(printf '%s' "$OFF") must submit the request. Nobody else can.
     * Submit it once per App ID — the app AND each of the three extensions.
     * https://developer.apple.com/contact/request/family-controls-distribution/
       (or Identifiers > your identifier > Capability Requests)
     * Apple publishes no turnaround time. Submit on the day the App IDs exist,
       not when the app is finished.
     * When it is granted, open the info button beside the capability and check
       that Provisioning Support lists Development, Ad Hoc AND App Store. An
       approval that omits App Store distribution is a silent trap.

$(printf '%s' "$BOLD")5. Open it$(printf '%s' "$OFF")
       open HopPotty.xcodeproj

   Two schemes:
     HopPotty        real Screen Time. Needs a signed build on a physical device.
     HopPotty-Mock   in-memory fakes, chosen at compile time. Use this in the
                     Simulator, for UI tests and for screenshots. It proves
                     nothing about Screen Time.

   Whether Family Controls works in the Simulator at all is UNVERIFIED
   (Docs/ScreenTimeArchitecture.md §12.7). Do not build a test strategy on it.

$(printf '%s' "$BOLD")6. Tests$(printf '%s' "$OFF")
   The domain logic needs no Xcode and no simulator:

       cd HopPottyKit && swift test

   The app-layer tests need Xcode:

       xcodebuild test -scheme HopPotty-Mock -destination 'platform=iOS Simulator,name=iPhone 16'

MANUAL
