//
//  GestaltIO.swift
//  CastKit — MobileGestalt.plist I/O engine
//
//  Target path:
//  /var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/
//    Library/Caches/com.apple.MobileGestalt.plist
//
//  On iOS 27 beta 3, three write paths exist:
//  A) Direct write (requires no-sandbox / root — not available)
//  B) CVE-2023-41991 HouseArrest XPC path traversal
//  C) Export patched plist → BookRestore from companion (RECOMMENDED)
//

import Foundation
import SwiftUI
import Combine

// MARK: - Errors

enum GestaltError: LocalizedError {
    case readFailed(String)
    case writeFailed(String)
    case mergeFailed(String)
    case backupFailed(String)
    case noValidPath
    case sandboxBlocked

    var errorDescription: String? {
        switch self {
        case .readFailed(let p): return "Read failed: \(p)"
        case .writeFailed(let p): return "Write failed: \(p)"
        case .mergeFailed(let m): return "Merge failed: \(m)"
        case .backupFailed(let m): return "Backup failed: \(m)"
        case .noValidPath: return "No accessible MobileGestalt path found"
        case .sandboxBlocked: return "Sandbox blocks direct write to target path"
        }
    }
}

// MARK: - GestaltIO (class, observable)

/// MobileGestalt.plist read/write engine.
/// Plain class — file I/O is synchronous; UI calls run on MainActor via Task.
final class GestaltIO: ObservableObject {

    static let shared = GestaltIO()

    // MARK: - Paths

    let gestaltRealPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"

    private var appTmpDir: String { NSTemporaryDirectory() }

    private var backupDir: String {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        return "\(base)/CastKitBackups"
    }

    private init() {}

    // MARK: - Probe

    /// Probe which paths are currently accessible from our sandbox.
    func probeReadable() -> [String: Bool] {
        var results: [String: Bool] = [:]
        results["Real path (root)"] = access(gestaltRealPath, R_OK) == 0
        let parentDir = (gestaltRealPath as NSString).deletingLastPathComponent
        results["Parent dir"] = access(parentDir, R_OK) == 0
        results["Parent dir (X)"] = access(parentDir, X_OK) == 0
        return results
    }

    // MARK: - Read

    /// Try to read MobileGestalt.plist from known paths.
    func readGestalt() throws -> [String: Any] {
        let fm = FileManager.default

        if fm.fileExists(atPath: gestaltRealPath),
           let data = fm.contents(atPath: gestaltRealPath) {
            return try parsePlist(data: data)
        }

        // Fallback: Shortcut-exported plist in Documents
        let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        for candidate in ["MobileGestalt.plist", "gestalt.plist", "mobilegestalt.plist"] {
            let p = "\(docDir)/\(candidate)"
            if fm.fileExists(atPath: p), let data = fm.contents(atPath: p) {
                return try parsePlist(data: data)
            }
        }

        throw GestaltError.noValidPath
    }

    // MARK: - Merge

    func mergePatch(_ patch: [String: Any], into original: [String: Any]) -> [String: Any] {
        var result = original
        for (key, value) in patch {
            if let value = value as? Bool      { result[key] = NSNumber(value: value) }
            else if let value = value as? Int  { result[key] = NSNumber(value: value) }
            else if let value = value as? String { result[key] = value }
            else                                { result[key] = value }
        }
        return result
    }

    func serializePlist(_ dict: [String: Any], format: PropertyListSerialization.PropertyListFormat = .xml) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0)
    }

    // MARK: - Write

    enum WriteStrategy: String, CaseIterable {
        case direct = "Direct write"
        case houseArrest = "CVE-2023-41991 HouseArrest"
        case companion = "Export → BookRestore (RECOMMENDED)"
    }

    /// Attempt to write. Returns which strategy actually succeeded.
    @discardableResult
    func writeGestalt(_ dict: [String: Any], strategy: WriteStrategy = .companion) throws -> WriteStrategy {
        let fm = FileManager.default
        let data = try serializePlist(dict, format: .binary)

        try backupCurrentIfExists()

        switch strategy {
        case .direct:
            guard fm.fileExists(atPath: gestaltRealPath) else { throw GestaltError.noValidPath }
            try data.write(to: URL(fileURLWithPath: gestaltRealPath), options: .atomic)
            return .direct

        case .houseArrest:
            // Full XPC implementation lives in FilzaSlop (CVE-2023-41991).
            // See: companion/README.md + 34306/FilzaJailedDS sandbox_escape.m
            throw GestaltError.writeFailed(
                "HouseArrest XPC path requires CVE-2023-41991 exploit — not implemented in CastKit. " +
                "Use companion path C instead."
            )

        case .companion:
            // Generate patched plist in tmp — caller shares it via UIActivityViewController
            let url = try generatePatchedPlist(dict)
            // Record last output path so UI can pick it up
            UserDefaults.standard.set(url.path, forKey: "castkit.lastExportPath")
            return .companion
        }
    }

    /// Generate a standalone patched plist file (XML) ready for export.
    func generatePatchedPlist(_ dict: [String: Any]) throws -> URL {
        let data = try serializePlist(dict, format: .xml)
        let fm = FileManager.default
        if !fm.fileExists(atPath: appTmpDir) {
            try fm.createDirectory(atPath: appTmpDir, withIntermediateDirectories: true)
        }
        let url = URL(fileURLWithPath: appTmpDir).appendingPathComponent("MobileGestalt_patched.plist")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Backup

    func backupCurrentIfExists() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: gestaltRealPath),
              let data = fm.contents(atPath: gestaltRealPath) else { return }

        if !fm.fileExists(atPath: backupDir) {
            try fm.createDirectory(atPath: backupDir, withIntermediateDirectories: true)
        }

        let ts = DateFormatter()
        ts.dateFormat = "yyyyMMdd_HHmmss"
        let fname = "gestalt_backup_\(ts.string(from: Date())).plist"
        try data.write(to: URL(fileURLWithPath: "\(backupDir)/\(fname)"), options: .atomic)
    }

    func listBackups() -> [String] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupDir) else { return [] }
        return (try? fm.contentsOfDirectory(atPath: backupDir).sorted()) ?? []
    }

    // MARK: - Private

    private func parsePlist(data: Data) throws -> [String: Any] {
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = obj as? [String: Any] else {
            throw GestaltError.mergeFailed("Root plist object is not a dict")
        }
        return dict
    }
}

// MARK: - CVE-2023-41991 HouseArrest Path Traversal (reference only)

/// CVE-2023-41991: HouseArrest daemon concatenates user-supplied filename
/// without normalizing `..`, letting an app escape its sandbox container.
///
/// Normal path:
///   /var/containers/Bundle/Application/<UUID>/CastKit.app/<filename>
///
/// With `../` traversal:
///   /var/containers/Bundle/Application/<UUID>/CastKit.app/
///     ../../../../Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/
///     Library/Caches/com.apple.MobileGestalt.plist
///   → resolves to /var/containers/Shared/SystemGroup/...  ✅ outside sandbox
///
/// This is how FilzaSlop (Filza iOS on jailed devices) writes MobileGestalt.plist.
/// The full XPC implementation belongs in a jailbreak-style tweak; we document
/// it here for reference.
enum HouseArrestPathTraversal {
    static let serviceName = "com.apple.housearrestd"

    /// 4 levels up from CastKit.app → /var/containers/
    static let depthToContainersRoot = 4

    /// Constructs the malicious relative path from App bundle to target file.
    static func relativePathTo(_ targetAbsolute: String) -> String? {
        guard targetAbsolute.hasPrefix("/var/containers/") else { return nil }
        guard let idx = targetAbsolute.split(separator: "/").firstIndex(of: "Shared") else { return nil }
        let suffix = targetAbsolute.split(separator: "/")[idx...].joined(separator: "/")
        return String(repeating: "../", count: depthToContainersRoot) + suffix
    }
}
