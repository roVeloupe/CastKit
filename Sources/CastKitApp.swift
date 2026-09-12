//
//  CastKitApp.swift
//  CastKit
//
//  Entry point. Primary source integrations are documented in README.md.
//

import SwiftUI

@main
struct CastKitApp: App {
    @StateObject private var viewModel = GestaltViewModel()

    init() {
        AutomationCommand.runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(viewModel)
        }
    }
}

/// Root tab container for CastKit.
struct RootTabView: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    var body: some View {
        Group {
            if GestaltAccess.isRunningSupportedOS() {
                TabView {
                    TweakWorkbenchView()
                        .tabItem { Label("Tools", systemImage: "switch.2") }

                    NavigationStack { AdvancedFieldEditorView() }
                        .tabItem { Label("Fields", systemImage: "list.bullet.rectangle") }

                    BackupLibraryView()
                        .tabItem { Label("Restore", systemImage: "archivebox") }

                    NavigationStack { PatchLibraryView() }
                        .tabItem { Label("Patches", systemImage: "shippingbox") }
                }
                .task { viewModel.load() }
            } else {
                UnsupportedOSView()
            }
        }
        .overlay {
            if viewModel.isRespringing {
                NeoSpringView()
            }
        }
        .alert(item: $viewModel.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}