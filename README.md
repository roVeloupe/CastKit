# CastKit

An on-device **MobileGestalt** editor for iOS 27 beta 1–4, built by integrating two proven open-source projects:

- **[GestaltEdit](https://github.com/frs0n/GestaltEdit)** — the core MobileGestalt engine: feature presets, full key/value field editor, automatic backups, and the `bad_query` sandbox-extension write path.
- **[3105](https://github.com/YangJiiii/3105)** — the `.3105` encrypted patch-package codec (AES-GCM + PBKDF2 envelope), so projects can be imported/exported and round-trip with 3105.

Nothing here is fabricated: the write path is the same `bad_query` ContainerManager trick GestaltEdit uses, the preset keys are GestaltEdit's real keys, and the patch format is 3105's real binary envelope.

---

## What it does

| Tab | From | Feature |
|---|---|---|
| **Tools** | GestaltEdit | Feature presets: Dynamic Island subtype, Always-On Display, AOD vibrancy, wallpaper parallax off, boot/shutdown chime, charge-limit menu, tap-to-wake, iPhone 16 camera control, Apple Pencil, Action Button, Collision SOS, Stage Manager, iPad apps, iPadOS mode, Apple Internal install, internal storage view, Security Research Device mode, Siri AI (US region). Tap **Apply** — an automatic backup is taken first, then the plist is rewritten and SpringBoard refreshes. |
| **Fields** | GestaltEdit | Advanced editor: search/edit any `CacheExtra` key or top-level key, change type (string/int/float/bool/data/array/dict), add or delete fields. |
| **Restore** | GestaltEdit | Every write is auto-backed up. Back up, import, export, and restore at any time. Restoring rewrites the plist and resprings. |
| **Patches** | 3105 | `.3105` encrypted patch packages: create a project, export it, import packages from other devices (password-protected variants require a password at import time in 3105 itself). |

## Requirements

- iOS / iPadOS **27 beta 1–4** (build `24A5355q`, `24A5370h`, `24A5380h`, `24A5380i`, `24A5380l`, `24A5390f`)
- Developer Mode enabled
- A signing/install method such as **[iLoader](https://github.com/nab138/iloader)** (signs with your own Apple ID, no paid certificate needed)

> The `bad_query` sandbox-extension path does not require a special entitlement or enterprise certificate. A normal free Apple ID / iLoader signature works.

## Install

1. Grab the latest IPA from **Actions → latest run → Artifacts → `CastKit-iOS`**.
2. Sign & install with [iLoader](https://iloader.app/), or any tool that signs with your Apple ID.
3. Trust the certificate under **Settings → General → VPN & Device Management**.
4. Enable **Developer Mode** if prompted.

## Build

```bash
git clone https://github.com/roVeloupe/CastKit.git
cd CastKit
brew install xcodegen
xcodegen generate
xcodebuild build -project CastKit.xcodeproj -scheme CastKit -sdk iphoneos -configuration Release
```

CI builds an (unsigned) IPA automatically on every push to `main`.

## Structure

```
CastKit/
├── Sources/
│   ├── CastKitApp.swift            # App entry + 4-tab root
│   ├── ContentView.swift           # Tools / Fields / Restore UIs (from GestaltEdit)
│   ├── GestaltModels.swift         # plist model, AI-region config (from GestaltEdit)
│   ├── GestaltTweaks.swift         # real preset catalog with real keys (from GestaltEdit)
│   ├── GestaltBackupStore.swift    # auto backups (from GestaltEdit)
│   ├── GestaltViewModel.swift      # apply/backup/restore logic (from GestaltEdit)
│   ├── NeoSpringView.swift         # respring (from GestaltEdit, based on neospring)
│   ├── AutomationCommand.swift     # --set-us-region CLI hook (from GestaltEdit)
│   ├── BadQueryBridge.{h,m}        # bad_query sandbox token (from GestaltEdit)
│   ├── GestaltAccess.{h,m}         # read/write MobileGestalt.plist (from GestaltEdit)
│   ├── PatchProjectModels.swift    # .3105 project model + validator (from 3105)
│   ├── PatchPackageCodec.swift     # .3105 envelope codec (from 3105)
│   ├── PatchKeyStore.swift         # keychain for package keys (from 3105)
│   └── PatchLibraryView.swift      # Patches tab UI (CastKit glue)
├── Resources/
│   ├── Info.plist
│   ├── CastKit.entitlements        # minimal (get-task-allow)
│   └── Assets.xcassets/            # AppIcon
├── project.yml                     # XcodeGen
└── .github/workflows/build.yml     # CI → unsigned IPA (+ optional enterprise signing)
```

## How the write works

`GestaltAccess` creates a ContainerManager query (class 13 / MobileGestalt SystemGroup / part 3) and asks for a sandbox extension to `/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist`. Once the extension is consumed, the live plist is opened `O_WRONLY` (preserving the inode), truncated, rewritten, `fsync`ed, and verified. This is the same mechanism both `bad_query` (forcequitOS) and GestaltEdit use — no jailbreak needed, works only on the supported OS builds listed above.

## Warnings

- Bad MobileGestalt values can break system features and may require restoring the device. Use only on devices you own. Every write is backed up first.
- Only supports iOS 27 beta 1–4. Other builds (incl. iOS 27 beta 5+) are rejected on startup.
- Respect the licenses below; neither project permits resale.

## License & Credits

This repository is licensed under **GPL-3.0** (see `LICENSE`, taken from the 3105 project), because it incorporates 3105's GPL-3.0 codec. Note that the **GestaltEdit** portions remain under its own **PolyForm Noncommercial 1.0.0** license — free for noncommercial use; commercial use is not permitted for the app as a whole.

- **GestaltEdit** — [PolyForm Noncommercial 1.0.0](https://github.com/frs0n/GestaltEdit/blob/main/LICENSE)
- **3105** — [GPL-3.0](https://github.com/YangJiiii/3105/blob/main/LICENSE)
- Parts of the respring implementation are based on [neospring](https://github.com/rooootdev/neospring).

This repository integrates portions of both upstream projects as-is (wholly renamed views aside). Upstream credits: [Nugget](https://github.com/leminlimez/Nugget) (presets & iPadOS support), [bad_query](https://github.com/forcequitOS/bad_query) & [0xJohnny](https://x.com/0xjohnny) (file access research).