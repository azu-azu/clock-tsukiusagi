import SwiftUI

public struct ContentView: View {
    @State private var selectedTab: Tab = .clock

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
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
                            label: "Audio Test",
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
        }
        .statusBarHidden(true)
    }
}

// MARK: - Tab Enum

public enum Tab {
    case clock
    case audioTest
    case settings
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
