# 🔧 CastKit

> **MobileGestalt 完整 patch 工具链** — 从 iOS 端生成 patch，到电脑端完整应用 — 一次搞定

**支持 iOS 27 beta 1-4 / iOS 26.0-26.1 / iOS 17.0-18.7**

---

## ✅ 已验证的 20+ 功能开关

| 分类 | 功能 | 原理 Key |
|---|---|---|
| **显示 / UI** | 灵动岛 (2796 / 2556) | `h9jDsbgj7xIVeIQ8S3/X3Q` = `iPhone16,1` |
| | 始终显示 AoD | `DeviceSupportsAlwaysOnDisplay` = true |
| | Apple Intelligence | `A62OafQ85EJAiiqKn4agtg` = 1 |
| | PWM 调光 | `DeviceSupportsPWM` |
| **硬件解锁** | Action Button | `DeviceSupportsActionButton` |
| | 横屏 Face ID | `DeviceSupportsLandscapeFaceID` |
| | 充电上限 80% | `DeviceChargeLimitSupported` |
| | SOS 车祸检测 | `DeviceSupportsCrashDetection` |
| **声音** | 开机音 / 相机静音 | `DeviceSupportsBootChime` / `DeviceRegion=US` |
| **多任务** | 台前调度 / iPad Apps / TrollPad | `DeviceSupportsStageManager` 等 |
| **设备伪装** | iPhone 16 Pro / iPhone 15 Pro / iPad Pro M4 | `ProductType` spoof |

完整清单见 [`Sources/GestaltPatcher.swift`](Sources/GestaltPatcher.swift) 里的 `FeatureDB.all`。

---

## 🎯 为什么 CastKit 不一样

**其他工具**（misaka26 / Nugget / Cowabunga）：
- 要么只是电脑端 GUI
- 要么只做 SparseRestore / BookRestore 一个路径
- 要么只做生成器不做写入

**CastKit**：
- ✅ **iOS 端完整 UI** — 功能开关、patch 预览、文件系统探测
- ✅ **三路径写入** — 直接写 / CVE-2023-41991 / 电脑端 BookRestore
- ✅ **电脑端 companion** — Python `companion.py status/apply/export`
- ✅ **自动备份 / 恢复** — 防止 bootloop
- ✅ **无越狱依赖** — iOS 端只是生成器，写入靠电脑端 exploit

---

## 🚀 完整流程（iOS 27 beta 3）

```
┌─────────────────────┐     AirDrop     ┌────────────────────────┐
│   iPhone 端 CastKit  │ ──────────────→ │  Mac/PC 端              │
│                     │                  │                        │
│  1. 勾选功能        │                  │  python3 companion.py   │
│  2. 点「导出 Patch」│                  │    apply MobileGestalt  │
│  3. 生成 patched    │                  │    _patched.plist       │
│     plist           │                  │  ├─ 检测 iOS 版本      │
│                     │                  │  ├─ 走 BookRestore     │
│                     │                  │  └─ 设备自动 reboot ✅  │
└─────────────────────┘                  └────────────────────────┘
                                                      │
                                                      ▼
                                              设备重启后
                                              Dynamic Island ✅
                                              Apple Intelligence ✅
                                              Always On ✅
                                              ...
```

**一句话**：选好功能 → AirDrop → `python3 companion.py apply` → 等设备重启。

---

## 🛠️ 构建

### iOS 端 App

```bash
git clone https://github.com/roVeloupe/CastKit.git
cd CastKit
brew install xcodegen
xcodegen generate
open CastKit.xcodeproj
# Xcode → Product → Build For → iOS Device
```

**CI 自动构建**：https://github.com/roVeloupe/CastKit/actions/workflows/build.yml

配企业证书 Secret（`ENTERPRISE_P12_BASE64` / `ENTERPRISE_P12_PASSWORD` / `ENTERPRISE_CERT_NAME`）后自动签名，下载 IPA 装到设备。

### 电脑端 Companion

```bash
# macOS
brew install libimobiledevice  # idevice_id, ideviceinfo
python3 companion/companion.py status
python3 companion/companion.py apply MobileGestalt_patched.plist

# 或直接用 misaka26（更成熟的 GUI）
# brew install --cask misaka26
# misaka26 apply MobileGestalt_patched.plist
```

详见 [companion/README.md](companion/README.md)。

---

## 🔐 iOS 27 beta 3 上能用的 Exploit 链

| Exploit | CVE | 用途 | iOS 27 beta 3 状态 |
|---|---|---|---|
| **FilzaSlop** | CVE-2023-41991 + 41992 | sandbox 容器级逃逸 + MobileGestalt 路径遍历 | ✅ 未补 |
| **BookRestore** | KhanhduyTran 发现 | Apple Books 下载失败 → backup 恢复 | ✅ 未补（beta 5 开始补） |
| **SparseRestore** | JJTech0130 | backup 恢复到非标准路径 | ❌ iOS 18.2 已补 |
| **DarkSword** | 6 个 0day | 完整内核利用 → 越狱 | ❌ 针对 18.4-18.7 |

**结论**：iOS 27 beta 3 上 **BookRestore 是最干净的路径**——不需要越狱，不需要内核利用，只是备份恢复机制的误用。

---

## 📁 项目结构

```
CastKit/
├── Sources/
│   ├── CastKitApp.swift       # App entry + TabView
│   ├── GestaltPatcher.swift   # FeatureDB（20+ patch key）
│   ├── GestaltIO.swift        # MobileGestalt 读写引擎 + HouseArrest 路径
│   └── Views.swift            # 三 Tab UI + 完整应用面板
├── Resources/
│   ├── Info.plist
│   └── CastKit.entitlements   # no-sandbox + MobileGestalt.Read/Write
├── companion/
│   ├── companion.py          # 电脑端 BookRestore 客户端
│   └── README.md             # 完整电脑端使用说明
├── project.yml               # XcodeGen
└── .github/workflows/
    └── build.yml              # CI 自动构建 IPA
```

---

## ⚠️ 警告

- 修改 MobileGestalt **理论上会导致 bootloop**，请先完整备份
- iOS 26.2+ / iOS 27 beta 5+：Apple 封堵了 BookRestore 通道，本方法无效
- iOS 27 beta 5+ 请检查更新，FilzaSlop (CVE-2023-41991) 也可能被补
- CastKit 不提供越狱 / root 能力，只做 patch 生成 + 电脑端应用
- **后果自负**

---

## 📜 License

MIT — 参见 `LICENSE`

## 🙏 致谢

| 项目 | 贡献 |
|---|---|
| [straight-tamago/misaka26](https://github.com/straight-tamago/misaka26) | patch 清单 + GUI 客户端 |
| [leminlimez/Nugget](https://github.com/leminlimez/Nugget) | SparseRestore / BookRestore 实现 |
| [JJTech0130/TrollRestore](https://github.com/JJTech0130/TrollRestore) | SparseRestore 原始 writeup |
| [khanhduytran0](https://github.com/khanhduytran0) | BookRestore 发现者 |
| [34306/FilzaJailedDS](https://github.com/34306/FilzaJailedDS) | DarkSword + sandbox escape |
| [f1shy-dev gist](https://gist.github.com/f1shy-dev/23b4a78dc283edd30ae2b2e6429129b5) | Apple Intelligence 完整教程 |
