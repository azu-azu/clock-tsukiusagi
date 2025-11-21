//
//  AppSettingsView.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-21.
//  アプリ全般の設定UI（将来的な拡張用）
//

import SwiftUI

public struct AppSettingsView: View {
    @Binding var selectedTab: Tab
    @AppStorage(FontStyle.userDefaultsKey) private var fontStyleRaw: String = FontStyle.rounded.rawValue

    private var fontStyle: FontStyle {
        FontStyle(rawValue: fontStyleRaw) ?? .rounded
    }

    public init(selectedTab: Binding<Tab>) {
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
                    settingsContent
                }
            }
            .navigationTitle("App Settings")
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
                            selectedTab = .settings
                        }) {
                            Image(systemName: "slider.horizontal.3")
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
            }
        }
        .navigationViewStyle(.stack)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.sectionSpacing) {

            // MARK: - About Section

            SettingsSection(title: "About") {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Version")
                                        .font(DesignTokens.SettingsTypography.itemTitle)
                                        .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                                    Spacer()

                                    Text("1.0.0")
                                        .font(DesignTokens.SettingsTypography.itemTitle)
                                        .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                                }
                                .padding(.vertical, DesignTokens.SettingsSpacing.verticalSmall)

                                Divider()
                                    .background(Color.white.opacity(0.2))

                                HStack {
                                    Text("App Name")
                                        .font(DesignTokens.SettingsTypography.itemTitle)
                                        .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                                    Spacer()

                                    Text("TsukiUsagi Clock")
                                        .font(DesignTokens.SettingsTypography.itemTitle)
                                        .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                                }
                                .padding(.vertical, DesignTokens.SettingsSpacing.verticalSmall)
                            }
                            .padding(DesignTokens.SettingsSpacing.cardPadding)
                        }

                        // MARK: - Appearance Section

                        SettingsSection(title: "Appearance") {
                            VStack(alignment: .leading, spacing: 16) {
                                // Font Style
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Font Style")
                                        .font(DesignTokens.SettingsTypography.itemTitle)
                                        .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                                    ForEach(FontStyle.allCases, id: \.self) { style in
                                        fontStyleOption(style)
                                    }
                                }
                                .padding(.vertical, DesignTokens.SettingsSpacing.verticalSmall)
                            }
                            .padding(DesignTokens.SettingsSpacing.cardPadding)
                        }

                        // MARK: - Data Section (placeholder for future features)

                        SettingsSection(title: "Data & Privacy") {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Coming Soon")
                                    .font(DesignTokens.SettingsTypography.itemTitle)
                                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                                    .padding(.vertical, DesignTokens.SettingsSpacing.verticalSmall)
                            }
                            .padding(DesignTokens.SettingsSpacing.cardPadding)
                        }

            Spacer(minLength: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Font Style Option

    private func fontStyleOption(_ style: FontStyle) -> some View {
        Button(action: {
            fontStyleRaw = style.rawValue
        }) {
            HStack(spacing: 12) {
                // 選択インジケーター
                Image(systemName: fontStyle == style ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(fontStyle == style ? DesignTokens.SettingsColors.accent : DesignTokens.SettingsColors.textSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(style.displayName)
                        .font(fontForStyle(style))
                        .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                    Text(style.description)
                        .font(DesignTokens.SettingsTypography.itemTitle)
                        .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Methods

    private func fontForStyle(_ style: FontStyle) -> Font {
        style.font
    }
}

// MARK: - Preview

#Preview {
    AppSettingsView(selectedTab: .constant(.settings))
        .environmentObject(AudioService.shared)
}
