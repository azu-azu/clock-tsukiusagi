import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        TabView {
            // メインの時計画面
            ZStack(alignment: .bottom) {
                ClockScreenView()

                // 底辺に重ねる波アニメーション（背景は描かない）
                WavyBottomView()
                    .allowsHitTesting(false)
            }
            .statusBarHidden(true)
            .tabItem {
                Label("Clock", systemImage: "clock.fill")
            }

            // オーディオテスト画面
            AudioTestView()
                .tabItem {
                    Label("Audio Test", systemImage: "waveform")
                }
        }
    }
}

#Preview {
    ContentView()
}
