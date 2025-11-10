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
                    AudioTestView()

                case .settings:
                    AudioSettingsView()
                }
            }

            // 上部のカスタムタブバー（レイヤーを上に、背景透明）
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    TabButton(
                        icon: "clock.fill",
                        label: "Clock",
                        isSelected: selectedTab == .clock
                    ) {
                        selectedTab = .clock
                    }

                    TabButton(
                        icon: "waveform",
                        label: "Audio Test",
                        isSelected: selectedTab == .audioTest
                    ) {
                        selectedTab = .audioTest
                    }

                    TabButton(
                        icon: "gearshape.fill",
                        label: "Settings",
                        isSelected: selectedTab == .settings
                    ) {
                        selectedTab = .settings
                    }
                }
                .frame(height: 60)
                .padding(.top, 10)

                Spacer()
            }
        }
        .statusBarHidden(true)
    }
}

// MARK: - Tab Enum

private enum Tab {
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
