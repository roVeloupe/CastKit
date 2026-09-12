//
//  CastKitApp.swift
//  CastKit / 3105 — 主入口
//

import SwiftUI

@main
struct CastKitApp: App {
    @StateObject private var patcher = GestaltPatcher.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                FeatureListView()
                    .tabItem {
                        Label("功能", systemImage: "sparkles")
                    }

                ApplyView()
                    .tabItem {
                        Label("应用", systemImage: "bolt.fill")
                    }

                WallpaperView()
                    .tabItem {
                        Label("壁纸", systemImage: "photo.on.rectangle.angled")
                    }

                LogView()
                    .tabItem {
                        Label("日志", systemImage: "terminal")
                    }
            }
            .tint(.purple)
            .environmentObject(patcher)
        }
    }
}
