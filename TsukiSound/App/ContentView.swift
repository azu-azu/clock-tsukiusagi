import SwiftUI

public struct ContentView: View {
    @State private var selectedTab: Tab = .clock
    @State private var isMenuPresented = false
    @State private var clockDisplayMode: ClockDisplayMode = .dotMatrix
    @StateObject private var fontStyleProvider = FontStyleProvider()

    public init() {}

    private var isAnalogClockMode: Bool {
        clockDisplayMode == .bunny || clockDisplayMode == .number
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // 選択されたビューを全画面表示（背景）
            Group {
                switch selectedTab {
                case .clock:
                    ZStack(alignment: .bottom) {
                        ClockScreenView(displayMode: $clockDisplayMode)

                        // 底辺に重ねる波アニメーション（背景は描かない）
                        WavyBottomView()
                            .allowsHitTesting(false)
                    }

                case .audioPlayback:
                    AudioPlaybackView(selectedTab: $selectedTab)

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
                        // 左側：ギアボタン（SideMenu トリガー）
                        TabButton(
                            icon: "gearshape.fill",
                            label: "Menu",
                            isSelected: false,
                            useAnalogColor: isAnalogClockMode
                        ) {
                            withAnimation {
                                isMenuPresented = true
                            }
                        }

                        Spacer()  // 左右を画面端に配置

                        // 右側：Audio
                        TabButton(
                            icon: "music.quarternote.3",
                            label: "Audio",
                            isSelected: false,
                            useAnalogColor: isAnalogClockMode
                        ) {
                            selectedTab = .audioPlayback
                        }
                    }

                    // フロントのタブバーの位置決め
                    .frame(height: 60)
                    .padding(.horizontal, 62)  // 画面端より内側に配置
                    .padding(.top, 10)

                    Spacer()
                }
            }

            // SideMenu関連（Clock画面のみ）
            if selectedTab == .clock {

                // オーバーレイ
                SideMenuOverlay(isPresented: $isMenuPresented)

                // メニュー本体
                ClockSideMenu(
                    isPresented: $isMenuPresented,
                    onBackToFront: {
                        selectedTab = .clock
                    },
                    onOpenAudio: {
                        selectedTab = .audioPlayback
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
        .withFontStyleProvider(fontStyleProvider)
        .gesture(sideMenuDragGesture())
        .statusBarHidden(true)
    }

    // MARK: - Swipe Gesture

    /// スワイプジェスチャー（Clock画面専用）
    /// - 左端からの右スワイプ: SideMenuを開く
    /// - 左スワイプ: Audio画面へ遷移
    private func sideMenuDragGesture() -> some Gesture {
        DragGesture()
            .onEnded { value in
                // Clock画面以外ではジェスチャーを無視
                guard selectedTab == .clock else { return }

                let horizontalAmount = value.translation.width
                let verticalAmount = abs(value.translation.height)
                let swipeThreshold: CGFloat = 50

                // 水平方向のスワイプのみ処理（垂直スクロールとの競合を避ける）
                if abs(horizontalAmount) > verticalAmount {
                    // 右スワイプ
                    if horizontalAmount > swipeThreshold && !isMenuPresented {
                        // 左端20px以内からのスワイプ → メニューを開く
                        if value.startLocation.x <= 20 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isMenuPresented = true
                            }
                        }
                    }
                    // 左スワイプ
                    else if horizontalAmount < -swipeThreshold {
                        if isMenuPresented {
                            // メニューが開いている → 閉じる
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isMenuPresented = false
                            }
                        } else {
                            // Audio画面へ遷移
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = .audioPlayback
                            }
                        }
                    }
                }
            }
    }
}

// MARK: - Tab Enum

public enum Tab {
    case clock
    case audioPlayback
    case settings
    case appSettings
}

// MARK: - TabButton

private struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var useAnalogColor: Bool = false
    let action: () -> Void

    private var foregroundColor: Color {
        if isSelected {
            return .accentColor
        } else if useAnalogColor {
            return DesignTokens.ClockColors.captionBlue
        } else {
            return DesignTokens.CommonTextColors.quaternary
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.caption)
            }
            .foregroundColor(foregroundColor)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
