# 🔧 CastKit

> MobileGestalt 动态 patch 工具 —— 把老 iPhone 上被 Apple 隐藏的功能全部打开

---

## 🎯 能做什么

| 功能 | iOS 版本 | 原理 |
|---|---|---|
| **灵动岛** (iPhone 16 风格) | 17.0+ | MobileGestalt key 强制启用 |
| **Apple Intelligence** | 18.1 Beta 4 | Generative Model capability + 伪装设备型号下载模型 |
| **始终显示 (AoD)** | 18.0+ | `DeviceSupportsAlwaysOnDisplay = true` |
| **Action Button** | 17.0+ | 在 iPhone 12-14 上启用长按按钮 |
| **充电上限 80%** | 16.0+ | 电池健康管理 |
| **开机音** | 17.0+ | 经典 Mac 启动音 |
| **相机静音** | 16.0+ | 绕日本/韩国强制有声地区 |
| **台前调度** | 16.0+ | iPhone 多窗口 |
| **横屏 Face ID** | 17.0+ | 横屏解锁 |
| **点击唤醒** | 18.0+ | iPhone SE 等 |
| **TrollPad 多窗口** | 18.0+ | 拖拽式多窗口 |
| **伪装 iPhone 15/16 Pro** | 16.0+ | ProductType spoof |
| **伪装 iPad Pro M4** | 16.0+ | 解锁 iPadOS 独占功能 |
| **SOS 车祸检测** | 18.0+ | 紧急碰撞 SOS |
| **Metal HUD 开发者模式** | 16.0+ | 性能 overlay |

完整 patch 清单见 [`Sources/GestaltPatcher.swift`](Sources/GestaltPatcher.swift)。

---

## 🔓 利用链要求

CastKit 本身是 patch **生成器**，要把 patch 写进系统需要以下任一 exploit：

| Exploit | iOS 版本 | 写入方式 |
|---|---|---|
| **CVE-2023-41991** (FilzaSlop) | 27 beta 1-4 | HouseArrest 容器逃逸 + MobileGestalt patch |
| **BookRestore** (TrollRestore 后续) | 18.2 - 26.1 | Apple Books 下载失败触发 restore |
| **SparseRestore** | 17.0 - 18.1.1 | 备份恢复漏洞 |
| **Jailbreak + ldid** | 任意 | root 直接写 plist |

**MobileGestalt.plist 路径**：
```
/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist
```

⚠️ **iOS 26.2+ / iOS 27 beta 5+**：Apple 已修补 SparseRestore / BookRestore 路径，MobileGestalt 写通道关闭。

---

## 🏗️ 构建

本仓库自带 GitHub Actions，自动构建无签名 IPA：

```bash
git clone https://github.com/roVeloupe/CastKit.git
cd CastKit
brew install xcodegen
xcodegen generate
open CastKit.xcodeproj
# Xcode → Product → Build For → iOS Device
```

CI：**https://github.com/roVeloupe/CastKit/actions/workflows/build.yml**

### 用企业证书签名

在 GitHub Repository Secrets 里配置：

| Secret | 说明 |
|---|---|
| `ENTERPRISE_P12_BASE64` | p12 文件的 base64 内容 |
| `ENTERPRISE_P12_PASSWORD` | p12 密码 |
| `ENTERPRISE_CERT_NAME` | 证书 Common Name |

Workflows 会自动构建并签名，下载 IPA 装到设备即可。

---

## 🗺️ 架构

```
CastKit/
├── Sources/
│   ├── CastKitApp.swift       # App entry + TabView
│   ├── GestaltPatcher.swift   # 核心引擎 + FeatureDB（所有 patch key 定义）
│   └── Views.swift            # SwiftUI 三个 tab
├── Resources/
│   ├── Info.plist
│   └── CastKit.entitlements   # 含 no-sandbox / MobileGestalt 读写
├── project.yml                # XcodeGen 配置
└── .github/workflows/
    └── build.yml              # GitHub Actions CI
```

---

## ⚠️ 警告

- 修改 MobileGestalt **理论上会导致 bootloop**，请先完整备份
- iOS 26.2+ / iOS 27 beta 5+：Apple 已封堵 SparseRestore / BookRestore
- 本仓库只提供 patch **生成和配置**，不包含越狱或注入能力
- 若用于实际设备修改，**后果自负**

---

## 📜 License

MIT — 参见 `LICENSE`

## 🙏 致谢

- [straight-tamago/misaka26](https://github.com/straight-tamago/misaka26) — patch 清单来源
- [leminlimez/Nugget](https://github.com/leminlimez/Nugget) — SparseRestore / BookRestore 实现
- [JJTech0130/TrollRestore](https://github.com/JJTech0130/TrollRestore) — BookRestore 利用
- [cowabunga](https://github.com/leminlimez/cowabunga) — 最早的 MobileGestalt patch 工具
- [f1shy-dev gist](https://gist.github.com/f1shy-dev/23b4a78dc283edd30ae2b2e6429129b5) — Apple Intelligence 教程
