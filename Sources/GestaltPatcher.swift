//
//  GestaltPatcher.swift
//  CastKit — 核心 patch 引擎 + Feature 注册
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
struct GestaltFeature: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let miniOS: String?
    let keys: [String: Any]
    let category: Category

    enum Category: String, CaseIterable {
        case display = "Display & UI"
        case hardware = "Hardware Unlock"
        case audio = "Audio"
        case tablet = "iPad / Multitasking"
        case security = "Security"
        case model = "Device Spoof"
    }
}

/// 所有功能定义（MobileGestalt key → value 映射）
enum FeatureDB {
    static let all: [GestaltFeature] = [

        // MARK: - Display / UI
        .init(
            id: "dynamic-island-2796",
            name: "Dynamic Island (2796)",
            icon: "airpods",
            description: "Enable Dynamic Island on older iPhones — 1290×2796",
            miniOS: "17.0",
            keys: [
                "h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone16,1",
                "DeviceSupportsAlwaysOnDisplay": true,
                "DisplayCapsLock": 2796
            ],
            category: .display
        ),
        .init(
            id: "dynamic-island-2556",
            name: "Dynamic Island (2556)",
            icon: "airpods.gen3",
            description: "Enable Dynamic Island — 1179×2556",
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
            name: "Always-On Display",
            icon: "display",
            description: "Enable AoD on iPhone 11 / 12 series",
            miniOS: "18.0",
            keys: ["DeviceSupportsAlwaysOnDisplay": true],
            category: .display
        ),
        .init(
            id: "apple-intelligence",
            name: "Apple Intelligence",
            icon: "apple.intelligence",
            description: "Enable AI summary, writing tools, image eraser",
            miniOS: "18.1",
            keys: [
                "A62OafQ85EJAiiqKn4agtg": 1,
                "h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone16,1",
                "DeviceRegion": "US"
            ],
            category: .display
        ),
        .init(
            id: "pwm-dimming",
            name: "PWM Dimming",
            icon: "rays",
            description: "High-frequency PWM dimming on supported displays",
            miniOS: "16.0",
            keys: ["DeviceSupportsPWM": true],
            category: .display
        ),

        // MARK: - Hardware Unlock
        .init(
            id: "charge-limit",
            name: "Charge Limit 80%",
            icon: "battery.75",
            description: "Cap battery charge at 80% to preserve health",
            miniOS: "16.0",
            keys: ["DeviceChargeLimitSupported": true],
            category: .hardware
        ),
        .init(
            id: "action-button",
            name: "Action Button",
            icon: "button.programmable",
            description: "Enable Action Button on iPhone 12/13/14",
            miniOS: "17.0",
            keys: ["DeviceSupportsActionButton": true],
            category: .hardware
        ),
        .init(
            id: "landscape-faceid",
            name: "Landscape Face ID",
            icon: "faceid",
            description: "Allow Face ID unlock in landscape",
            miniOS: "17.0",
            keys: ["DeviceSupportsLandscapeFaceID": true],
            category: .hardware
        ),
        .init(
            id: "tap-to-wake",
            name: "Tap to Wake",
            icon: "hand.tap",
            description: "Enable Tap to Wake on iPhone SE 2/3",
            miniOS: "18.0",
            keys: ["DeviceSupportsTapToWake": true],
            category: .hardware
        ),
        .init(
            id: "sos-collision",
            name: "SOS Collision Detection",
            icon: "car.fill",
            description: "Enable Crash Detection emergency SOS",
            miniOS: "18.0",
            keys: ["DeviceSupportsCrashDetection": true],
            category: .hardware
        ),

        // MARK: - Audio
        .init(
            id: "boot-chime",
            name: "Boot Chime",
            icon: "speaker.wave.2",
            description: "Classic Mac startup / shutdown sound",
            miniOS: "17.0",
            keys: ["DeviceSupportsBootChime": true],
            category: .audio
        ),
        .init(
            id: "shutter-sound-off",
            name: "Shutter Sound Mute",
            icon: "camera.fill",
            description: "Bypass JP/KR forced shutter sound",
            miniOS: "16.0",
            keys: ["DeviceRegion": "US"],
            category: .audio
        ),

        // MARK: - iPad / Multitasking
        .init(
            id: "stage-manager",
            name: "Stage Manager",
            icon: "rectangle.stack",
            description: "Enable Stage Manager multi-window on iPhone",
            miniOS: "16.0",
            keys: ["DeviceSupportsStageManager": true],
            category: .tablet
        ),
        .init(
            id: "ipad-apps",
            name: "iPad Apps on iPhone",
            icon: "ipad",
            description: "Allow installing iPad apps on iPhone",
            miniOS: "16.0",
            keys: ["DeviceSupportsiPadApps": true],
            category: .tablet
        ),
        .init(
            id: "trollpad",
            name: "TrollPad Multi-Window",
            icon: "rectangle.on.rectangle",
            description: "Drag-drop multi-window (macOS companion)",
            miniOS: "18.0",
            keys: ["DeviceSupportsTrollPad": true],
            category: .tablet
        ),

        // MARK: - Device Spoof
        .init(
            id: "spoof-iphone16pro",
            name: "Spoof iPhone 16 Pro",
            icon: "iphone",
            description: "Report as iPhone 16 Pro (A18 Pro)",
            miniOS: "16.0",
            keys: ["h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone17,1"],
            category: .model
        ),
        .init(
            id: "spoof-iphone15pro",
            name: "Spoof iPhone 15 Pro",
            icon: "iphone.gen3",
            description: "Report as iPhone 15 Pro (A17 Pro)",
            miniOS: "16.0",
            keys: ["h9jDsbgj7xIVeIQ8S3/X3Q": "iPhone16,1"],
            category: .model
        ),
        .init(
            id: "spoof-ipadm4",
            name: "Spoof iPad Pro M4",
            icon: "ipad.gen2",
            description: "Report as iPad Pro M4 (A18)",
            miniOS: "16.0",
            keys: ["h9jDsbgj7xIVeIQ8S3/X3Q": "iPad16,3"],
            category: .model
        ),

        // MARK: - Security
        .init(
            id: "developer-mode",
            name: "Developer Mode",
            icon: "hammer",
            description: "Force enable Developer Mode + Metal HUD",
            miniOS: "16.0",
            keys: ["DeviceSupportsDeveloperMode": true],
            category: .security
        ),
        .init(
            id: "internal-storage",
            name: "Internal Storage",
            icon: "internaldrive",
            description: "Show Internal Storage in Settings",
            miniOS: "17.0",
            keys: ["DeviceSupportsInternalStorage": true],
            category: .security
        ),
    ]

    static func by(category: GestaltFeature.Category) -> [GestaltFeature] {
        all.filter { $0.category == category }
    }

    static func by(id: String) -> GestaltFeature? {
        all.first { $0.id == id }
    }
}

// MARK: - Core Patcher (class, observable)

/// 核心 patch 引擎 — ObservableObject 才能在 SwiftUI 里用 @EnvironmentObject
@MainActor
final class GestaltPatcher: ObservableObject {

    static let shared = GestaltPatcher()

    /// 当前激活的 patch 列表
    @Published var enabledPatchIDs: Set<String> = []

    /// 日志
    @Published var logs: [String] = []

    private init() {}

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
            appendLog("❌ Disabled: \(feature.name)")
        } else {
            enabledPatchIDs.insert(feature.id)
            appendLog("✅ Enabled: \(feature.name)")
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

    /// 获取系统 iOS 版本
    var systemVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    // MARK: - Utils

    static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}
