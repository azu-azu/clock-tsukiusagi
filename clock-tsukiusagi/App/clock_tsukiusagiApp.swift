//
//  clock_tsukiusagiApp.swift
//  clock-tsukiusagi
//
//  Created by azu on 2025/10/18.
//

import SwiftUI

@main
struct clock_tsukiusagiApp: App {
    // オーディオサービス（Singleton）をアプリ全体で共有
    @StateObject private var audioService = AudioService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioService)
        }
    }
}
