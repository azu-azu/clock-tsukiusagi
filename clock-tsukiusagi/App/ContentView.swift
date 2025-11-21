import SwiftUI

public struct ContentView: View {
    @State private var selectedTab: Tab = .clock
    @State private var isMenuPresented = false

    public init() {}

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // 選択されたビューを全画面表示（背景）
            Group {
                switch selectedTab {
                case .clock:
                    ZStack(alignment: .bottom) {
                        ClockScreenView()

                        // 底辺に重ねる波アニメーション（背景は描かない）
                        WavyBottomView()
                            .allowsHitTesting(false)
                    }

                case .audioTest:
                    AudioTestView(selectedTab: $selectedTab)

                case .settings:
                    AudioSettingsView(selectedTab: $selectedTab)

                case .appSettings:
                    AppSettingsView(selectedTab: $selectedTab)
                }
            }

            // 上部のカスタムタブバー（Clock画面のみ表示）
            if selectedTab == .clock {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Clock アイコンは非表示（現在のページなので）

                        TabButton(
                            icon: "slider.horizontal.3",
                            label: "Settings",
                            isSelected: false
                        ) {
                            selectedTab = .settings
                        }

                        TabButton(
                            icon: "music.quarternote.3",
                            label: "Audio",
                            isSelected: false
                        ) {
                            selectedTab = .audioTest
                        }
                    }
                    .frame(height: 60)
                    .padding(.top, 10)

                    Spacer()
                }
            }

            // SideMenu関連（Clock画面のみ）
            if selectedTab == .clock {
                // トリガーボタン（左上）
                VStack {
                    HStack {
                        SideMenuTriggerButton {
                            withAnimation {
                                isMenuPresented = true
                            }
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.leading, 8)

                // オーバーレイ
                SideMenuOverlay(isPresented: $isMenuPresented)

                // メニュー本体
                ClockSideMenu(
                    isPresented: $isMenuPresented,
                    onBackToFront: {
                        selectedTab = .clock
                    },
                    onOpenAudio: {
                        selectedTab = .audioTest
                    },
                    onOpenAudioSettings: {
                        selectedTab = .settings
                    },
                    onOpenAppSettings: {
                        selectedTab = .appSettings
                    }
                )
            }
        }
        .gesture(sideMenuDragGesture())
        .statusBarHidden(true)
    }

    // MARK: - Swipe Gesture

    /// ✂️ 左端からのスワイプでSideMenuを開くジェスチャー
    /// ✂️ Timer app と同じロジック: 左端20px以内からのスワイプのみ検知
    private func sideMenuDragGesture() -> some Gesture {
        DragGesture()
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = abs(value.translation.height)
                // ✂️ 画面幅の10%を最小閾値として使用（最低50px）
                let openThreshold: CGFloat = 50
                let closeThreshold = -openThreshold

                // ✂️ 水平方向のスワイプのみ処理（垂直スクロールとの競合を避ける）
                if abs(horizontalAmount) > verticalAmount {
                    // ✂️ 右スワイプ & 左端20px以内からのスワイプのみメニューを開く
                    if horizontalAmount > openThreshold && !isMenuPresented {
                        if value.startLocation.x <= 20 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isMenuPresented = true
                            }
                        }
                    }
                    // ✂️ 左スワイプでメニューを閉じる
                    else if horizontalAmount < closeThreshold && isMenuPresented {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuPresented = false
                        }
                    }
                }
            }
    }
}

// MARK: - Tab Enum

public enum Tab {
    case clock
    case audioTest
    case settings
    case appSettings
}

// MARK: - TabButton

private struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .accentColor : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
