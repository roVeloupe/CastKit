//
//  GestaltPatcher.swift
//  CastKit — MobileGestalt patch engine + feature definitions
//
//  MobileGestalt file path:
//  /var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/
//    Library/Caches/com.apple.MobileGestalt.plist
//

import Foundation
import SwiftUI
import Combine

// MARK: - Feature Registry

/// 所有可开关的 MobileGestalt patch 功能
struct GestaltFeature: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let miniOS: String?
    let keys: [String: Any]      // key → value
    let category: Category

    enum Category: String, CaseIterable {
        case display = "显示 & UI"
        case hardware = "硬件解锁"
        case audio = "声音"
        case tablet = "iPad / 多任务"
        case security = "安全 & 隐私"
        case model = "设备伪装"
    }
}

/// 所有功能定义（MobileGestalt key → value 映射）
enum FeatureDB {
    static let all: [GestaltFeature] = [

        // MARK: - 显示 & UI
        .init(
            id: "dynamic-island-2796",
            name: "灵动岛 (1290×2796)",
            icon: "airpods",
            description: "iPhone 12 等老机型开启 Dynamic Island，高分辨率",
            miniOS: "17.0",
            keys: [
                "h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone16,1",  // 假装 iPhone 15
                "DeviceSupportsAlwaysOnDisplay": true,
                "DisplayCapsLock": 2796
            ],
            category: .display
        ),
        .init(
            id: "dynamic-island-2556",
            name: "灵动岛 (1179×2556)",
            icon: "airpods.gen3",
            description: "灵动岛标准分辨率版本",
            miniOS: "17.0",
            keys: [
                "h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone16,1",
                "DeviceSupportsAlwaysOnDisplay": true,
                "DisplayCapsLock": 2556
            ],
            category: .display
        ),
        .init(
            id: "always-on-display",
            name: "始终显示 (AoD)",
            icon: "display",
            description: "iPhone 11 等机型开启 Always On Display",
            miniOS: "18.0",
            keys: ["DeviceSupportsAlwaysOnDisplay": true],
            category: .display
        ),
        .init(
            id: "charge-limit",
            name: "充电上限 80%",
            icon: "battery.75",
            description: "限制充电到 80% 保护电池寿命",
            miniOS: "16.0",
            keys: ["DeviceChargeLimitSupported": true],
            category: .hardware
        ),
        .init(
            id: "action-button",
            name: "操作按钮",
            icon: "button.programmable",
            description: "在 iPhone 12-14 上启用 Action Button",
            miniOS: "17.0",
            keys: ["DeviceSupportsActionButton": true],
            category: .hardware
        ),
        .init(
            id: "landscape-faceid",
            name: "横屏 Face ID",
            icon: "faceid",
            description: "允许横屏状态下 Face ID 解锁",
            miniOS: "17.0",
            keys: ["DeviceSupportsLandscapeFaceID": true],
            category: .hardware
        ),
        .init(
            id: "tap-to-wake",
            name: "点击唤醒",
            icon: "hand.tap",
            description: "iPhone SE 2/3 等机型启用 Tap to Wake",
            miniOS: "18.0",
            keys: ["DeviceSupportsTapToWake": true],
            category: .hardware
        ),

        // MARK: - Audio
        .init(
            id: "boot-chime",
            name: "启动音",
            icon: "speaker.wave.2",
            description: "开机 / 关机时播放经典启动音效",
            miniOS: "17.0",
            keys: ["DeviceSupportsBootChime": true],
            category: .audio
        ),
        .init(
            id: "shutter-sound-off",
            name: "相机静音",
            icon: "camera.fill",
            description: "去掉相机快门声（日本/韩国等强制有声地区）",
            miniOS: "16.0",
            keys: ["DeviceRegion": "US"],
            category: .audio
        ),

        // MARK: - iPad / 多任务
        .init(
            id: "stage-manager",
            name: "台前调度",
            icon: "rectangle.stack",
            description: "iPhone 上启用 Stage Manager 多窗口",
            miniOS: "16.0",
            keys: ["DeviceSupportsStageManager": true],
            category: .tablet
        ),
        .init(
            id: "ipad-apps",
            name: "iPad 应用兼容",
            icon: "ipad",
            description: "允许在 iPhone 上安装 iPad 版 App",
            miniOS: "16.0",
            keys: ["DeviceSupportsiPadApps": true],
            category: .tablet
        ),
        .init(
            id: "trollpad",
            name: "TrollPad (多窗口)",
            icon: "rectangle.on.rectangle",
            description: "iPhone 上启用多窗口拖拽（需要 macOS 配合）",
            miniOS: "18.0",
            keys: ["DeviceSupportsTrollPad": true],
            category: .tablet
        ),

        // MARK: - Apple Intelligence
        .init(
            id: "apple-intelligence",
            name: "Apple Intelligence",
            icon: "apple.intelligence",
            description: "开启 AI 摘要、写作工具、图片消除等功能",
            miniOS: "18.1",
            keys: [
                "A62OafQ85EJAiiqKn4agtg": 1,          // Generative Model capability
                "h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone16,1",  // 伪装 iPhone 15 下载模型
                "DeviceRegion": "US"                  // 绕地区限制
            ],
            category: .display
        ),

        // MARK: - 设备伪装
        .init(
            id: "spoof-iphone16pro",
            name: "伪装 iPhone 16 Pro",
            icon: "iphone",
            description: "把设备型号报成 iPhone 16 Pro (A18 Pro)",
            miniOS: "16.0",
            keys: ["h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone17,1"],
            category: .model
        ),
        .init(
            id: "spoof-iphone15pro",
            name: "伪装 iPhone 15 Pro",
            icon: "iphone.gen3",
            description: "把设备型号报成 iPhone 15 Pro (A17 Pro)",
            miniOS: "16.0",
            keys: ["h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone16,1"],
            category: .model
        ),
        .init(
            id: "spoof-ipadm4",
            name: "伪装 iPad Pro M4",
            icon: "ipad.gen2",
            description: "伪装成 iPad Pro M4 (A18)",
            miniOS: "16.0",
            keys: ["h9jDsbgj7xIVeIQ8S3/X3Q": "iPad16,3"],
            category: .model
        ),

        // MARK: - 其他
        .init(
            id: "developer-mode",
            name: "开发者模式",
            icon: "hammer",
            description: "强制开启 Developer Mode + Metal HUD",
            miniOS: "16.0",
            keys: ["DeviceSupportsDeveloperMode": true],
            category: .security
        ),
        .init(
            id: "sos-collision",
            name: "车祸 SOS",
            icon: "car.fill",
            description: "启用碰撞检测紧急 SOS",
            miniOS: "18.0",
            keys: ["DeviceSupportsCrashDetection": true],
            category: .hardware
        ),
        .init(
            id: "pwm-dimming",
            name: "启用 PWM 调光",
            icon: "rays",
            description: "某些老机型开启高频 PWM 调光",
            miniOS: "16.0",
            keys: ["DeviceSupportsPWM": true],
            category: .display
        )
    ]

    static func by(category: GestaltFeature.Category) -> [GestaltFeature] {
        all.filter { $0.category == category }
    }

    static func by(id: String) -> GestaltFeature? {
        all.first { $0.id == id }
    }
}

// MARK: - Patch Engine

/// 负责读写 MobileGestalt.plist 的核心引擎
actor GestaltPatcher {
    static let shared = GestaltPatcher()

    /// MobileGestalt.plist 路径（iOS 17+ BookRestore 可写入）
    let gestaltPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"

    /// 当前激活的 patch 列表
    @Published var enabledPatchIDs: Set<String> = []

    /// 日志
    @Published var logs: [String] = []

    /// 原始 gestalt 备份
    private(set) var backupData: Data?

    // MARK: - API

    func appendLog(_ msg: String) {
        logs.append("[\(Self.timestamp())] \(msg)")
    }

    func isEnabled(_ feature: GestaltFeature) -> Bool {
        enabledPatchIDs.contains(feature.id)
    }

    func toggle(_ feature: GestaltFeature) {
        if enabledPatchIDs.contains(feature.id) {
            enabledPatchIDs.remove(feature.id)
            appendLog("❌ 关闭: \(feature.name)")
        } else {
            enabledPatchIDs.insert(feature.id)
            appendLog("✅ 开启: \(feature.name)")
        }
    }

    /// 生成合并后的 patch dict
    func generateMergedPatch() -> [String: Any] {
        var merged: [String: Any] = [:]
        for fid in enabledPatchIDs {
            guard let f = FeatureDB.by(id: fid) else { continue }
            for (k, v) in f.keys {
                merged[k] = v
            }
        }
        return merged
    }

    /// 将 patch 应用到当前 plist（内存操作）
    func applyToPlist(_ dict: [String: Any]) -> [String: Any] {
        var result = dict
        let patches = generateMergedPatch()

        // MobileGestalt 的 key 是 base64 哈希或明文
        // 我们直接覆盖匹配的 key
        for (key, value) in patches {
            result[key] = value
            appendLog("  → \(key) = \(value)")
        }
        return result
    }

    /// 获取系统 iOS 版本
    var systemVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    // MARK: - 工具

    static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

// MARK: - iOS 版本比较扩展

extension String {
    func isAtLeast(_ target: String) -> Bool {
        let a = self.split(separator: ".").map { Int($0) ?? 0 }
        let b = target.split(separator: ".").map { Int($0) ?? 0 }
        let len = max(a.count, b.count)
        for i in 0..<len {
            let x = a.indices.contains(i) ? a[i] : 0
            let y = b.indices.contains(i) ? b[i] : 0
            if x < y { return false }
            if x > y { return true }
        }
        return true
    }
}
