# CastKit Companion — 电脑端 Patch 应用器

> iOS 27 beta 3 / 26.0-26.1 / 18.2+ 上**真正写入 MobileGestalt.plist** 的完整链路

---

## 📋 支持的 iOS 版本

| iOS 版本 | Exploit 路径 | 状态 |
|---|---|---|
| **iOS 27 beta 1-4** | BookRestore | ✅ 可用（你现在这个版本） |
| iOS 26.0 - 26.1 | BookRestore | ✅ 可用 |
| iOS 26.2+ | — | ❌ Apple 封堵了 MobileGestalt 写通道 |
| iOS 18.2 - 18.7 | BookRestore | ✅ 可用 |
| iOS 17.0 - 18.1.1 | SparseRestore | ✅ 可用 |
| iOS 16.x | KFD | ❌ CastKit 不支持 |

---

## 🚀 快速开始

### Step 1: iOS 端 CastKit 生成 patch

1. 安装 CastKit IPA 到 iPhone（AltStore / Sideloadly / TrollStore / 企业证书）
2. 打开 CastKit → 勾选要开启的功能
3. 点「**导出 Patch**」→ AirDrop 到 Mac/PC

### Step 2: 电脑端应用 patch

#### macOS

```bash
# 1. 安装依赖
brew install libimobiledevice   # idevice_id, ideviceinfo, idevicebackup2

# 2. 检测设备
python3 companion.py status

# 3. 应用 patch
python3 companion.py apply MobileGestalt_patched.plist
```

#### Windows

```bash
# 1. 安装 iTunes（官方版，不要 Microsoft Store 版）
#    https://secure-appldnld.apple.com/itunes12/...

# 2. 安装 Python + 让它能找到 iTunesMobileDevice.dll
#    最简单：直接用 misaka26

# 3. 应用 patch
python companion.py apply MobileGestalt_patched.plist
```

#### Linux

```bash
# libimobiledevice 还没完全同步 iOS 27 beta
# 建议用 macOS 或 Windows
```

### Step 3: 等待设备 Reboot

- BookRestore 会触发设备自动重启
- 重启后新的 MobileGestalt.plist 生效
- **效果：Dynamic Island / Apple Intelligence / AoD / ...**

---

## 🛠️ 直接用 misaka26（更快）

misaka26 是最成熟的 BookRestore / SparseRestore 客户端，CastKit 的 companion.py 也会自动调用它（如果装了）。

```bash
# macOS
brew tap straight-tamago/misaka26
brew install --cask misaka26

# Windows
# 下载：https://github.com/straight-tamago/misaka26/releases

# 用法（GUI）
open misaka26.app
# 选设备 → 导入 plist → Apply

# 用法（CLI）
misaka26 apply MobileGestalt_patched.plist
```

---

## 📊 完整流程对照

```
┌─────────────────────────────────────────────────────────────┐
│                    CastKit 完整应用链                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  iOS 端 CastKit                                             │
│  ├─ 功能开关 UI ──────────┐                                 │
│  ├─ MobileGestalt key 合并 │                                 │
│  ├─ 生成 patched plist    │                                 │
│  └─ 点击「导出 Patch」────┤─── AirDrop / USB ──→ 电脑端      │
│                           │                                 │
│                           ▼                                 │
│  电脑端 companion.py / misaka26                              │
│  ├─ 检测设备 + iOS 版本                                    │
│  ├─ 选择 exploit 路径                                      │
│  │   ├─ BookRestore (iOS 18.2-26.1 / 27 beta)              │
│  │   │   └─ 触发 Apple Books 下载失败 → restore 写入       │
│  │   └─ SparseRestore (iOS 17.0-18.1)                      │
│  │       └─ 构造包含 MobileGestalt 的 backup 恢复          │
│  └─ 设备自动 reboot                                        │
│                                                             │
│  设备重启后 → Dynamic Island ✅ / Apple Intelligence ✅ / ...│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 恢复原始 MobileGestalt

CastKit iOS 端每次应用 patch 前会自动备份到 sandbox Documents/CastKitBackups/。

**恢复方法**：
1. 从备份里找到 `gestalt_backup_*.plist`
2. 电脑端 `misaka26 apply gestalt_backup_*.plist`
3. 或者电脑端 `idevicebackup2 restore --system-settings`
4. 或者直接刷回原厂系统

---

## ⚠️ 警告

- **修改 MobileGestalt 可能导致 bootloop** — 虽然概率很低但不是零
- iOS 26.2+ / iOS 27 beta 5+：Apple 封堵了 BookRestore 通道，本方法无效
- 本 companion 只是 patch 应用器，不负责越狱或 root
- 设备 bootloop 时，强制重启（Power + VolUp），等 30 秒会自动 fallback

---

## 📚 参考

| 项目 | 说明 |
|---|---|
| [straight-tamago/misaka26](https://github.com/straight-tamago/misaka26) | 最成熟的 GUI 客户端 |
| [leminlimez/Nugget](https://github.com/leminlimez/Nugget) | SparseRestore / BookRestore 实现 |
| [JJTech0130/TrollRestore](https://github.com/JJTech0130/TrollRestore) | 原始 SparseRestore writeup |
| [khanhduytran0](https://github.com/khanhduytran0) | BookRestore 发现者 |
| [f1shy-dev Apple Intelligence gist](https://gist.github.com/f1shy-dev/23b4a78dc283edd30ae2b2e6429129b5) | AI 完整教程 |
