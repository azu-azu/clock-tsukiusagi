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
    @Binding var selectedTab: Tab

    public init(selectedTab: Binding<Tab>) {
        _settings = State(initialValue: AudioSettings.load())
        _selectedTab = selectedTab
    }

    public var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション（DesignTokens使用）
                DesignTokens.SettingsColors.backgroundGradient
                    .ignoresSafeArea()

                // 設定コンテンツ
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.sectionSpacing) {
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
                                            .dynamicFont(size: DesignTokens.SettingsTypography.itemTitleSize, weight: DesignTokens.SettingsTypography.itemTitleWeight)
                                            .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                                        Spacer()
                                        Text(DateFormatter.localizedString(from: nextBreak, dateStyle: .none, timeStyle: .short))
                                            .dynamicFont(size: DesignTokens.SettingsTypography.itemTitleSize, weight: DesignTokens.SettingsTypography.itemTitleWeight)
                                            .foregroundColor(DesignTokens.SettingsColors.accent)
                                    }
                                    .padding(.vertical, DesignTokens.SettingsSpacing.verticalSmall)
                                }
                            }
                        }

                        // MARK: - Volume Safety Section (Phase 2)

                        SettingsSection(title: "Volume Safety") {
                            VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.verticalMedium) {
                                HStack {
                                    Text("Maximum Output Level")
                                        .dynamicFont(size: DesignTokens.SettingsTypography.itemTitleSize, weight: DesignTokens.SettingsTypography.itemTitleWeight)
                                        .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                                    Spacer()
                                    Text("\(String(format: "%.1f", settings.maxOutputDb)) dB")
                                        .dynamicFont(size: DesignTokens.SettingsTypography.itemTitleSize, weight: DesignTokens.SettingsTypography.itemTitleWeight)
                                        .foregroundColor(DesignTokens.SettingsColors.accent)
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
                                .tint(DesignTokens.SettingsColors.accent)

                                Text("Limits the maximum output volume to protect your hearing. Default: -6.0 dB")
                                    .dynamicFont(size: DesignTokens.SettingsTypography.captionSize, weight: DesignTokens.SettingsTypography.captionWeight)
                                    .foregroundColor(DesignTokens.SettingsColors.textQuaternary)
                            }
                            .padding(.vertical, DesignTokens.SettingsSpacing.verticalSmall)
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

                        Spacer(minLength: DesignTokens.SettingsSpacing.bottomSpacer)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                    .padding(.bottom, DesignTokens.SettingsSpacing.screenBottom)
                }
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .dynamicNavigationFont()
            .toolbarBackground(NavigationBarTokens.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedTab = .clock
                    }) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            selectedTab = .appSettings
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Button(action: {
                            selectedTab = .audioTest
                        }) {
                            Image(systemName: "music.quarternote.3")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }

                // Settings アイコンは非表示（現在のページ）
            }
        }
    }

    // MARK: - Private Methods

    private func saveSettings() {
        settings.save()
        audioService.updateSettings(settings)
    }
}

// MARK: - Preview

#Preview {
    AudioSettingsView(selectedTab: .constant(.settings))
        .environmentObject(AudioService.shared)
}
