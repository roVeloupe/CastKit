//
//  CastKitApp.swift
//  CastKit
//
//  Entry point. Integrated from:
//    - GestaltEdit (frs0n/GestaltEdit) — MobileGestalt editing engine + presets
//    - 3105 (YangJiiii/3105) — .3105 encrypted patch package codec
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

                    NavigationStack { AdvancedGestaltEditorView() }
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