//
//  AudioSettingsView.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-10.
//  オーディオ設定UI（Phase 2: Quiet Break + Volume Limit）
//

import SwiftUI

public struct AudioSettingsView: View {
    @EnvironmentObject private var audioService: AudioService
    @State private var settings: AudioSettings

    public init() {
        _settings = State(initialValue: AudioSettings.load())
    }

    public var body: some View {
        ZStack {
            // 背景グラデーション（時計画面と同様のトーン）
            LinearGradient(
                colors: [
                    SkyTone.night.gradStart,
                    SkyTone.night.gradEnd
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 設定コンテンツ
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 64)

                    // MARK: - Route Safety Section

                        SettingsSection(title: "Route Safety") {
                            SettingsToggle(
                                title: "Headphone-Only Mode",
                                subtitle: "Auto-pause when headphones are removed",
                                isOn: Binding(
                                    get: { settings.onlyHeadphoneOutput },
                                    set: {
                                        settings.onlyHeadphoneOutput = $0
                                        saveSettings()
                                    }
                                )
                            )

                            SettingsToggle(
                                title: "Auto-Resume After Interruption",
                                subtitle: "Resume playback after phone calls, etc.",
                                isOn: Binding(
                                    get: { settings.autoResumeAfterInterruption },
                                    set: {
                                        settings.autoResumeAfterInterruption = $0
                                        saveSettings()
                                    }
                                )
                            )
                        }

                        // MARK: - Quiet Break Section (Phase 2)

                        SettingsSection(title: "Quiet Break Schedule") {
                            SettingsToggle(
                                title: "Enable Quiet Breaks",
                                subtitle: "Automatic break scheduling",
                                isOn: Binding(
                                    get: { settings.quietBreakEnabled },
                                    set: {
                                        settings.quietBreakEnabled = $0
                                        saveSettings()
                                    }
                                )
                            )

                            if settings.quietBreakEnabled {
                                SettingsStepper(
                                    title: "Play Duration",
                                    value: Binding(
                                        get: { settings.playMinutes },
                                        set: {
                                            settings.playMinutes = $0
                                            saveSettings()
                                        }
                                    ),
                                    range: 10...120,
                                    step: 5,
                                    unit: "min"
                                )

                                SettingsStepper(
                                    title: "Break Duration",
                                    value: Binding(
                                        get: { settings.breakMinutes },
                                        set: {
                                            settings.breakMinutes = $0
                                            saveSettings()
                                        }
                                    ),
                                    range: 1...30,
                                    step: 1,
                                    unit: "min"
                                )

                                // 次の休憩時刻を表示
                                if let nextBreak = audioService.breakScheduler.nextBreakAt {
                                    HStack {
                                        Text("Next Break")
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                        Text(DateFormatter.localizedString(from: nextBreak, dateStyle: .none, timeStyle: .short))
                                            .foregroundColor(.accentColor)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }

                        // MARK: - Volume Safety Section (Phase 2)

                        SettingsSection(title: "Volume Safety") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Maximum Output Level")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(String(format: "%.1f", settings.maxOutputDb)) dB")
                                        .foregroundColor(.accentColor)
                                        .monospacedDigit()
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(settings.maxOutputDb) },
                                        set: {
                                            settings.maxOutputDb = Float($0)
                                            saveSettings()
                                        }
                                    ),
                                    in: -12.0...0.0,
                                    step: 0.5
                                )
                                .tint(.accentColor)

                                Text("Limits the maximum output volume to protect your hearing. Default: -6.0 dB")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.vertical, 8)
                        }

                        // MARK: - Live Activity (Phase 3)
                        if #available(iOS 16.1, *) {
                            SettingsSection(title: "Live Activity") {
                                SettingsToggle(
                                    title: "Enable Live Activity",
                                    subtitle: "Show playback status on Lock Screen and Dynamic Island",
                                    isOn: Binding(
                                        get: { settings.liveActivityEnabled },
                                        set: {
                                            settings.liveActivityEnabled = $0
                                            saveSettings()
                                        }
                                    )
                                )
                            }
                        }

                        Spacer(minLength: 40)
                    }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Private Methods

    private func saveSettings() {
        settings.save()
        audioService.updateSettings(settings)
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 16) {
                content
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.white)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.accentColor)
        }
    }
}

struct SettingsStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Stepper(
                value: $value,
                in: range,
                step: step
            ) {
                Text("\(value) \(unit)")
                    .foregroundColor(.accentColor)
                    .monospacedDigit()
                    .frame(minWidth: 80, alignment: .trailing)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AudioSettingsView()
        .environmentObject(AudioService.shared)
}
