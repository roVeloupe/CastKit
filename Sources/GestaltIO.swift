//
//  GestaltIO.swift
//  CastKit — MobileGestalt.plist 读写引擎
//
//  目标文件：
//  /var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/
//    Library/Caches/com.apple.MobileGestalt.plist
//
//  注意：iOS 27 beta 3 上有 3 条写入路径
//

import Foundation

// MARK: - GestaltIO

enum GestaltError: LocalizedError {
    case readFailed(String)
    case writeFailed(String)
    case mergeFailed(String)
    case backupFailed(String)
    case noValidPath
    case sandboxBlocked

    var errorDescription: String? {
        switch self {
        case .readFailed(let p): return "读文件失败: \(p)"
        case .writeFailed(let p): return "写文件失败: \(p)"
        case .mergeFailed(let m): return "合并失败: \(m)"
        case .backupFailed(let m): return "备份失败: \(m)"
        case .noValidPath: return "找不到可访问的 MobileGestalt 路径"
        case .sandboxBlocked: return "当前沙箱不允许直接写目标路径"
        }
    }
}

/// MobileGestalt.plist 的读写引擎
actor GestaltIO {

    // MARK: - 路径常量

    /// MobileGestalt.plist 的**真实路径**（只有 root 或特定 entitlement 进程能直接写）
    let gestaltRealPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"

    /// App Group 共享路径 — 任何 App 带 `group.com.apple.mobilegestaltcache` entitlement 都能**读**
    /// 但 iOS 上实际没有 App 自动拿到这个 group，所以这个路径通常也写不了
    let sharedContainerBase = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache"

    /// 我们自己的 App sandbox tmp 目录
    var appTmpDir: String { NSTemporaryDirectory() }

    /// 备份目录（在我们 sandbox 内）
    var backupDir: String {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        return "\(base)/CastKitBackups"
    }

    // MARK: - API

    /// 检查目标路径是否可读（多种路径尝试）
    func probeReadable() -> [String: Bool] {
        var results: [String: Bool] = [:]

        // 1. 真实路径
        results["真实路径 (root)"] = access(gestaltRealPath, R_OK) == 0

        // 2. 父目录逐层 stat
        let parentDir = (gestaltRealPath as NSString).deletingLastPathComponent
        results["父目录"] = access(parentDir, R_OK) == 0
        results["父目录 (X_OK)"] = access(parentDir, X_OK) == 0

        // 3. HouseArrest 容器（如果我们有 CVE-2023-41991 容器映射）
        // 这个只能在 exploit 跑起来后才能确认

        // 4. 用 plutil 读
        let p = Process()
        p.launchPath = "/usr/bin/plutil"
        p.arguments = ["-lint", gestaltRealPath]
        let pipe = Pipe()
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
            results["plutil lint"] = p.terminationStatus == 0
        } catch {
            results["plutil lint"] = false
        }

        return results
    }

    /// 尝试读取 MobileGestalt.plist（多种路径）
    func readGestalt() throws -> [String: Any] {
        let fm = FileManager.default

        // 优先尝试真实路径
        if fm.fileExists(atPath: gestaltRealPath),
           let data = fm.contents(atPath: gestaltRealPath) {
            return try parsePlist(data: data)
        }

        // 再尝试 Shortcut 导出到我们 Documents 目录的备份
        let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        for candidate in ["MobileGestalt.plist", "gestalt.plist", "mobilegestalt.plist"] {
            let p = "\(docDir)/\(candidate)"
            if fm.fileExists(atPath: p), let data = fm.contents(atPath: p) {
                return try parsePlist(data: data)
            }
        }

        throw GestaltError.noValidPath
    }

    /// 把 patch 合并到现有 gestalt dict，返回修改后的 dict
    func mergePatch(_ patch: [String: Any], into original: [String: Any]) -> [String: Any] {
        var result = original

        for (key, value) in patch {
            if let value = value as? Bool {
                result[key] = NSNumber(value: value)
            } else if let value = value as? Int {
                result[key] = NSNumber(value: value)
            } else if let value = value as? String {
                result[key] = value
            } else {
                result[key] = value
            }
        }

        return result
    }

    /// 将 dict 序列化为 plist 数据
    func serializePlist(_ dict: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        )
    }

    /// 将 dict 序列化为 XML plist 数据（方便用户查看/编辑）
    func serializeXMLPlist(_ dict: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .xml,
            options: 0
        )
    }

    // MARK: - 写入策略

    /// 尝试写入 MobileGestalt.plist（多策略依次尝试）
    enum WriteStrategy: String {
        case direct = "直接写真实路径"
        case houseArrest = "CVE-2023-41991 HouseArrest"
        case userDefaults = "App 内 userDefaults（仅本机生效）"
    }

    func writeGestalt(_ data: Data, strategy: WriteStrategy = .direct) throws -> WriteStrategy {
        let fm = FileManager.default

        // 先备份
        try backupCurrentIfExists()

        switch strategy {
        case .direct:
            // 直接写真实路径（需要 no-sandbox 或 root）
            if fm.fileExists(atPath: gestaltRealPath) {
                do {
                    try data.write(to: URL(fileURLWithPath: gestaltRealPath), options: .atomic)
                    return .direct
                } catch {
                    throw GestaltError.writeFailed("直接写失败: \(error.localizedDescription)")
                }
            }
            throw GestaltError.noValidPath

        case .houseArrest:
            // 通过 CVE-2023-41991 HouseArrest 路径遍历写入
            // 这需要与 HouseArrest daemon 建立 XPC 连接
            // 实际实现在下面的 HouseArrestXPC 里
            throw GestaltError.writeFailed("HouseArrest 路径需要完整 XPC 实现")

        case .userDefaults:
            // 兜底：写进我们自己 App 的 userDefaults
            // 不能真的改系统，但能让 App 内的 patch 预览生效
            let ud = UserDefaults.standard
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) {
                ud.set(plist, forKey: "castkit.lastPatch")
                ud.synchronize()
            }
            return .userDefaults
        }
    }

    /// 生成"修改后的完整 MobileGestalt.plist"到临时文件
    /// 用户可以 AirDrop / Shortcut 转给电脑用 misaka26 应用
    func generatePatchedPlist(_ patch: [String: Any], from original: [String: Any]? = nil) throws -> URL {
        let finalDict = try original ?? readGestalt()
        let merged = mergePatch(patch, into: finalDict)
        let data = try serializeXMLPlist(merged)

        let fm = FileManager.default
        let tmpDir = appTmpDir
        if !fm.fileExists(atPath: tmpDir) {
            try fm.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        }

        let url = URL(fileURLWithPath: tmpDir).appendingPathComponent("MobileGestalt_patched.plist")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - 备份

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

    /// 列出现有备份
    func listBackups() -> [String] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupDir) else { return [] }
        return (try? fm.contentsOfDirectory(atPath: backupDir).sorted()) ?? []
    }

    // MARK: - Private

    private func parsePlist(data: Data) throws -> [String: Any] {
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = obj as? [String: Any] else {
            throw GestaltError.mergeFailed("plist 根节点不是字典")
        }
        return dict
    }
}

// MARK: - CVE-2023-41991 HouseArrest XPC 路径

/// CVE-2023-41991 核心：HouseArrest daemon 在处理文件同步请求时，
/// 拼路径没过滤 `..`，导致容器逃逸。
///
/// 正常 HouseArrest 路径：
///   /var/containers/Bundle/Application/<UUID>/<App>/<user_filename>
///
/// 漏洞路径（user_filename = "../../../Shared/SystemGroup/.../MobileGestalt.plist"）：
///   /var/containers/Bundle/Application/<UUID>/<App>/../../../Shared/SystemGroup/.../MobileGestalt.plist
///   → 解析后落到 /var/containers/Shared/...
///
/// 这就是 FilzaSlop 链的第一步：拿到容器外的 R/W。
///
/// 下面的代码是**简化示意**，真正实现需要与 HouseArrest 的 XPC 服务建立连接。
struct HouseArrestPathTraversal {

    /// HouseArrest 的 XPC 服务名称
    static let houseArrestService = "com.apple.housearrestd"

    /// 构造恶意文件名触发路径遍历
    static func maliciousFilename(targetPath: String, fromAppBundlePath: String) -> String? {
        // 算从 App bundle 到根目录需要多少个 ../
        // 然后拼到 Shared/SystemGroup/... 的相对路径

        // 简化版：假设 App bundle 在：
        // /var/containers/Bundle/Application/<UUID>/CastKit.app/
        // 从这里 ../../../Shared/... 能落到 /var/containers/Shared/

        guard targetPath.hasPrefix("/var/containers/") else { return nil }

        let components = targetPath.split(separator: "/")
        // 找到 Shared/SystemGroup 的起始点
        guard let idx = components.firstIndex(of: "Shared") else { return nil }

        // ../../../Shared/SystemGroup/...
        let relativePath = "../" + components[idx...].joined(separator: "/")
        return relativePath
    }

    /// 计算需要遍历的深度
    static func depthToShared() -> Int {
        // App bundle: /var/containers/Bundle/Application/<UUID>/CastKit.app/
        // 从这里到 /var/containers/ 需要 ../../../..
        return 4  // Bundle → Application → <UUID> → CastKit.app → /
    }
}

// MARK: - SparseRestore / BookRestore 电脑端 Companion 说明

/// 电脑端 companion 脚本使用说明（iOS 27 beta 3 上完整流程）
///
/// ## 电脑端应用流程（misaka26 / Nugget）
///
/// 1. 在 iOS 端 CastKit 里选好功能 → 点"导出"
/// 2. 把生成的 `MobileGestalt_patched.plist` AirDrop 到 Mac/PC
/// 3. 电脑端运行 companion 脚本：
///    ```bash
///    # macOS (需要 Homebrew 的 python3 + libimobiledevice)
///    brew install libimobiledevice
///    python3 companion/sparse_restore.py apply MobileGestalt_patched.plist
///
///    # Windows (需要 iTunes)
///    python companion/sparse_restore.py apply MobileGestalt_patched.plist
///    ```
/// 4. 电脑端脚本会：
///    - 用 `libimobiledevice` 跟手机通信
///    - 触发 SparseRestore (iOS 17.0-18.1) 或 BookRestore (iOS 18.2-26.1 / 27 beta 3)
///    - 把 patched plist 写入目标路径
///    - 提示 reboot
/// 5. 手机 reboot 后，所有 patch 生效
///
/// ## iOS 端直接应用（需要 exploit）
///
/// - iOS 27 beta 3 上，FilzaSlop (CVE-2023-41991) 还没被补
/// - 如果已经有 FilzaSlop / DarkSword 权限，CastKit 可以直接写
/// - 否则走电脑端 companion 路径
