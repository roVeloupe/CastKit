//
//  Views.swift
//  CastKit — 完整 patch 应用 UI
//
//  三种写入路径：
//  A. 直接写真实路径（需要 no-sandbox / root）
//  B. CVE-2023-41991 HouseArrest 路径遍历
//  C. 导出 plist → 电脑端 SparseRestore / BookRestore
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Feature List (主功能开关)

struct FeatureListView: View {
    @EnvironmentObject var patcher: GestaltPatcher
    @StateObject private var io = GestaltIO.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerBanner
                    applyPanel   // ← 新增：应用 patch 面板
                    ForEach(GestaltFeature.Category.allCases, id: \.self) { cat in
                        categorySection(cat)
                    }
                }
                .padding()
            }
            .navigationTitle("CastKit")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Banner

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔧 \(patcher.enabledPatchIDs.count) 个激活中")
                .font(.headline)
            Text("MobileGestalt dynamic patcher — iOS 27 beta 1-4")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 🆕 Apply Panel（核心缺失）

    /// 完整 patch 应用面板 — 三种写入路径
    private var applyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚡ 应用 Patch").font(.headline)

            // 路径 A：直接写
            pathRow(
                icon: "bolt",
                title: "A. 直接写真实路径",
                desc: "需要 no-sandbox entitlement 或 root",
                statusText: io.probeReadable()["真实路径 (root)"] == true ? "✅ 可读（仍需可写）" : "❌ 沙箱阻止",
                enabled: false
            )

            // 路径 B：HouseArrest
            pathRow(
                icon: "lock.shield",
                title: "B. CVE-2023-41991 HouseArrest",
                desc: "FilzaSlop 链第一步：XPC 路径遍历出容器",
                statusText: "⚠️ 需完整 XPC 实现（见 companion/）",
                enabled: false
            )

            // 路径 C：电脑端（推荐）
            pathRow(
                icon: "desktopcomputer",
                title: "C. 导出 → 电脑端 BookRestore",
                desc: "iOS 27 beta 1-4 / 26.0-26.1 / 18.2+ 均可",
                statusText: "✅ 可用（推荐）",
                enabled: true
            )

            Divider().padding(.vertical, 4)

            // 操作按钮
            HStack(spacing: 10) {
                Button {
                    Task { await exportPatchedPlist() }
                } label: {
                    Label("导出 Patch", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(patcher.enabledPatchIDs.isEmpty)

                Button {
                    patcher.enabledPatchIDs.removeAll()
                    patcher.appendLog("🧹 清空所有 patch")
                } label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            // 电脑端说明
            DisclosureGroup("📱 电脑端应用步骤") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. 点「导出 Patch」保存 .plist").font(.footnote)
                    Text("2. AirDrop 到 Mac/PC").font(.footnote)
                    Text("3. 电脑端运行:").font(.footnote).bold()
                    Text("   python3 companion/companion.py apply MobileGestalt_patched.plist").font(.system(.footnote, design: .monospaced))
                    Text("4. 或直接用 misaka26:").font(.footnote).bold()
                    Text("   misaka26 apply MobileGestalt_patched.plist").font(.system(.footnote, design: .monospaced))
                    Text("5. 设备会自动 reboot").font(.footnote)
                }
                .padding(.top, 4)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func pathRow(icon: String, title: String, desc: String, statusText: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(enabled ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text(desc).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(enabled ? .green : .secondary)
        }
    }

    // MARK: - 导出 Patch

    private func exportPatchedPlist() async {
        let patch = patcher.generateMergedPatch()
        do {
            // 尝试从系统读原始，失败就用空字典
            var original: [String: Any] = [:]
            if let existing = try? await io.readGestalt() {
                original = existing
            }

            let url = try await io.generatePatchedPlist(patch, from: original)
            patcher.appendLog("📤 导出成功: \(url.lastPathComponent)")
            patcher.appendLog("   包含 \(patch.count) 个 patch key")

            // 在主线程弹出分享 sheet
            await MainActor.run {
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                activityVC.popoverPresentationController?.sourceView = UIView()
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let root = window.rootViewController {
                    root.present(activityVC, animated: true)
                }
            }
        } catch {
            patcher.appendLog("❌ 导出失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Category 分组（保留原有）

    private func categorySection(_ cat: GestaltFeature.Category) -> some View {
        let features = FeatureDB.by(category: cat)
        guard !features.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(cat.rawValue).font(.subheadline).foregroundStyle(.secondary).textCase(.uppercase)
                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { i, f in
                        featureRow(f, isLast: i == features.count - 1)
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        )
    }

    private func featureRow(_ f: GestaltFeature, isLast: Bool) -> some View {
        let enabled = patcher.isEnabled(f)
        return VStack(spacing: 0) {
            Toggle(isOn: Binding(get: { enabled }, set: { _ in patcher.toggle(f) })) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.15))
                        Image(systemName: f.icon).foregroundStyle(.purple)
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.name).font(.body)
                        Text(f.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if let ios = f.miniOS {
                        Text("iOS \(ios)+").font(.caption2).foregroundStyle(.tertiary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                    }
                }
                .padding(.vertical, 4)
            }
            .toggleStyle(.switch)
            if !isLast { Divider().padding(.leading, 58) }
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Status View（更新）

struct StatusView: View {
    @EnvironmentObject var patcher: GestaltPatcher
    @StateObject private var io = GestaltIO.shared
    @State private var probeResults: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    infoCard(icon: "iphone", title: "设备信息", items: [
                        ("系统版本", patcher.systemVersion),
                        ("激活 Patch", "\(patcher.enabledPatchIDs.count) 个"),
                        ("目标路径", io.gestaltRealPath)
                    ])

                    // 新增：文件系统探测
                    fileProbeCard

                    // patch 预览
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📋 将写入的 Key-Value").font(.headline)
                        let patch = patcher.generateMergedPatch()
                        if patch.isEmpty {
                            Text("（当前无激活的 patch）").foregroundStyle(.secondary).font(.footnote).padding(.vertical)
                        } else {
                            ForEach(Array(patch.keys.sorted()), id: \.self) { k in
                                HStack(alignment: .top) {
                                    Text(k).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    Spacer()
                                    Text("\(patch[k]!)").font(.caption.monospaced())
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    // 备份列表
                    backupsCard

                    // 安全提示
                    VStack(alignment: .leading, spacing: 8) {
                        Label("安全提示", systemImage: "exclamationmark.triangle").font(.headline)
                        Text("""
                        • 修改 MobileGestalt 可能导致 bootloop — 务必先备份
                        • iOS 26.2+ / iOS 27 beta 5+：苹果封堵了 BookRestore 通道
                        • FilzaSlop 链 (CVE-2023-41991/41992) 在 iOS 27 beta 1-4 未被补
                        • 本项目只提供 patch 生成器 + 电脑端 companion
                        • 越狱/注入能力需要 FilzaSlop / DarkSword / palera1n
                        """)
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .navigationTitle("状态")
            .background(Color(.systemGroupedBackground))
            .onAppear { Task { probeResults = await io.probeReadable() } }
        }
    }

    private var fileProbeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🔍 文件系统探测").font(.headline)
                Spacer()
                Button("刷新") {
                    Task { probeResults = await io.probeReadable() }
                }
            }
            ForEach(Array(probeResults.keys.sorted()), id: \.self) { k in
                HStack {
                    Text(k).font(.caption)
                    Spacer()
                    Text(probeResults[k] == true ? "✅" : "❌")
                }
            }
            if probeResults.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var backupsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💾 本地备份").font(.headline)
            let backups = io.listBackups()
            if backups.isEmpty {
                Text("（暂无备份）").font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(backups, id: \.self) { b in Text(b).font(.caption.monospaced()) }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func infoCard(icon: String, title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            ForEach(items, id: \.0) { k, v in
                HStack {
                    Text(k).foregroundStyle(.secondary)
                    Spacer()
                    Text(v).monospaced().font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Log View

struct LogView: View {
    @EnvironmentObject var patcher: GestaltPatcher

    var body: some View {
        NavigationStack {
            VStack {
                if patcher.logs.isEmpty {
                    Spacer()
                    Text("暂无日志").foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(patcher.logs.enumerated()), id: \.offset) { i, msg in
                                    Text(msg)
                                        .font(.system(.footnote, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: patcher.logs.count) { newCount in
                            if newCount > 0 {
                                withAnimation { proxy.scrollTo(newCount - 1, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("日志")
            .toolbar {
                Button("清空") { patcher.logs.removeAll() }.disabled(patcher.logs.isEmpty)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TabView {
        FeatureListView().tabItem { Label("功能", systemImage: "sparkles") }
        StatusView().tabItem { Label("状态", systemImage: "info.circle") }
        LogView().tabItem { Label("日志", systemImage: "terminal") }
    }
    .tint(.purple)
    .environmentObject(GestaltPatcher.shared)
}
