//
//  PatchLibraryView.swift
//  CastKit
//
//  .3105 encrypted patch package support, integrated from
//  YangJiiii/3105. Encodes/decodes PatchProject payloads using the
//  same binary envelope format (magic "3105PATCH\0") so packages
//  created here round-trip with 3105 on other devices.
//

import SwiftUI
import UniformTypeIdentifiers

/// Library of .3105 patch projects on this device.
struct PatchLibraryView: View {
    @State private var projects: [PatchProject] = []
    @State private var showingCreateSheet = false
    @State private var showingImporter = false
    @State private var selectedProject: PatchProject?
    @State private var notice: PatchNotice?

    var body: some View {
        List {
            Section {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("New Patch Project", systemImage: "plus.circle.fill")
                }
                Button {
                    showingImporter = true
                } label: {
                    Label("Import .3105 Package", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("Packages use the encrypted 3105 envelope format (AES-GCM + PBKDF2). Imported projects can be inspected and re-exported.")
            }

            Section("Local Projects") {
                if projects.isEmpty {
                    Label("No patch projects", systemImage: "shippingbox")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(projects) { project in
                        PatchProjectRow(project: project) {
                            selectedProject = project
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            let project = projects[index]
                            try? PatchProjectStore.delete(project)
                        }
                        reload()
                    }
                }
            }
        }
        .navigationTitle("Patches")
        .onAppear(perform: reload)
        .sheet(isPresented: $showingCreateSheet) {
            NewPatchProjectSheet { project in
                try PatchProjectStore.save(project)
                reload()
            }
        }
        .sheet(item: $selectedProject) { project in
            NavigationStack {
                PatchProjectDetailView(project: project)
            }
            .presentationDetents([.medium, .large])
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let data = try Data(contentsOf: url)
                    let summary = try PatchPackageCodec.inspect(data)
                    let decoded = try PatchPackageCodec.decode(data, password: nil)
                    try PatchProjectStore.save(decoded.project)
                    notice = PatchNotice(kind: .info, message: "Imported \(summary.schemaVersion) package")
                    reload()
                } catch {
                    notice = PatchNotice(kind: .error, message: error.localizedDescription)
                }
            case .failure(let error):
                notice = PatchNotice(kind: .error, message: error.localizedDescription)
            }
        }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.kind == .error ? "Import Failed" : "Patches"),
                  message: Text(notice.message),
                  dismissButton: .default(Text("OK")))
        }
    }

    private func reload() {
        projects = (try? PatchProjectStore.loadProjects()) ?? []
    }
}

private struct PatchProjectRow: View {
    let project: PatchProject
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .foregroundStyle(.primary)
                    Text("\(project.rules.count) replacements · \(project.directories.count) dirs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if project.isPrivate {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PatchProjectDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let project: PatchProject
    @State private var exported: URL?

    var body: some View {
        List {
            Section("Project") {
                LabeledContent("ID", value: project.id.uuidString)
                LabeledContent("Name", value: project.name)
                LabeledContent("Author", value: project.author.isEmpty ? "-" : project.author)
                LabeledContent("Private", value: project.isPrivate ? "Yes" : "No")
            }

            Section("Replacement Targets") {
                ForEach(project.rules, id: \.id) { rule in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.bundleID).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        Text("\(rule.relativePath) → \(rule.replacementFilename)")
                            .font(.subheadline)
                    }
                }
                if project.rules.isEmpty {
                    Text("No replacements").foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    export()
                } label: {
                    Label("Export .3105 Package", systemImage: "square.and.arrow.up")
                }
                .disabled(project.rules.isEmpty)
            } footer: {
                Text("Exports in the unencrypted (public key) envelope variant — import it in 3105 or share with others.")
            }
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $exported) { url in
            ShareSheet(items: [url])
        }
    }

    private func export() {
        do {
            let encoded = try PatchPackageCodec.encodeNew(project: project, password: nil)
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(project.name).3105")
            try encoded.data.write(to: tmp, options: .atomic)
            exported = tmp
        } catch {
            // surface via alert in parent; keep simple for now
        }
    }
}

private struct NewPatchProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (PatchProject) throws -> Void

    @State private var name = ""
    @State private var author = ""
    @State private var bundleID = "com.example.app"
    @State private var relativePath = "Documents/save.dat"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                    TextField("Author", text: $author)
                }
                Section("Target") {
                    TextField("Bundle ID", text: $bundleID)
                    TextField("File path in container", text: $relativePath)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Patch Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create", action: create)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        do {
            let rule = PatchRule(
                bundleID: bundleID,
                relativePath: relativePath,
                replacementFilename: "placeholder.dat",
                replacementData: Data()
            )
            let project = PatchProject(
                name: name,
                author: author,
                isPrivate: false,
                bundleIdentifiers: [bundleID],
                directories: [],
                rules: [rule]
            )
            try onSave(project)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct PatchNotice: Identifiable {
    enum Kind { case info, error }
    let id = UUID()
    let kind: Kind
    let message: String
}

/// Minimal on-device store for patch projects (Documents/Patches).
enum PatchProjectStore {
    private static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Patches", isDirectory: true)
    }

    static func save(_ project: PatchProject) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(project)
        try data.write(to: directory.appendingPathComponent("\(project.id.uuidString).p3105"))
    }

    static func loadProjects() throws -> [PatchProject] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let decoder = PropertyListDecoder()
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "p3105" }
        .compactMap { url -> PatchProject? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(PatchProject.self, from: data)
        }
    }

    static func delete(_ project: PatchProject) throws {
        try FileManager.default.removeItem(
            at: directory.appendingPathComponent("\(project.id.uuidString).p3105")
        )
    }
}