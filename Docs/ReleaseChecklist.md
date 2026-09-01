# Release Checklist

**Scope:** everything between "the code is finished" and "the build is submitted".

This is not a formality. HopPotty ships an app extension that can take a child's
apps away, and a bug in that path is not a crash report — it is a four-year-old
holding a device that will not open anything, with nobody able to explain why.
Several items below exist for that one failure mode and are worth the minutes
they cost.

Work top to bottom. An item that cannot be ticked is a release blocker unless it
is explicitly marked otherwise.

---

## 0. Blockers that are not about this build

Check these first; they have lead times measured in days or weeks, not minutes.

- [ ] The **Family Controls distribution entitlement is approved** for all four
      App IDs — the app and each of the three extensions. TestFlight is gated on
      this, not just the App Store. (`Docs/Entitlements.md` §2)
- [ ] Beside the granted capability, **Provisioning Support** lists Development,
      Ad Hoc **and** App Store. An approval missing App Store distribution passes
      every local check and fails at upload.
- [ ] The App Group `group.com.hoppotty` exists in the developer account and all
      four App IDs are members.
- [ ] Every one of the nine **UNVERIFIED** items in
      `Docs/ScreenTimeArchitecture.md` §12 has been answered on a physical device,
      with the date and OS version written back into that document. Shipping with
      any of them open means shipping a shield whose behaviour is a guess.

---

## 1. The tree is clean

- [ ] `Scripts/bootstrap.sh` runs clean from a fresh clone.
- [ ] `Scripts/verify-config.sh` passes — identifiers, deployment target,
      Release compilation conditions, entitlements, StoreKit product id, no
      committed signing material.
- [ ] `git status` is clean and no `.p12`, `.mobileprovision`, `.cer` or
      `Config/Secrets.xcconfig` is tracked.
- [ ] No `TODO` or `FIXME` in shipping logic (`Docs/CONTRACTS.md` §7).
- [ ] `HopPotty.xcodeproj` is **not** committed.

## 2. Tests

- [ ] `cd HopPottyKit && swift test` — green, no skips.
- [ ] `xcodebuild test -scheme HopPotty-Mock -destination 'platform=iOS Simulator,name=iPhone 16'` — green.
- [ ] CI is green on the commit being released, not on an earlier one.
- [ ] The child-safety copy scanner passed. Every new string went through
      `HopCopy`; there are no string literals in views (`Docs/CONTRACTS.md` §5).

## 3. Versioning

- [ ] `MARKETING_VERSION` bumped in `Config/Base.xcconfig`.
- [ ] `CURRENT_PROJECT_VERSION` bumped, and higher than every build already
      uploaded for this marketing version.
- [ ] Both are set once, at project level, so the app and all three extensions
      agree. **An extension whose version differs from its host app is rejected at
      upload** — and the error names the extension, not the mismatch.
- [ ] `AppSettings.lastSeenReleaseVersion` migration behaviour considered if this
      release changes stored data.

## 4. Build the archive

- [ ] Archive the **HopPotty** scheme in the **Release** configuration. Not
      DebugMock. Not Debug.
- [ ] The archive builds with no new warnings. (Release does not treat warnings
      as errors on purpose — so read them here, where nobody is forced to.)
- [ ] Automatic signing resolved a distribution profile for all four targets.

## 5. Inspect the archive before uploading

Right-click the archive in Xcode's Organizer > Show in Finder > Show Package
Contents, then `Products/Applications/HopPotty.app`.

- [ ] `PlugIns/` contains exactly **three** `.appex` bundles. A missing extension
      builds and installs silently and then never runs.
- [ ] Each `.appex` `Info.plist` has the expected `NSExtensionPointIdentifier`
      and an `NSExtensionPrincipalClass` naming a class that exists.
- [ ] `codesign -d --entitlements - HopPotty.app` and the same for each `.appex`:
      every one carries `com.apple.developer.family-controls` and the App Group.
- [ ] The App Group string is byte-identical in all four, and equals
      `ScreenTimeIdentifiers.appGroupID`.
- [ ] `com.apple.developer.family-controls.app-and-website-usage` appears
      **nowhere**. It is deliberately declined (`Docs/Entitlements.md` §1).
- [ ] No `aps-environment`, no iCloud container, no keychain access group.
- [ ] `nm`/`strings` finds no Potty Pause Lab symbols. The Lab must be absent
      from the binary, not merely unreachable.
- [ ] `Info.plist` has `ITSAppUsesNonExemptEncryption = false`, and that is still
      true — nothing in this release added custom cryptography.
- [ ] The app icon is present at 1024×1024 and the placeholder slots in
      `Assets.xcassets` have been filled.

## 6. Behaviour on a physical device — the Potty Pause

Development-signed build, real device, real Family Controls authorization.
**Every one of these is about the child getting their apps back.**

- [ ] A pause starts, the selected apps show the HopPotty shield, and the shield
      renders our copy — not Apple's default shield. (Apple's default appearing is
      a user-visible copy failure and a P1: it means the configuration extension
      was too slow or crashed.)
- [ ] Tapping the shield's primary button ends the pause and restores access.
- [ ] A pause left alone ends **on its own** at the intended duration.
- [ ] A pause left alone with the device face-down ends by the 15-minute backstop
      at the latest.
- [ ] **Force-quit mid-pause, relaunch: access is restored.** This is the
      cold-start reconciliation and it is the load-bearing invariant.
- [ ] **Reboot mid-pause, relaunch: access is restored.**
- [ ] Revoke Screen Time authorization in Settings mid-pause: the shield comes
      down and the caregiver is told why.
- [ ] Caregiver override behind the parent gate restores access immediately.
- [ ] Delete and reinstall the app while a shield is up: no shield survives that
      the app cannot clear.
- [ ] Change the device clock backwards mid-pause: the shield comes down.
- [ ] No path anywhere extends a pause. No path consults what the child produced.

## 7. Behaviour — the rest

- [ ] First-run authorization prompt appears once and only once, and declining it
      leaves a working app that explains what it cannot do.
- [ ] Stars only ever increase. Nothing removes one — not an accident, not a
      deletion, not a crash mid-award (`Docs/CONTRACTS.md` §4.2).
- [ ] An `accident` is recorded on the timeline and reaches no reward path.
- [ ] Every destructive action passes the parent gate and states exactly what it
      will remove, with counts.
- [ ] The store-failure paths degrade rather than crash: rename the store file on
      a test device and confirm the app launches, works, and tells the caregiver
      history is unavailable.

## 8. Purchases

- [ ] `com.hoppotty.family` exists in App Store Connect as a **non-consumable**,
      priced at $19.99 (Tier equivalent), with Family Sharing **enabled**, and its
      identifier matches `Config/Base.xcconfig` exactly.
- [ ] The product is in the "Ready to Submit" state and attached to this version.
      An in-app purchase that is not attached is not reviewed.
- [ ] Purchase, restore, and Ask To Buy all exercised against a **sandbox**
      account on a real device — not only against the local `.storekit` file.
- [ ] Restore works on a second device signed into the same Apple Account.
- [ ] The paywall shows `Product.displayPrice`, never a hard-coded price, and
      shows no price at all when StoreKit has not answered.
- [ ] The paywall and the purchase button are behind the parent gate.

## 9. Accessibility

- [ ] VoiceOver reaches every control on every screen, with meaningful labels.
- [ ] Dynamic Type to the largest accessibility size: nothing truncates, nothing
      overlaps, nothing becomes unreachable.
- [ ] Reduce Motion: every animation has its degraded path
      (`Docs/CONTRACTS.md` §6).
- [ ] Increased Contrast: the palette resolves and the contrast tests still pass.
- [ ] Child controls are at least 72pt, primary child actions 96pt.
- [ ] No meaning is carried by colour alone — every event kind has its glyph.
- [ ] Every spoken line has its written caption.

## 10. Privacy and App Store Connect

- [ ] **App Privacy: "Data Not Collected"** — and it is true. No analytics SDK, no
      crash reporter that transmits, no network request carrying child data.
- [ ] No third-party SDK was added this release. In the Kids Category that is not
      a preference; it is a review rule.
- [ ] Age rating 4+.
- [ ] Any link out of the app is behind the parent gate.
- [ ] Screenshots show real UI from this build, and no real child's data.
- [ ] The privacy policy URL resolves and describes on-device-only storage.
- [ ] Support URL resolves.

## 11. App Review notes

- [ ] Pasted from `Docs/Entitlements.md` §5 into App Review Information > Notes.
- [ ] **Every sentence is true of this build.** In particular the stated default
      pause duration and the described "how to test" steps.
- [ ] Demo caregiver passcode filled in and verified on a clean install.
- [ ] The reviewer is told Screen Time authorization needs a device signed into
      iCloud with a passcode set.
- [ ] The explanation of *why* Family Controls is required is present. A Screen
      Time app without one is rejected as a matter of course.

## 12. After upload

- [ ] The build processed without an ITMS email about entitlements, missing
      icons, or extension versioning.
- [ ] Installed from TestFlight on a device that has **never** had a development
      build of HopPotty — a distribution-signed extension failing to launch is
      invisible on a device that already trusts a development one.
- [ ] Section 6 repeated, in full, on that TestFlight build. Development signing
      and distribution signing are different entitlement paths, and a stale
      extension profile produces a build that installs and then does nothing when
      a shield should appear.

---

## If something is wrong after release

The one failure that cannot wait for a review cycle is a stranded shield. Before
shipping, know the answer to: *if a family reports their child's apps are stuck,
what do we tell them tonight?*

Today the answer is: delete HopPotty. Removing the app removes its
`ManagedSettings` store with it, and the child's apps come back. That is worth
writing into the support page **before** the first release, not after the first
report.
