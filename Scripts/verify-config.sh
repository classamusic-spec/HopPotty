#!/usr/bin/env bash
#
# verify-config.sh — the checks that catch a silent misconfiguration.
#
# Everything here is a fact that is invisible at build time and total at runtime.
# An App Group identifier that differs between the entitlements and the code
# still compiles, still signs, still installs, and still launches — and then the
# extensions cannot see the app's state and a shield never comes down. A
# HOPPOTTY_DEBUG_TOOLS left in the Release configuration still ships, and takes
# the Potty Pause Lab with it.
#
# Runs on Linux, on macOS, in CI, with no Xcode and no XcodeGen: it is text
# comparison, nothing more. That is the point — it is the only part of the build
# configuration this repository can genuinely verify.
#
# Usage: Scripts/verify-config.sh
# Exit:  0 all checks passed  ·  1 at least one failure

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; BOLD=""; OFF=""
fi

FAILURES=0
WARNINGS=0

pass () { printf '  %sok%s   %s\n' "$GREEN" "$OFF" "$1"; }
fail () { printf '  %sFAIL%s %s\n' "$RED" "$OFF" "$1"; FAILURES=$((FAILURES + 1)); }
warn () { printf '  %swarn%s %s\n' "$YELLOW" "$OFF" "$1"; WARNINGS=$((WARNINGS + 1)); }
section () { printf '\n%s%s%s\n' "$BOLD" "$1" "$OFF"; }

# Read a build setting's raw (unexpanded) value from an xcconfig.
setting () {
    local file="$1" key="$2"
    sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$file" | head -1 | sed 's/[[:space:]]*$//'
}

# Read a Swift `static let NAME = "value"` string literal.
swift_literal () {
    local file="$1" name="$2"
    sed -n "s/.*static let ${name}[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -1
}

BASE=Config/Base.xcconfig
IDS=HopPotty/Services/ScreenTime/ScreenTimeIdentifiers.swift

# ---------------------------------------------------------------------------
section "Files the project definition points at"
# ---------------------------------------------------------------------------

for f in \
    project.yml \
    Config/Base.xcconfig Config/Debug.xcconfig Config/DebugMock.xcconfig Config/Release.xcconfig \
    Config/Secrets.example.xcconfig \
    HopPotty/App/Info.plist HopPotty/App/HopPotty.entitlements \
    HopPotty/Resources/HopPotty.storekit \
    Extensions/HopPottyDeviceActivityMonitor/Info.plist \
    Extensions/HopPottyDeviceActivityMonitor/HopPottyDeviceActivityMonitor.entitlements \
    Extensions/HopPottyShieldConfiguration/Info.plist \
    Extensions/HopPottyShieldConfiguration/HopPottyShieldConfiguration.entitlements \
    Extensions/HopPottyShieldAction/Info.plist \
    Extensions/HopPottyShieldAction/HopPottyShieldAction.entitlements \
    Extensions/HopPottyWidgets/Info.plist \
    Extensions/HopPottyWidgets/HopPottyWidgets.entitlements \
    HopPottyKit/Package.swift
do
    [ -f "$f" ] && pass "$f" || fail "missing: $f"
done

# ---------------------------------------------------------------------------
section "Identifiers agree between the build configuration and the code"
# ---------------------------------------------------------------------------
#
# ScreenTimeIdentifiers.swift is the source of truth at runtime; the xcconfig is
# the source of truth at build time. They describe the same four bundles and one
# App Group, and nothing in the toolchain checks that they match.

if [ ! -f "$IDS" ]; then
    warn "$IDS not found — skipping identifier comparison (the Screen Time layer may not have landed yet)"
else
    APP_ID="$(setting "$BASE" HOPPOTTY_APP_BUNDLE_ID)"
    GROUP="$(setting "$BASE" HOPPOTTY_APP_GROUP)"

    # One level of $(VAR) expansion is enough for how these are written.
    expand () { printf '%s' "${1//\$(HOPPOTTY_APP_BUNDLE_ID)/$APP_ID}"; }

    MONITOR_ID="$(expand "$(setting "$BASE" HOPPOTTY_MONITOR_BUNDLE_ID)")"
    SHIELDCFG_ID="$(expand "$(setting "$BASE" HOPPOTTY_SHIELD_CONFIG_BUNDLE_ID)")"
    SHIELDACT_ID="$(expand "$(setting "$BASE" HOPPOTTY_SHIELD_ACTION_BUNDLE_ID)")"

    compare () {
        local label="$1" configured="$2" declared="$3"
        if [ -z "$declared" ]; then
            warn "$label: no constant found in ScreenTimeIdentifiers.swift"
        elif [ "$configured" = "$declared" ]; then
            pass "$label = $configured"
        else
            fail "$label: xcconfig says '$configured', ScreenTimeIdentifiers.swift says '$declared'"
        fi
    }

    compare "App Group"        "$GROUP"        "$(swift_literal "$IDS" appGroupID)"
    compare "app bundle id"    "$APP_ID"       "$(swift_literal "$IDS" appBundleID)"
    compare "monitor ext id"   "$MONITOR_ID"   "$(swift_literal "$IDS" monitorBundleID)"
    compare "shieldconfig id"  "$SHIELDCFG_ID" "$(swift_literal "$IDS" shieldConfigurationBundleID)"
    compare "shieldaction id"  "$SHIELDACT_ID" "$(swift_literal "$IDS" shieldActionBundleID)"

    case "$GROUP" in
        group.*) pass "App Group begins with 'group.' as Apple requires" ;;
        *)       fail "App Group '$GROUP' must begin with 'group.'" ;;
    esac

    WIDGETS_ID="$(expand "$(setting "$BASE" HOPPOTTY_WIDGETS_BUNDLE_ID)")"

    for ext_id in "$MONITOR_ID" "$SHIELDCFG_ID" "$SHIELDACT_ID" "$WIDGETS_ID"; do
        case "$ext_id" in
            "$APP_ID".*) : ;;
            *) fail "extension id '$ext_id' is not prefixed by the app id '$APP_ID', which Apple requires" ;;
        esac
    done

    # The widget extension does not link the Screen Time layer, so it cannot see
    # ScreenTimeIdentifiers.appGroupID and re-declares the constant instead. That
    # duplication is only safe while something checks it, and this is that thing:
    # a drift here is silent, total, and looks exactly like a broken widget.
    WIDGET_STORE=HopPotty/Services/Widgets/WidgetSnapshotStore.swift
    if [ -f "$WIDGET_STORE" ]; then
        compare "widget App Group" "$GROUP" "$(swift_literal "$WIDGET_STORE" widgetAppGroupID)"
    else
        warn "$WIDGET_STORE not found — skipping the widget App Group comparison"
    fi
fi

# ---------------------------------------------------------------------------
section "Deployment target is 17.0 everywhere (ADR 0002)"
# ---------------------------------------------------------------------------

DEPLOY="$(setting "$BASE" IPHONEOS_DEPLOYMENT_TARGET)"
[ "$DEPLOY" = "17.0" ] && pass "Config/Base.xcconfig: $DEPLOY" || fail "Config/Base.xcconfig: IPHONEOS_DEPLOYMENT_TARGET is '$DEPLOY', expected 17.0"

if grep -q 'iOS: "17.0"' project.yml; then
    pass "project.yml: iOS 17.0"
else
    fail "project.yml: deploymentTarget iOS is not 17.0"
fi

if grep -q '\.iOS(\.v17)' HopPottyKit/Package.swift; then
    pass "HopPottyKit/Package.swift: .iOS(.v17)"
else
    fail "HopPottyKit/Package.swift: platform floor is not .iOS(.v17)"
fi

# ---------------------------------------------------------------------------
section "Debug tools cannot reach a Release build"
# ---------------------------------------------------------------------------

if grep -q 'SWIFT_ACTIVE_COMPILATION_CONDITIONS.*HOPPOTTY_DEBUG_TOOLS' Config/Debug.xcconfig; then
    pass "Debug defines HOPPOTTY_DEBUG_TOOLS"
else
    fail "Debug does not define HOPPOTTY_DEBUG_TOOLS — the Lab would be unbuildable everywhere"
fi

for forbidden in HOPPOTTY_DEBUG_TOOLS HOPPOTTY_MOCKS DEBUG; do
    if grep -E '^[[:space:]]*(SWIFT_ACTIVE_COMPILATION_CONDITIONS|GCC_PREPROCESSOR_DEFINITIONS)' Config/Release.xcconfig \
        | grep -qw "$forbidden"; then
        fail "Release defines $forbidden — a Release build must not contain developer surfaces"
    else
        pass "Release does not define $forbidden"
    fi
done

if grep -q 'HOPPOTTY_MOCKS' Config/DebugMock.xcconfig; then
    pass "DebugMock defines HOPPOTTY_MOCKS"
else
    fail "DebugMock does not define HOPPOTTY_MOCKS — AppBuildConfiguration would report .live"
fi

# ---------------------------------------------------------------------------
section "Extension principal classes exist"
# ---------------------------------------------------------------------------
#
# NSExtensionPrincipalClass is a STRING. Nothing checks it: not the compiler, not
# the linker, not code signing, not App Store validation. If it names a class
# that does not exist, or one that has been renamed, the extension builds,
# signs, embeds, installs — and is then never instantiated. From the outside
# that is indistinguishable from a Screen Time bug, which is the most expensive
# thing in this project to debug.
#
# The extension point identifiers themselves cannot be checked here. They are
# hand-written (Docs/ScreenTimeArchitecture.md §8 advises against that; XcodeGen
# leaves no alternative) and only an Xcode-generated target can confirm them.

check_principal () {
    local dir="$1"
    local plist="Extensions/$dir/Info.plist"
    [ -f "$plist" ] || return 0

    local declared
    declared="$(sed -n 's/.*<string>\$(PRODUCT_MODULE_NAME)\.\([A-Za-z0-9_]*\)<\/string>.*/\1/p' "$plist" | head -1)"
    if [ -z "$declared" ]; then
        fail "$dir: NSExtensionPrincipalClass is not of the form \$(PRODUCT_MODULE_NAME).ClassName"
        return 0
    fi

    if ls "Extensions/$dir"/*.swift >/dev/null 2>&1 &&
       grep -qE "(final )?class ${declared}[[:space:]]*:" "Extensions/$dir"/*.swift; then
        pass "$dir: principal class $declared is declared"
    elif ls "Extensions/$dir"/*.swift >/dev/null 2>&1; then
        fail "$dir: Info.plist names principal class '$declared', which no source in Extensions/$dir declares"
    else
        warn "$dir: no Swift sources yet — principal class '$declared' unchecked"
    fi
}

check_principal HopPottyDeviceActivityMonitor
check_principal HopPottyShieldConfiguration
check_principal HopPottyShieldAction

# ---------------------------------------------------------------------------
section "Widget extension"
# ---------------------------------------------------------------------------
#
# The widget target is the odd one out, in three ways that all fail silently:
#
#  * It is entered through @main on a WidgetBundle, NOT through a principal
#    class. A principal class here would be ignored; more to the point, someone
#    adding one by analogy with the other three would be papering over a missing
#    @main, and the extension would never be instantiated.
#  * Its extension point identifier is WidgetKit's. Wrong value, no widget in the
#    gallery, no error anywhere.
#  * It must NOT hold the Family Controls entitlement (Docs/Widgets.md §5). That
#    is checked in the Entitlements section below, which is where the
#    corresponding positive check for the other three lives.

WIDGET_DIR=Extensions/HopPottyWidgets
WIDGET_PLIST="$WIDGET_DIR/Info.plist"

if [ -f "$WIDGET_PLIST" ]; then
    if grep -q '<string>com.apple.widgetkit-extension</string>' "$WIDGET_PLIST"; then
        pass "HopPottyWidgets: extension point is com.apple.widgetkit-extension"
    else
        fail "HopPottyWidgets: Info.plist does not declare NSExtensionPointIdentifier com.apple.widgetkit-extension"
    fi

    if grep -q '<key>NSExtensionPrincipalClass</key>' "$WIDGET_PLIST"; then
        fail "HopPottyWidgets: declares NSExtensionPrincipalClass — a WidgetKit extension is entered through @main on a WidgetBundle"
    else
        pass "HopPottyWidgets: no principal class, as a WidgetKit extension requires"
    fi
else
    warn "$WIDGET_PLIST not found — skipping the widget extension point checks"
fi

if ls "$WIDGET_DIR"/*.swift >/dev/null 2>&1; then
    if grep -qE '^@main' "$WIDGET_DIR"/*.swift; then
        pass "HopPottyWidgets: an @main entry point is declared"
    else
        fail "HopPottyWidgets: no @main in $WIDGET_DIR — the extension would never start"
    fi

    if grep -qE ': *WidgetBundle' "$WIDGET_DIR"/*.swift; then
        pass "HopPottyWidgets: a WidgetBundle is declared"
    else
        fail "HopPottyWidgets: no WidgetBundle in $WIDGET_DIR"
    fi

    # The Live Activity's attributes are compiled into two targets. If the app
    # stops compiling them, Activity.request has no type to request and the whole
    # Live Activity silently disappears.
    ATTRS="$WIDGET_DIR/PottyPauseActivityAttributes.swift"
    if [ -f "$ATTRS" ]; then
        if grep -q "path: $ATTRS" project.yml; then
            pass "PottyPauseActivityAttributes.swift is listed for the app target too"
        else
            fail "PottyPauseActivityAttributes.swift exists but project.yml does not add it to the app target — ActivityKit needs both processes to compile the same type"
        fi
    else
        warn "$ATTRS not found — skipping the Live Activity attributes check"
    fi
else
    warn "$WIDGET_DIR has no Swift sources yet"
fi

# NSSupportsLiveActivities belongs to the APP, not to the widget extension.
# Without it every Activity.request throws and the lock screen simply stays
# empty, which is indistinguishable from a family who switched the feature off.
if grep -q '<key>NSSupportsLiveActivities</key>' HopPotty/App/Info.plist; then
    pass "app Info.plist declares NSSupportsLiveActivities"
else
    fail "app Info.plist is missing NSSupportsLiveActivities — Activity.request would always throw"
fi

if grep -q '<key>NSSupportsLiveActivities</key>' "$WIDGET_PLIST" 2>/dev/null; then
    fail "HopPottyWidgets/Info.plist declares NSSupportsLiveActivities — that key belongs to the app, which is what starts an activity"
fi

# ---------------------------------------------------------------------------
section "Developer-only sources are guarded"
# ---------------------------------------------------------------------------
#
# The Release configuration removes HopPotty/Developer/* from the compile with
# EXCLUDED_SOURCE_FILE_NAMES, and every file in there is additionally wrapped in
# a compilation condition Release does not define. Two mechanisms, because the
# thing being prevented — a build that can start and end a Potty Pause without a
# real authorization reaching a family — is not a thing to protect with one.

if [ -d HopPotty/Developer ]; then
    for dev in HopPotty/Developer/*.swift; do
        [ -e "$dev" ] || continue
        if head -5 "$dev" | grep -qE '^#if (DEBUG|HOPPOTTY_DEBUG_TOOLS)'; then
            # Whole file is developer-only. The type does not exist in Release.
            pass "$(basename "$dev") is wholly inside a debug-only condition"
        elif grep -qE '^[[:space:]]*#if (DEBUG|HOPPOTTY_DEBUG_TOOLS)' "$dev" && grep -qE '^[[:space:]]*#else' "$dev"; then
            # The seam pattern: a modifier or shim that must compile in BOTH
            # configurations, with the release branch containing no reference to
            # anything developer-only. DeveloperSurface.swift is the example.
            pass "$(basename "$dev") is a debug/release seam (#if … #else)"
        else
            fail "$(basename "$dev") has no debug-only guard — it would compile into a Release build"
        fi
    done
else
    warn "HopPotty/Developer does not exist"
fi

# ---------------------------------------------------------------------------
section "Preview fixtures are declared, and cannot reach a Release build"
# ---------------------------------------------------------------------------
#
# The app target links HopPottyFixtures — the sample family every #Preview and
# `ParentEnvironment.preview()` is built from. XcodeGen has no per-configuration
# dependency filter, so it is linked in Release too, and the only thing keeping
# it out of a shipping binary is that no Release code references it: every
# `import HopPottyFixtures` in the app sits inside `#if DEBUG`, so the module's
# symbols are unreferenced and the static linker drops them.
#
# Two checks, because the argument has two halves and each fails silently on its
# own. A missing dependency is a compile error nobody sees until they open Xcode;
# an unguarded import is a Release build that carries invented children around
# and gives the compiler a reason to keep them.

APP_TARGET_BLOCK="$(awk '/^  HopPotty:$/ {inblock = 1; next} inblock && /^  [A-Za-z]/ {exit} inblock {print}' project.yml)"

if printf '%s\n' "$APP_TARGET_BLOCK" | grep -qE '^[[:space:]]*product:[[:space:]]*HopPottyFixtures[[:space:]]*$'; then
    pass "app target depends on HopPottyFixtures"
elif grep -rlq '^[[:space:]]*import[[:space:]]\+HopPottyFixtures' HopPotty 2>/dev/null; then
    fail "HopPotty imports HopPottyFixtures but project.yml does not list it as an app-target dependency"
else
    pass "app target does not depend on HopPottyFixtures, and does not import it"
fi

# Every import inside a `#if DEBUG` region. `#else` at the guarded level ends
# that region, so an import moved into a release branch is caught too.
fixtures_import_is_debug_guarded () {
    awk '
        /^[[:space:]]*#if[[:space:]]+DEBUG([[:space:]]|$)/ { debug = 1; depth = 0; next }
        /^[[:space:]]*#(if|elseif)/  { if (debug) depth++; next }
        /^[[:space:]]*#else/         { if (debug && depth == 0) debug = 0; next }
        /^[[:space:]]*#endif/        { if (debug) { if (depth > 0) depth--; else debug = 0 }; next }
        /^[[:space:]]*import[[:space:]]+HopPottyFixtures/ { if (!debug) bad = 1 }
        END { exit bad }
    ' "$1"
}

FIXTURE_IMPORTERS="$(grep -rl '^[[:space:]]*import[[:space:]]\+HopPottyFixtures' HopPotty 2>/dev/null || true)"
if [ -z "$FIXTURE_IMPORTERS" ]; then
    pass "no app source imports HopPottyFixtures"
else
    while IFS= read -r src; do
        [ -n "$src" ] || continue
        if fixtures_import_is_debug_guarded "$src"; then
            pass "$(basename "$src") imports HopPottyFixtures inside #if DEBUG"
        else
            fail "$(basename "$src") imports HopPottyFixtures outside #if DEBUG — the sample family would link into Release"
        fi
    done <<EOF
$FIXTURE_IMPORTERS
EOF
fi

# ---------------------------------------------------------------------------
section "Entitlements"
# ---------------------------------------------------------------------------

for ent in \
    HopPotty/App/HopPotty.entitlements \
    Extensions/HopPottyDeviceActivityMonitor/HopPottyDeviceActivityMonitor.entitlements \
    Extensions/HopPottyShieldConfiguration/HopPottyShieldConfiguration.entitlements \
    Extensions/HopPottyShieldAction/HopPottyShieldAction.entitlements
do
    [ -f "$ent" ] || continue
    if grep -q '<key>com.apple.developer.family-controls</key>' "$ent"; then
        pass "$(basename "$ent"): Family Controls"
    else
        fail "$(basename "$ent"): missing com.apple.developer.family-controls"
    fi
    if grep -q '<key>com.apple.security.application-groups</key>' "$ent"; then
        pass "$(basename "$ent"): App Group"
    else
        fail "$(basename "$ent"): missing com.apple.security.application-groups"
    fi
    if grep -q '<key>com.apple.developer.family-controls.app-and-website-usage</key>' "$ent"; then
        fail "$(basename "$ent"): declares the app-and-website-usage entitlement, deliberately declined in Docs/Entitlements.md §1"
    fi
done

# The widget extension is the one target that must NOT hold Family Controls.
# It draws a countdown from a JSON file; granting it the capability would put a
# fifth App ID into the distribution request and hand the entitlement to the one
# HopPotty target rendered on a locked screen. Docs/Widgets.md §5.
WIDGET_ENT=Extensions/HopPottyWidgets/HopPottyWidgets.entitlements
if [ -f "$WIDGET_ENT" ]; then
    if grep -q '<key>com.apple.security.application-groups</key>' "$WIDGET_ENT"; then
        pass "$(basename "$WIDGET_ENT"): App Group"
    else
        fail "$(basename "$WIDGET_ENT"): missing com.apple.security.application-groups — the widget would find no snapshot"
    fi
    if grep -q '<key>com.apple.developer.family-controls</key>' "$WIDGET_ENT"; then
        fail "$(basename "$WIDGET_ENT"): declares Family Controls, which the widget neither needs nor should have"
    else
        pass "$(basename "$WIDGET_ENT"): no Family Controls, as intended"
    fi
    if grep -q '<key>aps-environment</key>' "$WIDGET_ENT"; then
        fail "$(basename "$WIDGET_ENT"): declares aps-environment — HopPotty pushes nothing, Live Activities included"
    fi
fi

# ---------------------------------------------------------------------------
section "StoreKit product identifier"
# ---------------------------------------------------------------------------

IAP_RAW="$(setting "$BASE" HOPPOTTY_IAP_FAMILY_PRODUCT_ID)"
IAP="${IAP_RAW//\$(HOPPOTTY_APP_BUNDLE_ID)/$(setting "$BASE" HOPPOTTY_APP_BUNDLE_ID)}"
STOREKIT_ID="$(sed -n 's/.*"productID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' HopPotty/Resources/HopPotty.storekit | head -1)"

if [ "$IAP" = "$STOREKIT_ID" ]; then
    pass "product id = $IAP (xcconfig and .storekit agree)"
else
    fail "product id: xcconfig says '$IAP', HopPotty.storekit says '$STOREKIT_ID'"
fi

# The Swift source, which this check used to stop short of. A literal product id
# in PurchaseService.swift once said `com.hoppotty.family.unlock` while every
# other file said `com.hoppotty.family`; the extra word made StoreKit return no
# products, so the paywall could never load and a family who had paid stayed
# locked. Nothing failed at build time and this script passed. It now refuses any
# hard-coded product id in Swift: the identifier comes from Info.plist, which the
# xcconfig fills, so there is exactly one place to change it.
SWIFT_IAP_LITERALS="$(grep -rn '"com\.[A-Za-z0-9._-]*\.family[A-Za-z0-9._-]*"' HopPotty --include='*.swift' || true)"
if [ -z "$SWIFT_IAP_LITERALS" ]; then
    pass "no hard-coded product id in Swift (it is read from Info.plist)"
else
    fail "hard-coded product id in Swift — it must come from \$HPFamilyUnlockProductIdentifier:
$SWIFT_IAP_LITERALS"
fi

if grep -q 'HPFamilyUnlockProductIdentifier' HopPotty/Services/Purchases/PurchaseService.swift; then
    pass "PurchaseService reads HPFamilyUnlockProductIdentifier"
else
    fail "PurchaseService does not read HPFamilyUnlockProductIdentifier — the Info.plist key documented as the single source of the product id has no reader"
fi

if grep -q '"type"[[:space:]]*:[[:space:]]*"NonConsumable"' HopPotty/Resources/HopPotty.storekit; then
    pass "HopPotty Family is a NonConsumable"
else
    fail "HopPotty Family is not a NonConsumable — HopPotty is bought once, never rented"
fi

# ---------------------------------------------------------------------------
section "No signing material is committed"
# ---------------------------------------------------------------------------

if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    LEAKED="$(git ls-files '*.p12' '*.mobileprovision' '*.cer' '*.certSigningRequest' 'Config/Secrets.xcconfig' 2>/dev/null || true)"
    if [ -z "$LEAKED" ]; then
        pass "no certificates, profiles or Secrets.xcconfig are tracked"
    else
        fail "signing material is tracked by git:"$'\n'"$LEAKED"
    fi
else
    warn "not a git checkout — skipped the committed-secrets check"
fi

# ---------------------------------------------------------------------------
section "Files shared by all four targets"
# ---------------------------------------------------------------------------
#
# project.yml lists these individually for each extension target. They are the
# machine-readable form of the "Target membership" comment in
# ScreenTimeIdentifiers.swift, and they are declared `optional: true` so a rename
# does not block generation — which is exactly why it has to be checked here.

for shared in \
    HopPotty/Services/ScreenTime/ScreenTimeIdentifiers.swift \
    HopPotty/Services/ScreenTime/AppGroupStore.swift \
    HopPotty/Services/ScreenTime/SharedPauseTypes.swift \
    HopPotty/Services/ScreenTime/ShieldReconciler.swift
do
    if [ -f "$shared" ]; then
        if grep -c "path: $shared" project.yml | grep -q '^3$'; then
            pass "$(basename "$shared") is a member of all three extension targets"
        else
            fail "$(basename "$shared") exists but is not listed for all three extension targets in project.yml"
        fi
    else
        warn "$shared is listed in project.yml but does not exist (renamed? not written yet?)"
    fi
done

# WidgetSnapshotStore.swift is a fifth shared file with a different membership:
# the app (implicitly, through `path: HopPotty`), the widget extension, and the
# DeviceActivity monitor — which is often the only HopPotty code that runs for
# hours, and is therefore the process that has to tell the home screen a pause
# started. Two explicit listings, and the app's is implicit, so the expected
# count is two.
WIDGET_SHARED=HopPotty/Services/Widgets/WidgetSnapshotStore.swift
if [ -f "$WIDGET_SHARED" ]; then
    if [ "$(grep -c "path: $WIDGET_SHARED" project.yml)" = "2" ]; then
        pass "$(basename "$WIDGET_SHARED") is a member of the widget and monitor extensions"
    else
        fail "$(basename "$WIDGET_SHARED") must be listed for exactly two extension targets in project.yml (widgets, monitor)"
    fi
else
    warn "$WIDGET_SHARED does not exist"
fi

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAILURES" -gt 0 ]; then
    printf '%s%d check(s) failed%s' "$RED" "$FAILURES" "$OFF"
    [ "$WARNINGS" -gt 0 ] && printf ', %d warning(s)' "$WARNINGS"
    printf '\n'
    exit 1
fi
printf '%sAll configuration checks passed%s' "$GREEN" "$OFF"
[ "$WARNINGS" -gt 0 ] && printf ' (%d warning(s))' "$WARNINGS"
printf '\n'
