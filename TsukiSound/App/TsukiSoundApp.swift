//
//  TsukiSoundApp.swift
//  TsukiSound
//
//  Created by azu on 2025/10/18.
//

import SwiftUI

@main
struct TsukiSoundApp: App {
    // オーディオサービス（Singleton）をアプリ全体で共有
    @StateObject private var audioService = AudioService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioService)
                .environmentObject(audioService.playlistState)
        }
    }
}
