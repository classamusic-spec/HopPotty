# Getting HopPotty running on your Mac

**Who this is for:** someone who has never opened this project before and wants
to see it running. Every command is meant to be copied and pasted exactly.

**Read this first — one honest sentence:** this app has never been compiled by
anyone, so the very first build **will** show errors in Xcode. That is expected,
not a sign anything is broken. `Docs/FirstBuild.md` lists the ones we predict and
how to fix each.

---

## What you need before you start

| | Why |
| --- | --- |
| **A Mac** | iOS apps can only be built on macOS. There is no way around this. |
| **Xcode 16 or newer** | Free, from the Mac App Store. It is a big download — start it now, it can take an hour. |
| **An Apple ID** | Free. You already have one if you use an iPhone. |
| **A paid Apple Developer account** ($99/year) | **Only** needed for the app-pausing feature on a real iPhone. Not needed to look at the app in the Simulator. |

You do **not** need the paid account to do Steps 1–7 below.

---

## Step 1 — Open the Terminal

Press `Cmd` + `Space`, type `Terminal`, press Enter. A window with a text prompt
appears. Every command below gets typed (or pasted) here, one line at a time,
pressing Enter after each.

---

## Step 2 — Install Homebrew

Homebrew installs developer tools. Skip this step if you already have it (type
`brew --version` — if it prints a number, you have it).

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

It will ask for your Mac password. Typing it shows nothing on screen — that is
normal. When it finishes it may print two `export` lines and ask you to run
them; do exactly what it says.

---

## Step 3 — Install XcodeGen

```bash
brew install xcodegen
```

**What this is for:** `HopPotty.xcodeproj` — the file you double-click to open
Xcode — is *not* stored in the repository. It is generated from `project.yml`.
That is deliberate: an Xcode project file is thousands of lines nobody can
review, and two people editing one always conflict. XcodeGen builds it fresh
from a file you *can* read.

---

## Step 4 — Get the code

```bash
cd ~/Desktop
git clone https://github.com/classamusic-spec/HopPotty.git
cd HopPotty
```

You now have a folder called `HopPotty` on your Desktop. The repository has one
branch and the clone lands on it, so there is nothing to switch.

---

## Step 5 — Generate the Xcode project

```bash
Scripts/bootstrap.sh
```

This one command does a lot: it checks your tools, creates your private signing
file, runs the configuration checks, generates `HopPotty.xcodeproj`, and then
prints the manual steps. **Read what it prints.**

Run it again any time — after pulling changes, after switching branches, or if
anything looks wrong. It never overwrites your settings and it always rebuilds
the project from scratch, so it cannot get into a bad state.

If it stops with a red `bootstrap failed:` message, it tells you exactly what to
fix. Fix that, run it again.

---

## Step 6 — Put in your Team ID

Bootstrap created `Config/Secrets.xcconfig`. Open it:

```bash
open -e Config/Secrets.xcconfig
```

Find your Team ID — it is ten characters like `A1B2C3D4E5` — at
[developer.apple.com/account](https://developer.apple.com/account) under
**Membership details**. Put it on the right of the `=`:

```
HOPPOTTY_DEVELOPMENT_TEAM = A1B2C3D4E5
```

Save and close.

> **This file must never be committed to git.** It is already listed in
> `.gitignore` and bootstrap refuses to run if it ever gets tracked. Leave it
> that way.

**Simulator only?** You can leave this blank for now and still do Step 7.

---

## Step 7 — Open it and run it in the Simulator

```bash
open HopPotty.xcodeproj
```

Xcode opens. At the top of the window there is a dropdown showing the scheme and
the device.

1. Set the **scheme** (left dropdown) to **`HopPotty-Mock`**.
2. Set the **device** (right dropdown) to any iPhone Simulator, e.g. *iPhone 16*.
3. Press the **▶ Play** button, or `Cmd` + `R`.

**Why `HopPotty-Mock`?** There are two schemes:

| Scheme | What it does |
| --- | --- |
| **`HopPotty-Mock`** | Swaps the Screen Time layer for in-memory fakes at compile time. Runs anywhere, including the Simulator. Use this for looking at screens, animations and flows. |
| **`HopPotty`** | The real thing. Needs a signed build on a physical iPhone. |

**The Simulator cannot pause apps.** Apple's Screen Time framework does not
meaningfully exist there, so `HopPotty-Mock` shows you the entire app *except*
the actual app-blocking. That is the honest boundary and no amount of
configuration changes it.

This is also where the first build errors appear. **Go to
`Docs/FirstBuild.md`** — it is written for exactly this moment.

---

## Step 8 — Run it on a real iPhone

Everything above still applies; this adds the device.

1. Plug the iPhone into the Mac with a cable. Unlock it. Tap **Trust** if asked.
2. In Xcode, pick your iPhone from the device dropdown instead of a Simulator.
3. Choose the **`HopPotty`** scheme (not Mock) if you want real Screen Time.
4. Press ▶.
5. The first time, the iPhone refuses to open the app. On the phone go to
   **Settings → General → VPN & Device Management**, tap your developer
   certificate, and tap **Trust**. Then open the app again.

---

## Step 9 — The Screen Time setup (only for real app-pausing)

This is the part that needs the **paid** Apple Developer account, and it is the
one place where you wait on Apple. All of it happens at
[developer.apple.com/account](https://developer.apple.com/account) under
**Certificates, Identifiers & Profiles**.

**9a. Register four App IDs.** The app plus its three Screen Time extensions:

```
com.hoppotty                  the app
com.hoppotty.monitor          Device Activity Monitor extension
com.hoppotty.shieldconfig     Shield Configuration extension
com.hoppotty.shieldaction     Shield Action extension
```

To use your own domain instead, change `HOPPOTTY_APP_BUNDLE_ID` in
`Config/Base.xcconfig` **and** the matching values in
`HopPotty/Services/ScreenTime/ScreenTimeIdentifiers.swift`, then run
`Scripts/bootstrap.sh` again. The config check fails if the two disagree, which
is the point — a mismatch here fails silently at runtime otherwise.

**9b. Enable Family Controls on all four.** Not just the app. An extension whose
App ID lacks the capability will build, install, and then simply never shield
anything — with no error to tell you why.

**9c. Create one App Group** and add all four App IDs to it:

```
group.com.hoppotty
```

This is how the extensions see the app's state. If it is missing or misspelled
nothing fails at build time; shields just stop coming down.

**9d. Request the Family Controls *distribution* entitlement — do this on day
one.** Development works as soon as 9b is done. Distribution — including
TestFlight — does not, and nothing in this repository can unblock it:

- Only your Apple Developer **Account Holder** can submit it. Not an admin, not a developer.
- Submit it **once per App ID** — the app and each of the three extensions.
- [The request form](https://developer.apple.com/contact/request/family-controls-distribution/)
- Apple publishes no turnaround time. Submit the day the App IDs exist, not when the app is finished.
- When granted, open the ⓘ beside the capability and check **Provisioning
  Support lists Development, Ad Hoc *and* App Store**. An approval missing App
  Store distribution is a silent trap you will not notice until submission.

`Docs/Entitlements.md` has the citations and the review notes.

---

## Running the tests

The domain logic — scheduling, rewards, insights, the state machine — needs no
Xcode and no Simulator:

```bash
cd HopPottyKit && swift test
```

That is 464 tests and it should be green. If it is not, something is wrong with
your toolchain, not with the app.

The app-layer tests need Xcode:

```bash
xcodebuild test -scheme HopPotty-Mock -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## When something goes wrong

| What you see | What it means |
| --- | --- |
| `xcodegen: command not found` | Step 3 did not finish. Run `brew install xcodegen` again. |
| `bootstrap failed: XcodeGen is not installed` | Same as above. |
| `bootstrap failed: Config/Secrets.xcconfig is tracked by git` | It got committed by mistake. Run `git rm --cached Config/Secrets.xcconfig`. |
| "Signing for … requires a development team" | Step 6. Your Team ID is missing from `Config/Secrets.xcconfig`. |
| "Failed to register bundle identifier" | That bundle ID is taken by someone else. Change it to your own domain — see 9a. |
| "Provisioning profile doesn't include the com.apple.developer.family-controls entitlement" | Step 9b, and you need the paid account. |
| The app builds but never pauses anything | Almost always the App Group (9c) or a missing capability on an *extension's* App ID (9b). |
| Lots of red errors on the very first build | Expected. See `Docs/FirstBuild.md`. |
| Xcode acts strangely after you pull changes | Run `Scripts/bootstrap.sh` again. The project file goes stale whenever files are added or renamed. |

---

## The shape of the thing, in one picture

```
project.yml ──(XcodeGen)──> HopPotty.xcodeproj   generated, git-ignored, never edit
Config/*.xcconfig                                build settings, readable
Config/Secrets.xcconfig                          your Team ID, git-ignored, never commit
HopPottyKit/                                     domain logic — builds and tests anywhere
HopPotty/                                        the SwiftUI app — needs Xcode
Extensions/                                      Screen Time + widgets — need Xcode
Scripts/bootstrap.sh                             run this after any change
```

**Never edit `HopPotty.xcodeproj`.** It is regenerated from `project.yml` every
time bootstrap runs, and your change would vanish. Change `project.yml` instead.
