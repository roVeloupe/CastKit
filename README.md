# CastKit

> **Complete MobileGestalt patch toolchain** — generate patches on-device, apply them from your computer — in one workflow.

**Supports iOS 27 beta 1-4 / iOS 26.0-26.1 / iOS 17.0-18.7**

---

## Features (20+ toggles)

| Category | Toggle | Mechanism |
|---|---|---|
| **Display / UI** | Dynamic Island (2796 / 2556) | Spoof `h9jDsbgj7xIVeIQ8S3/X3Q` → `iPhone16,1` |
| | Always-On Display | `DeviceSupportsAlwaysOnDisplay = true` |
| | Apple Intelligence | `A62OafQ85EJAiiqKn4agtg = 1` + device spoof |
| | PWM Dimming | `DeviceSupportsPWM` |
| **Hardware** | Action Button | `DeviceSupportsActionButton` |
| | Landscape Face ID | `DeviceSupportsLandscapeFaceID` |
| | Charge Limit 80% | `DeviceChargeLimitSupported` |
| | SOS Collision Detection | `DeviceSupportsCrashDetection` |
| **Audio** | Boot Chime | `DeviceSupportsBootChime` |
| | Shutter Sound Mute | `DeviceRegion = US` (bypass JP/KR) |
| **Multitasking** | Stage Manager | `DeviceSupportsStageManager` |
| | iPad Apps on iPhone | `DeviceSupportsiPadApps` |
| | TrollPad Multi-Window | `DeviceSupportsTrollPad` |
| **Device Spoof** | iPhone 16 Pro / 15 Pro / iPad Pro M4 | `ProductType` spoof |

All keys defined in [`Sources/GestaltPatcher.swift`](Sources/GestaltPatcher.swift) → `FeatureDB.all`.

---

## Complete Flow (iOS 27 beta 3)

```
┌──────────────────────┐    AirDrop     ┌──────────────────────────┐
│  iPhone — CastKit     │ ──────────────→ │  Mac / Windows PC         │
│                      │                 │                          │
│  1. Pick features    │                 │  python3 companion.py     │
│  2. Tap "Export      │                 │    apply MobileGestalt    │
│     Patch"           │                 │    _patched.plist         │
│  3. Get patched .plist│                │  ├─ Detects iOS version   │
│                      │                 │  ├─ Picks BookRestore     │
│                      │                 │  └─ Device auto-reboots ✅ │
└──────────────────────┘                 └──────────────────────────┘
                                                     │
                                                     ▼
                                           After reboot:
                                           Dynamic Island ✅
                                           Apple Intelligence ✅
                                           Always-On ✅
                                           ...
```

**In one sentence**: pick features → AirDrop → `python3 companion.py apply` → wait for reboot.

---

## Build

### iOS App

```bash
git clone https://github.com/roVeloupe/CastKit.git
cd CastKit
brew install xcodegen
xcodegen generate
open CastKit.xcodeproj
# Xcode → Product → Build For → iOS Device
```

CI builds unsigned IPA automatically at **https://github.com/roVeloupe/CastKit/actions/workflows/build.yml**.

Set enterprise cert secrets (`ENTERPRISE_P12_BASE64` / `ENTERPRISE_P12_PASSWORD` / `ENTERPRISE_CERT_NAME`) for auto-signing.

### Computer Companion

```bash
# macOS
brew install libimobiledevice
python3 companion/companion.py status
python3 companion/companion.py apply MobileGestalt_patched.plist

# Windows: install iTunes (official, not Microsoft Store edition)
# then run the same commands
```

Or just use [misaka26](https://github.com/straight-tamago/misaka26) — CastKit's companion calls it automatically if installed.

Full companion guide → [`companion/README.md`](companion/README.md).

---

## Exploit Chain on iOS 27 beta 3

| Exploit | CVE / Author | Purpose | Status on beta 3 |
|---|---|---|---|
| **FilzaSlop** | CVE-2023-41991 + 41992 | Sandbox container escape + MobileGestalt path traversal | ✅ Not patched |
| **BookRestore** | khanhduytran | Apple Books download failure → backup restore write | ✅ Not patched (beta 5 starts patching) |
| **SparseRestore** | JJTech0130 | Backup restore to non-standard paths | ❌ Patched on iOS 18.2 |
| **DarkSword** | 6 zero-days | Full kernel exploit → jailbreak | ❌ Targets 18.4-18.7 only |

**Verdict**: BookRestore is the cleanest path on iOS 27 beta 3 — no jailbreak, no kernel exploit, just a backup/restore corner case.

---

## Project Structure

```
CastKit/
├── Sources/
│   ├── CastKitApp.swift       # App entry + TabView
│   ├── GestaltPatcher.swift   # FeatureDB (20+ patch keys)
│   ├── GestaltIO.swift        # MobileGestalt I/O engine + CVE-2023-41991 HouseArrest path
│   └── Views.swift            # Three-tab UI + apply panel + share sheet
├── Resources/
│   ├── Info.plist
│   └── CastKit.entitlements   # no-sandbox + MobileGestalt.Read/Write
├── companion/
│   ├── companion.py           # BookRestore / SparseRestore client
│   └── README.md              # Full Mac/Windows guide
├── project.yml                # XcodeGen
└── .github/workflows/
    └── build.yml               # CI → unsigned or enterprise-signed IPA
```

---

## ⚠️ Warning

- Modifying MobileGestalt **can cause bootloop** — back up your device first
- iOS 26.2+ / iOS 27 beta 5+: Apple closed the BookRestore write path. This tool will not work
- FilzaSlop (CVE-2023-41991) may also get patched in iOS 27 beta 5+ — check before updating
- CastKit is a **patch generator + companion tool**, not a jailbreak
- Use at your own risk

---

## License

MIT — see `LICENSE`

## Credits

| Project | Role |
|---|---|
| [straight-tamago/misaka26](https://github.com/straight-tamago/misaka26) | Patch key list + mature GUI client |
| [leminlimez/Nugget](https://github.com/leminlimez/Nugget) | SparseRestore / BookRestore reference impl |
| [JJTech0130/TrollRestore](https://github.com/JJTech0130/TrollRestore) | SparseRestore writeup |
| [khanhduytran0](https://github.com/khanhduytran0) | BookRestore discoverer |
| [34306/FilzaJailedDS](https://github.com/34306/FilzaJailedDS) | DarkSword + sandbox escape |
| [f1shy-dev](https://gist.github.com/f1shy-dev/23b4a78dc283edd30ae2b2e6429129b5) | Apple Intelligence full tutorial |
