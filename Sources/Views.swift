//
//  FeatureListView.swift
//  CastKit
//

import SwiftUI

/// 主功能列表 — 按 Category 分组的开关列表
struct FeatureListView: View {
    @EnvironmentObject var patcher: GestaltPatcher

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 顶部 banner
                    headerBanner

                    // 所有分类
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

    // MARK: - Subviews

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔧 \(patcher.enabledPatchIDs.count) 个激活中")
                .font(.headline)
            Text("MobileGestalt dynamic patcher — 基于 CVE-2023-41991/41992")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button {
                    patcher.appendLog("🧪 导出配置")
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    patcher.enabledPatchIDs.removeAll()
                    patcher.appendLog("🧹 清空所有 patch")
                } label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func categorySection(_ cat: GestaltFeature.Category) -> some View {
        let features = FeatureDB.by(category: cat)
        guard !features.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(cat.rawValue)
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

    private func featureRow(_ f: GestaltFeature, isLast: Bool) -> some View {
        let enabled = patcher.isEnabled(f)

        return VStack(spacing: 0) {
            Toggle(isOn: Binding(
                get: { enabled },
                set: { _ in patcher.toggle(f) }
            )) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.15))
                        Image(systemName: f.icon)
                            .foregroundStyle(.purple)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.name).font(.body)
                        Text(f.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if let ios = f.miniOS {
                        Text("iOS \(ios)+")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                    }
                }
                .padding(.vertical, 4)
            }
            .toggleStyle(.switch)

            if !isLast {
                Divider().padding(.leading, 58)
            }
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Status View

struct StatusView: View {
    @EnvironmentObject var patcher: GestaltPatcher

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 系统信息
                    infoCard(
                        icon: "iphone",
                        title: "设备信息",
                        items: [
                            ("系统版本", patcher.systemVersion),
                            ("激活 Patch", "\(patcher.enabledPatchIDs.count) 个"),
                            ("目标", "MobileGestalt.plist")
                        ]
                    )

                    // patch 预览
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📋 将写入的 Key-Value").font(.headline)
                        let patch = patcher.generateMergedPatch()
                        if patch.isEmpty {
                            Text("（当前无激活的 patch）")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                                .padding(.vertical)
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

                    // 安全提示
                    VStack(alignment: .leading, spacing: 8) {
                        Label("安全提示", systemImage: "exclamationmark.triangle").font(.headline)
                        Text("""
                        • 修改 MobileGestalt 理论上可能导致 bootloop
                        • 请先完整备份设备
                        • iOS 26.2+ MobileGestalt 通道已被 Apple 关闭
                        • 需要 BookRestore / SparseRestore / FilzaSlop 任一 exploit
                        • 本项目不提供越狱/注入能力
                        """)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .navigationTitle("状态")
            .background(Color(.systemGroupedBackground))
        }
    }

    private func infoCard(icon: String, title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            ForEach(items, id: \.0) { k, v in
                HStack {
                    Text(k).foregroundStyle(.secondary)
                    Spacer()
                    Text(v).monospaced()
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
                Button("清空") { patcher.logs.removeAll() }
                    .disabled(patcher.logs.isEmpty)
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
