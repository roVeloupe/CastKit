//
//  Views.swift
//  CastKit — 全中文 UI
//
//  四个 Tab：
//    功能     → 勾选 MobileGestalt 开关（20+ 功能）
//    应用     → 一键写入系统（HouseArrest 直接写 / 导出给电脑端）
//    壁纸     → PosterBoard 动态壁纸定制
//    日志     → 实时运行日志
//

import SwiftUI

// MARK: - Tab 1: 功能开关

struct FeatureListView: View {
    @EnvironmentObject var patcher: GestaltPatcher

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    bannerCard
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

    private var bannerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🟣 CastKit 3105").font(.title2).bold()
                Spacer()
            }
            Text("iOS 27 beta 1-4 MobileGestalt 动态补丁")
                .font(.footnote).foregroundStyle(.secondary)
            Text("当前激活：\(patcher.enabledPatchIDs.count) 项")
                .font(.caption).foregroundStyle(.purple)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func categorySection(_ cat: GestaltFeature.Category) -> some View {
        let features = FeatureDB.by(category: cat)
        guard !features.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(categoryLabel(cat))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { i, f in
                        featureRow(f, isLast: i == features.count - 1)
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        )
    }

    private func categoryLabel(_ cat: GestaltFeature.Category) -> String {
        switch cat {
        case .display:   return "显示与 UI"
        case .hardware:  return "硬件解锁"
        case .audio:     return "声音"
        case .tablet:    return "iPad / 多任务"
        case .security:  return "安全与开发"
        case .model:     return "设备伪装"
        }
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
                        Text("iOS \(ios)+")
                            .font(.caption2).foregroundStyle(.tertiary)
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

// MARK: - Tab 2: 应用到系统（核心！）

struct ApplyView: View {
    @EnvironmentObject var patcher: GestaltPatcher
    @StateObject private var ha = HouseArrestExploit.shared
    @StateObject private var io = GestaltIO.shared

    @State private var haStatus: String = "检测中…"
    @State private var haOK: Bool = false
    @State private var applying: Bool = false
    @State private var showSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    preflightCard

                    Divider()

                    applySection

                    Divider()

                    pathSection

                    Divider()

                    patchPreviewCard
                }
                .padding()
            }
            .navigationTitle("应用到系统")
            .background(Color(.systemGroupedBackground))
            .onAppear { runPreflight() }
        }
    }

    // MARK: - 预检

    private var preflightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🔍 环境预检").font(.headline)

            row("Bundle ID", value: Bundle.main.bundleIdentifier ?? "?")
            row("iOS 版本", value: ProcessInfo.processInfo.operatingSystemVersionString)
            row("HouseArrest (CVE-2023-41991)", value: haOK ? "✅ 可用" : "❌ 不可用")
            row("导出补丁", value: haOK ? "✅ 可分享" : "✅ 可分享")
            row("电脑端 BookRestore", value: "❌ iOS 27 已被 Apple 封堵")
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ k: String, value: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary).font(.footnote)
            Spacer()
            Text(value).font(.footnote.monospaced())
        }
    }

    // MARK: - 核心应用区

    private var applySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("⚡ 一键应用").font(.headline)

            // 按钮 1: HouseArrest 直接写（iOS 27 beta 1-4 原生）
            Button(action: {
                Task { await applyDirect() }
            }) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(haOK ? .white : .secondary)
                    VStack(alignment: .leading) {
                        Text("写入系统 MobileGestalt")
                            .font(.body.bold())
                        Text("CVE-2023-41991 HouseArrest 路径遍历")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if applying {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.white.opacity(haOK ? 1 : 0.3))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(haOK ? Color.purple : Color(.tertiaryLabel),
                            in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(haOK ? .white : .secondary)
            }
            .disabled(!haOK || applying || patcher.enabledPatchIDs.isEmpty)

            // 按钮 2: 导出补丁（兜底）
            Button(action: { exportPatch() }) {
                HStack {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(.purple)
                    VStack(alignment: .leading) {
                        Text("导出补丁文件 (.3105)").font(.body.bold())
                        Text("AirDrop 给电脑或其他设备").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill").foregroundStyle(.purple)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(patcher.enabledPatchIDs.isEmpty)

            // 按钮 3: 清除所有
            Button(action: {
                patcher.enabledPatchIDs.removeAll()
                patcher.appendLog("🧹 所有 patch 已清空（不影响系统）")
            }) {
                Label("清空所有开关", systemImage: "trash").foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity)

            // ⚠️ 提示
            VStack(alignment: .leading, spacing: 4) {
                Label("⚠️ 警告", systemImage: "exclamationmark.triangle.fill").font(.footnote)
                Text("""
                • CVE-2023-41991 在 iOS 27 beta 5+ 可能已被 Apple 修补
                • 写入 MobileGestalt 可能导致 bootloop — 请先备份
                • iOS 27 上 BookRestore / SparseRestore 全被封堵
                • 本工具需要 enterprise 签名 + 特定 bundle ID 才能完整工作
                """).font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - 三种路径说明

    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📊 写入路径对比").font(.headline)

            pathRow(
                icon: "lock.shield",
                title: "A. CVE-2023-41991 HouseArrest",
                subtitle: "FilzaSlop 路径遍历 → 出容器写",
                status: haOK ? "✅ 当前可用" : "❌ 不满足条件",
                ok: haOK
            )
            pathRow(
                icon: "desktopcomputer",
                title: "B. BookRestore / SparseRestore",
                subtitle: "电脑端 Apple Books 下载失败触发恢复",
                status: "❌ iOS 27 已补封堵",
                ok: false
            )
            pathRow(
                icon: "sparkle",
                title: "C. 越狱 / palera1n",
                subtitle: "完整 root + amfid bypass",
                status: "❌ A14 iPhone 12 上尚无稳定 palera1n",
                ok: false
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func pathRow(icon: String, title: String, subtitle: String, status: String, ok: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(ok ? .green : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                Text(status).font(.caption2).foregroundStyle(ok ? .green : .secondary)
            }
        }
    }

    // MARK: - Patch 预览

    private var patchPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📋 将写入的 Key-Value（\(patcher.enabledPatchIDs.count) 项）").font(.headline)
            let patch = patcher.generateMergedPatch()
            if patch.isEmpty {
                Text("（当前没有激活的 patch）").foregroundStyle(.secondary).font(.footnote)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(patch.keys.sorted()), id: \.self) { k in
                            HStack(alignment: .top) {
                                Text(k).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                Spacer()
                                Text("\(patch[k]!)").font(.caption.monospaced())
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    private func runPreflight() {
        HouseArrestExploit.shared.runPreflight()
        if HouseArrestExploit.shared.isAvailable {
            haOK = true
            patcher.appendLog("✅ 预检通过 — HouseArrest 路径遍历可用")
        } else {
            haOK = false
            patcher.appendLog("❌ 预检失败: \(HouseArrestExploit.shared.statusMessage)")
        }
    }

    private func applyDirect() async {
        applying = true
        defer { applying = false }

        let patch = patcher.generateMergedPatch()
        guard !patch.isEmpty else {
            patcher.appendLog("⚠️ 没有激活的 patch，无法应用")
            return
        }

        // 1. 读取当前 MobileGestalt（能读就 merge，不能就用 patch 裸写）
        var current: [String: Any] = [:]
        if let existing = try? io.readGestalt() {
            current = io.mergePatch(patch, into: existing)
            patcher.appendLog("📖 已合并现有 MobileGestalt")
        } else {
            current = patch
            patcher.appendLog("⚠️ 无法读取现有 MobileGestalt — 只写变更项")
        }

        // 2. HouseArrest 写入
        do {
            try HouseArrestExploit.shared.writeMobileGestalt(current)
            patcher.appendLog("✅ CVE-2023-41991 写入成功！")
            patcher.appendLog("📱 请重启设备使更改生效")
            // 弹出重启提示
            await MainActor.run {
                showRebootAlert()
            }
        } catch {
            patcher.appendLog("❌ 写入失败: \(error.localizedDescription)")
            patcher.appendLog("💡 试试在电脑端用 misaka26 或导出补丁")
        }
    }

    private func showRebootAlert() {
        // SwiftUI alert
    }

    private func exportPatch() {
        let patch = patcher.generateMergedPatch()
        guard !patch.isEmpty else { return }

        let pkg = PatchPackage(
            name: "CastKit Custom Patch",
            description: "导出的 MobileGestalt 补丁",
            version: "1.0",
            iosMin: "26.0",
            iosMax: "27.0",
            patches: patch
        )

        do {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("CastKitPatch.3105-patch")
            try pkg.write(to: tmp)
            patcher.appendLog("📤 导出成功: \(tmp.lastPathComponent)")

            // Share sheet
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                let vc = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
                let pop = vc.popoverPresentationController
                pop?.sourceView = root.view
                pop?.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
                root.present(vc, animated: true)
            }
        } catch {
            patcher.appendLog("❌ 导出失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Tab 3: 壁纸

struct WallpaperView: View {
    @State private var packages: [PosterPackage] = []
    @State private var selected: PosterPackage?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(packages) { pkg in
                        posterCard(pkg)
                    }
                }
                .padding()
            }
            .navigationTitle("壁纸")
            .background(Color(.systemGroupedBackground))
            .onAppear { packages = PosterBoardEngine.shared.listPackages() }
        }
    }

    private func posterCard(_ pkg: PosterPackage) -> some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: pkg.previewColorHex) ?? .purple)
                .frame(height: 180)
                .overlay(
                    VStack {
                        Image(systemName: "sparkles")
                            .font(.title2).foregroundStyle(.white.opacity(0.6))
                        Text(pkg.name).font(.body).bold().foregroundStyle(.white)
                    }
                )
            Text(pkg.bundleID)
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .contextMenu {
            Button("导出 .3105 包") { /* export */ }
            Button("应用到锁屏", role: .none) { /* apply */ }
        }
    }
}

// MARK: - Tab 4: 日志

struct LogView: View {
    @EnvironmentObject var patcher: GestaltPatcher

    var body: some View {
        NavigationStack {
            Group {
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
                        .onChange(of: patcher.logs.count, perform: { newCount in
                            if newCount > 0 {
                                withAnimation { proxy.scrollTo(newCount - 1, anchor: .bottom) }
                            }
                        })
                    }
                }
            }
            .navigationTitle("运行日志")
            .toolbar {
                Button("清空") { patcher.logs.removeAll() }.disabled(patcher.logs.isEmpty)
            }
        }
    }
}

// MARK: - Color Hex Helper

extension Color {
    init?(hex: String) {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt64(h, radix: 16) else { return nil }
        let r = Double((v & 0xff0000) >> 16) / 255.0
        let g = Double((v & 0x00ff00) >> 8) / 255.0
        let b = Double(v & 0x0000ff) / 255.0
        self = .init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Preview

#Preview {
    TabView {
        FeatureListView().tabItem { Label("功能", systemImage: "sparkles") }
        ApplyView().tabItem { Label("应用", systemImage: "bolt.fill") }
        WallpaperView().tabItem { Label("壁纸", systemImage: "photo.on.rectangle.angled") }
        LogView().tabItem { Label("日志", systemImage: "terminal") }
    }
    .tint(.purple)
    .environmentObject(GestaltPatcher.shared)
}
