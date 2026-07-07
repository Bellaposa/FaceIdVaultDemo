# FaceIDVaultDemo

A tiny, self-contained lab for the article **"The Face ID Bypass Everyone Copies
From Stack Overflow (And Why It Doesn't Actually Work)"**.

It ships two vaults inside one SwiftUI app and a dylib that method-swizzles
Apple's `LocalAuthentication` framework, so you can *watch* the classic
"just return `YES`" bypass succeed against a naive vault and do nothing against
a Keychain + Secure Enclave one.

> Everything here targets code you own, for learning. Don't point it at other
> people's apps.

## What's inside

| Path | What it is |
| --- | --- |
| `App/ContentView.swift` | Two tabs: **Naive Vault** (gates on the `Bool`) and **Secure Vault** (gates on the Keychain). |
| `App/KeychainVault.swift` | The correct pattern: secret stored under a `.biometryCurrentSet` access control. |
| `App/SelfTest.swift` | Headless proof (`-selftest`) that logs both paths, no tapping required. |
| `App/Bypass.m` | The SAME swizzle, but compiled *into* the app so you can demo the attack on a real device with **no jailbreak and no Frida**. |
| `inject/FaceIDBypass.m` | The injectable dylib version (the "real attacker on someone else's app" story). |
| `inject/hook.js` | The same bypass in Frida, for live on/off experimentation. |
| `inject/build_dylib.sh` | Builds + ad-hoc signs the dylib for the Simulator. |
| `run.sh` | One-shot: build app + dylib, boot a Simulator, install, launch injected. |

## Build & Setup (do this first)

Requirements: **Xcode** (tested on Xcode 26.x) and **XcodeGen**
(`brew install xcodegen`). The `.xcodeproj` is generated from `project.yml`, so
after cloning (or after editing `project.yml`) generate it:

```bash
brew install xcodegen        # one time
xcodegen generate            # creates FaceIDVaultDemo.xcodeproj
open FaceIDVaultDemo.xcodeproj
```

That's all you need for the Simulator demo and to open the project in Xcode. The
device / Sideloadly steps below build their own artifacts via the scripts.

## No jailbreak? No problem — run it on your own iPhone

Because **you own this app**, you don't need to inject anything to demo the
attack. The bypass is compiled in behind a switch, so you can run on a real
device (real Secure Enclave) with just free provisioning:

1. Open `FaceIDVaultDemo.xcodeproj` in Xcode (run `xcodegen generate` first if
   it doesn't exist yet).
2. Select your iPhone, set a unique bundle id + your personal team (Signing &
   Capabilities), and Run. No paid account, no jailbreak.
3. In the app, flip **"Attacker mode (bypass Face ID)"** (or launch with the
   `-bypass` argument). This installs the LAContext swizzle in-process.
4. **Naive Vault** → *Unlock*: opens instantly, Face ID never shown.
   **Secure Vault** → *Seed*, then *Read*: still demands a real match and the
   forged boolean is useless, because the Secure Enclave — not your process —
   holds the key.

That contrast, on real hardware, is the whole article. The dylib + Frida paths
below are only for the "attacking an app you didn't build" narrative.

> Note: the Attacker-mode swizzle is one-way; toggling it off doesn't restore
> the original methods — relaunch to reset.

## No jailbreak, external injection — via Sideloadly

This is the closest thing to a "real" attack you can do without a jailbreak:
build an IPA, let **Sideloadly** inject the dylib into it and re-sign with your
Apple ID, and install on your device. The dylib's constructor swizzles
`LAContext` at load — you didn't have to bake anything into the app.

### 1. Build the pieces

```bash
./inject/build_dylib_device.sh      # -> inject/libFaceIDBypass-device.dylib  (arm64, iphoneos)
./make_ipa.sh                       # -> ipa/FaceIDVaultDemo.ipa              (unsigned)
```

### 2. Sideloadly

1. Open Sideloadly, plug in your iPhone, drag in `ipa/FaceIDVaultDemo.ipa`.
2. Enter your Apple ID (free account is fine).
3. Open **Advanced options** → enable **inject dylibs/frameworks** (a.k.a.
   "Sideload with dylib") and add `inject/libFaceIDBypass-device.dylib`.
   Sideloadly copies it into `.app/Frameworks/`, adds the `LC_LOAD_DYLIB`
   command, and fixes the load path for you.
4. Start. Sideloadly re-signs the whole bundle with your Apple ID and installs.
5. Trust the developer profile on device: Settings → General → VPN & Device
   Management.

### 3. Observe

- **Naive Vault** → *Unlock*: the injected dylib forges `reply(YES, nil)`; the
  secret appears and the Face ID sheet never shows.
- **Secure Vault** → *Seed*, then *Read*: this is a **real device with a real
  Secure Enclave**, so the protected Keychain read still demands a genuine match.
  The injected boolean is worthless here. (Watch the log for
  `errSecInteractionNotAllowed` / a real Face ID prompt.)

That side-by-side — same injected dylib, two completely different outcomes — on
non-jailbroken hardware, is the money shot for the article.

> Free Apple IDs sign apps for 7 days; re-run Sideloadly to renew. If injection
> options are greyed out, update Sideloadly — dylib injection is under Advanced
> options.

### Clean vs embedded builds

- `make_ipa.sh` builds a **clean** IPA (`SWIFT_ACTIVE_COMPILATION_CONDITIONS=""`,
  so `EMBEDDED_BYPASS` is undefined): no in-app toggle, nothing calls the
  swizzle. The only way to bypass it is the injected dylib. This is the IPA to
  use with Sideloadly for the article.
- Running from Xcode (Debug) or `run.sh` defines `EMBEDDED_BYPASS`, which brings
  back the "Attacker mode" toggle for quick local experiments.

## Quick start (Simulator)

```bash
./run.sh          # launch WITH the bypass injected
./run.sh clean    # launch WITHOUT injection (baseline)
```

Then in the app: on **Naive Vault** tap *Unlock* — with the dylib injected the
Face ID sheet never appears and the secret is revealed. On **Secure Vault** tap
*Seed secret*, then *Read* — the boolean forgery is irrelevant there.

### Headless proof

```bash
# build the Simulator dylib first (creates inject/libFaceIDBypass.dylib)
./inject/build_dylib.sh

UDID=$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | head -1)

# injected
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$PWD/inject/libFaceIDBypass.dylib" \
  xcrun simctl launch --terminate-running-process "$UDID" com.bellaposa.faceidvaultdemo -selftest

# read the verdict
xcrun simctl spawn "$UDID" log show --last 15s \
  --predicate 'eventMessage CONTAINS "SelfTest" OR eventMessage CONTAINS "FaceIDBypass"'
```

Injected run, observed output:

```
[FaceIDBypass] evaluatePolicy intercepted (policy=1, reason=self-test)
[FaceIDBypass] --> forging reply(YES, nil), sensor never consulted
[SelfTest] NAIVE evaluatePolicy -> success=true error=nil
[SelfTest] NAIVE VAULT: secret would be revealed. Boolean gate defeated.
```

## Important caveat about the Simulator

The iOS **Simulator has no Secure Enclave**, so the OS does *not* actually
enforce the biometric access control on Keychain items — a protected read can
succeed there without a match. That's why `SelfTest` prints a `#if
targetEnvironment(simulator)` note. To demonstrate the *Secure Vault holding the
line*, run on a **real device** (via Sideloadly, above — no jailbreak needed),
where the protected read demands a genuine Face ID match no matter what you
forge on `LAContext`. The Simulator is perfect for proving the **naive bypass
works**; a device is where you prove the **secure design wins**.

## Requirements

- **Xcode** (tested with Xcode 26.x)
- **XcodeGen** (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml`
- iOS **Simulator** for the naive-bypass demo
- A real iPhone + **Sideloadly** (free Apple ID) for the full contrast — no jailbreak required
- Optional: a jailbroken device / Frida if you prefer the classic tooling

## Article outline (for Medium)

1. The advice everyone copies: hook `evaluatePolicy`, return `YES`.
2. `class-dump` `LAContext`: it's a thin client, not the decider.
3. Write the one-line bypass → it destroys the Naive Vault.
4. Plot twist: the Secure Vault shrugs it off.
5. Follow the `YES`: `LAContext` → XPC → `coreauthd` → `biometrickitd` → Secure Enclave.
6. The real gate: Keychain item under `.biometryCurrentSet`; the SEP releases the key, not a boolean.
7. Lesson: use biometrics to *release a key*, never to *unlock a screen*.
8. Ship the repo, invite questions.
