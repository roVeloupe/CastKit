//
//  PosterBoard.swift
//  CastKit — 动态壁纸 / 锁屏壁纸定制引擎
//
//  3105 (YangJiiii) popularized portable wallpaper packages + .3105 patch format.
//

import Foundation
import UIKit

// MARK: - Poster Layer

/// One layer in a PosterBoard wallpaper
struct PosterLayer: Codable, Identifiable {
    let id: String
    let fileName: String
    let zPosition: Int
    let xOffset: CGFloat
    let yOffset: CGFloat
    let scale: CGFloat
    let blendMode: String
    let opacity: CGFloat
}

// MARK: - Poster Package (Identifiable)

struct PosterPackage: Codable, Identifiable {
    let id: String
    let name: String
    let bundleID: String
    let version: String
    let layers: [PosterLayer]
    let previewColorHex: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case bundleID = "BundleID"
        case version = "Version"
        case layers = "Layers"
        case previewColorHex = "PreviewColorHex"
    }

    init(name: String, bundleID: String, version: String,
         layers: [PosterLayer], previewColorHex: String) {
        self.id = bundleID
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.layers = layers
        self.previewColorHex = previewColorHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        version = try c.decode(String.self, forKey: .version)
        layers = try c.decode([PosterLayer].self, forKey: .layers)
        previewColorHex = try c.decode(String.self, forKey: .previewColorHex)
        id = bundleID
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(bundleID, forKey: .bundleID)
        try c.encode(version, forKey: .version)
        try c.encode(layers, forKey: .layers)
        try c.encode(previewColorHex, forKey: .previewColorHex)
    }

    static let defaultDark = PosterPackage(
        name: "暗夜紫",
        bundleID: "com.castkit.poster.darkpurple",
        version: "1.0",
        layers: [PosterLayer(id: "bg", fileName: "darkpurple_bg.heic",
                   zPosition: 0, xOffset: 0, yOffset: 0,
                   scale: 1.0, blendMode: "normal", opacity: 1.0)],
        previewColorHex: "#1a0a2e"
    )

    static let defaultOcean = PosterPackage(
        name: "海洋蓝",
        bundleID: "com.castkit.poster.ocean",
        version: "1.0",
        layers: [PosterLayer(id: "bg", fileName: "ocean_bg.heic",
                   zPosition: 0, xOffset: 0, yOffset: 0,
                   scale: 1.0, blendMode: "normal", opacity: 1.0)],
        previewColorHex: "#0d4f7a"
    )
}

// MARK: - PosterBoard Engine

final class PosterBoardEngine {
    static let shared = PosterBoardEngine()
    private init() {}

    var postersDir: String {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        return "\(base)/Posters"
    }

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
}

// MARK: - .3105 MobileGestalt Patch Package

/// Portable MobileGestalt patch — can be shared between devices / tools.
/// Uses manual Codable because patches is [String: Any].
struct PatchPackage {
    let name: String
    let description: String
    let version: String
    let iosMin: String
    let iosMax: String
    let patches: [String: Any]

    static let fileExtension = "3105-patch"

    func encodeToData() throws -> Data {
        let dict: [String: Any] = [
            "Name": name,
            "Description": description,
            "Version": version,
            "iOSMin": iosMin,
            "iOSMax": iosMax,
            "Patches": patches
        ]
        return try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    static func decode(from data: Data) throws -> PatchPackage {
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let d = obj as? [String: Any] else {
            throw NSError(domain: "PatchPackage", code: -1, userInfo: [NSLocalizedDescriptionKey: "plist root not a dict"])
        }
        return PatchPackage(
            name: d["Name"] as? String ?? "Untitled",
            description: d["Description"] as? String ?? "",
            version: d["Version"] as? String ?? "1.0",
            iosMin: d["iOSMin"] as? String ?? "16.0",
            iosMax: d["iOSMax"] as? String ?? "27.0",
            patches: d["Patches"] as? [String: Any] ?? [:]
        )
    }

    func write(to url: URL) throws {
        try encodeToData().write(to: url, options: .atomic)
    }

    static func load(from url: URL) throws -> PatchPackage {
        try decode(from: Data(contentsOf: url))
    }
}
