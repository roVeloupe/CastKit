//
//  Views.swift
//  CastKit — 3-tab UI
//

import SwiftUI

// MARK: - Feature List

struct FeatureListView: View {
    @EnvironmentObject var patcher: GestaltPatcher
    @StateObject private var io = GestaltIO.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerBanner
                    applyPanel
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
            Text("\(patcher.enabledPatchIDs.count) active")
                .font(.headline)
            Text("MobileGestalt dynamic patcher — iOS 27 beta 1-4")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Apply Panel

    private var applyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚡ Apply Patch").font(.headline)

            pathRow(
                icon: "bolt",
                title: "A. Direct write (no-sandbox)",
                desc: "Requires no-sandbox entitlement or root",
                statusText: "❌ Sandblock blocked",
                enabled: false
            )

            pathRow(
                icon: "lock.shield",
                title: "B. CVE-2023-41991 HouseArrest",
                desc: "FilzaSlop sandbox escape + XPC traversal",
                statusText: "⚠️ Requires exploit chain",
                enabled: false
            )

            pathRow(
                icon: "desktopcomputer",
                title: "C. Export → BookRestore (RECOMMENDED)",
                desc: "iOS 18.2 - 26.1 / 27 beta 1-4",
                statusText: "✅ Available",
                enabled: true
            )

            Divider().padding(.vertical, 4)

            HStack(spacing: 10) {
                Button {
                    exportPatchedPlist()
                } label: {
                    Label("Export Patch", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(patcher.enabledPatchIDs.isEmpty)

                Button {
                    patcher.enabledPatchIDs.removeAll()
                    patcher.appendLog("🧹 All patches cleared")
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            DisclosureGroup("📱 How to apply from Mac/PC") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Tap Export Patch on iPhone")
                    Text("2. AirDrop to Mac/PC")
                    Text("3. Run:").bold()
                    Text("   python3 companion.py apply MobileGestalt_patched.plist").font(.system(.footnote, design: .monospaced))
                    Text("   or: brew install --cask misaka26 && misaka26 apply ...").font(.system(.footnote, design: .monospaced))
                    Text("4. Device auto-reboots ✅")
                }
                .padding(.top, 4)
                .font(.caption2)
            }
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
            Text(statusText).font(.caption2).foregroundStyle(enabled ? .green : .secondary)
        }
    }

    // MARK: - Export

    private func exportPatchedPlist() {
        let patch = patcher.generateMergedPatch()

        // Try to merge with original; if we can't read it, just use patch as-is
        var finalDict: [String: Any] = [:]
        if let original = try? io.readGestalt() {
            finalDict = io.mergePatch(patch, into: original)
            patcher.appendLog("📖 Merged with live MobileGestalt")
        } else {
            finalDict = patch
            patcher.appendLog("⚠️ Can't read original MobileGestalt — exporting patch only")
        }

        do {
            let url = try io.generatePatchedPlist(finalDict)
            patcher.appendLog("📤 Exported: \(url.lastPathComponent) (\(patch.count) keys)")

            // Share sheet
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                let pop = vc.popoverPresentationController
                pop?.sourceView = root.view
                pop?.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
                root.present(vc, animated: true)
            }
        } catch {
            patcher.appendLog("❌ Export failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Category section

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

// MARK: - Status View

struct StatusView: View {
    @EnvironmentObject var patcher: GestaltPatcher
    @StateObject private var io = GestaltIO.shared
    @State private var probeResults: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    infoCard(icon: "iphone", title: "Device", items: [
                        ("iOS", patcher.systemVersion),
                        ("Active patches", "\(patcher.enabledPatchIDs.count)"),
                        ("Target path", "…com.apple.MobileGestalt.plist")
                    ])

                    fileProbeCard

                    VStack(alignment: .leading, spacing: 10) {
                        Text("📋 Patched keys").font(.headline)
                        let patch = patcher.generateMergedPatch()
                        if patch.isEmpty {
                            Text("(none)").foregroundStyle(.secondary).font(.footnote).padding(.vertical)
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

                    backupsCard

                    VStack(alignment: .leading, spacing: 8) {
                        Label("⚠️ Warning", systemImage: "exclamationmark.triangle").font(.headline)
                        Text("""
                        • MobileGestalt edits CAN cause bootloop — BACK UP FIRST
                        • iOS 26.2+ / iOS 27 beta 5+: Apple closed BookRestore path
                        • iOS 27 beta 5+: CVE-2023-41991 (FilzaSlop) may also be patched
                        • CastKit is a patch generator + companion, NOT a jailbreak
                        • Use at your own risk
                        """)
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .navigationTitle("Status")
            .background(Color(.systemGroupedBackground))
            .onAppear { probeResults = io.probeReadable() }
        }
    }

    private var fileProbeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🔍 Filesystem probe").font(.headline)
                Spacer()
                Button("Refresh") { probeResults = io.probeReadable() }
            }
            ForEach(Array(probeResults.keys.sorted()), id: \.self) { k in
                HStack {
                    Text(k).font(.caption)
                    Spacer()
                    Text(probeResults[k] == true ? "✅" : "❌")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var backupsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💾 Local backups").font(.headline)
            let backups = io.listBackups()
            if backups.isEmpty {
                Text("(none yet)").font(.footnote).foregroundStyle(.secondary)
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
            Group {
                if patcher.logs.isEmpty {
                    Spacer()
                    Text("No logs yet").foregroundStyle(.secondary)
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
            .navigationTitle("Log")
            .toolbar {
                Button("Clear") { patcher.logs.removeAll() }.disabled(patcher.logs.isEmpty)
            }
        }
    }
}
