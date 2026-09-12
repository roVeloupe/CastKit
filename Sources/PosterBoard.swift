//
//  PosterBoard.swift
//  CastKit — 动态壁纸 / 锁屏壁纸定制引擎
//
//  PosterBoard is the iOS 16+ system framework that manages
//  custom lock-screen / home-screen wallpaper layers.
//  3105 (YangJiiii) popularized portable wallpaper packages.
//
//  We implement two things:
//    1. .3105 wallpaper package (.plist + .heic layers) importer/exporter
//    2. Apply logic — writes into App container's PosterBoard plist
//       (needs HouseArrest exploit to escape to /Library/Preferences/)
//

import Foundation
import UIKit

// MARK: - Poster Layer Model

/// One layer in a PosterBoard wallpaper (foreground, background, etc.)
struct PosterLayer: Codable, Identifiable {
    let id: String
    let fileName: String      // .heic or .png file
    let zPosition: Int
    let xOffset: CGFloat
    let yOffset: CGFloat
    let scale: CGFloat
    let blendMode: String     // "normal", "multiply", "screen"
    let opacity: CGFloat

    enum CodingKeys: String, CodingKey {
        case id = "Identifier"
        case fileName = "FileName"
        case zPosition = "ZPosition"
        case xOffset = "XOffset"
        case yOffset = "YOffset"
        case scale = "Scale"
        case blendMode = "BlendMode"
        case opacity = "Opacity"
    }
}

/// Complete wallpaper package
struct PosterPackage: Codable {
    let name: String
    let bundleID: String
    let version: String
    let layers: [PosterLayer]
    let previewColorHex: String  // fallback when no preview image

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case bundleID = "BundleID"
        case version = "Version"
        case layers = "Layers"
        case previewColorHex = "PreviewColorHex"
    }

    static let defaultDark = PosterPackage(
        name: "暗夜紫",
        bundleID: "com.castkit.poster.darkpurple",
        version: "1.0",
        layers: [
            PosterLayer(id: "bg", fileName: "darkpurple_bg.heic",
                       zPosition: 0, xOffset: 0, yOffset: 0,
                       scale: 1.0, blendMode: "normal", opacity: 1.0)
        ],
        previewColorHex: "#1a0a2e"
    )

    static let defaultOcean = PosterPackage(
        name: "海洋蓝",
        bundleID: "com.castkit.poster.ocean",
        version: "1.0",
        layers: [
            PosterLayer(id: "bg", fileName: "ocean_bg.heic",
                       zPosition: 0, xOffset: 0, yOffset: 0,
                       scale: 1.0, blendMode: "normal", opacity: 1.0)
        ],
        previewColorHex: "#0d4f7a"
    )
}

// MARK: - PosterBoard Engine

final class PosterBoardEngine {

    static let shared = PosterBoardEngine()
    private init() {}

    // MARK: - Paths

    var postersDir: String {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        return "\(base)/Posters"
    }

    // MARK: - Manage Packages

    /// List all packages we know about (built-in + imported).
    func listPackages() -> [PosterPackage] {
        var builtin: [PosterPackage] = [.defaultDark, .defaultOcean]

        let fm = FileManager.default
        if fm.fileExists(atPath: postersDir) {
            for fname in (try? fm.contentsOfDirectory(atPath: postersDir)) ?? [] {
                if fname.hasSuffix(".3105"),
                   let data = fm.contents(atPath: "\(postersDir)/\(fname)"),
                   let pkg = try? PropertyListDecoder().decode(PosterPackage.self, from: data) {
                    builtin.append(pkg)
                }
            }
        }
        return builtin
    }

    /// Import a .3105 plist package (from file URL or data).
    func importPackage(from url: URL) throws -> PosterPackage {
        let data = try Data(contentsOf: url)
        return try importPackage(data: data)
    }

    func importPackage(data: Data) throws -> PosterPackage {
        let pkg = try PropertyListDecoder().decode(PosterPackage.self, from: data)

        let fm = FileManager.default
        if !fm.fileExists(atPath: postersDir) {
            try fm.createDirectory(atPath: postersDir, withIntermediateDirectories: true)
        }

        let fname = "\(pkg.bundleID).3105"
        let outPath = "\(postersDir)/\(fname)"
        try data.write(to: URL(fileURLWithPath: outPath), options: .atomic)

        return pkg
    }

    func deletePackage(_ pkg: PosterPackage) throws {
        let p = "\(postersDir)/\(pkg.bundleID).3105"
        if FileManager.default.fileExists(atPath: p) {
            try FileManager.default.removeItem(atPath: p)
        }
    }

    // MARK: - Apply (simplified)

    /// On a jailbroken / HouseArrest device, PosterBoard writes go to:
    ///   /var/containers/Shared/SystemGroup/com.apple.containershared/.../PosterBoard.plist
    /// or App container's own preferences.
    ///
    /// On a jailed device we can only preview — real apply needs CVE-2023-41991.
    func apply(_ pkg: PosterPackage, via houseArrest: HouseArrestExploit? = nil) -> Bool {
        guard let ha = houseArrest else { return false }

        // PosterBoard's config lives in the App container's preferences
        let prefs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].path
        let target = "\(prefs)/Preferences/\(pkg.bundleID).plist"

        do {
            let data = try PropertyListEncoder().encode(pkg)
            let gestaltTarget = "…" // not really; we just know where to write
            // Actually PosterBoard apply is more complex than this
            // We'd need to inject into the right process. Skip for now.
            return false
        } catch {
            return false
        }
    }
}

// MARK: - .3105 Patch Package (MobileGestalt patch as a single file)

/// Portable .3105 patch file — bundles a MobileGestalt plist diff
/// so it can be shared between devices / tools.
struct PatchPackage: Codable {
    let name: String
    let description: String
    let version: String
    let iosMin: String
    let iosMax: String
    let patches: [String: Any]   // MobileGestalt key → value

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case description = "Description"
        case version = "Version"
        case iosMin = "iOSMin"
        case iosMax = "iOSMax"
        case patches = "Patches"
    }

    static let fileExtension = "3105-patch"

    func write(to url: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    static func load(from url: URL) throws -> PatchPackage {
        let data = try Data(contentsOf: url)
        return try PropertyListDecoder().decode(PatchPackage.self, from: data)
    }
}
