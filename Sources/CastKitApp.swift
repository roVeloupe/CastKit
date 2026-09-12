//
//  CastKitApp.swift
//  CastKit — MobileGestalt dynamic patch tool
//

import SwiftUI

@main
struct CastKitApp: App {
    @StateObject private var patcher = GestaltPatcher.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                FeatureListView()
                    .tabItem { Label("功能", systemImage: "sparkles") }
                StatusView()
                    .tabItem { Label("状态", systemImage: "info.circle") }
                LogView()
                    .tabItem { Label("日志", systemImage: "terminal") }
            }
            .tint(.purple)
            .environmentObject(patcher)
        }
    }
}
