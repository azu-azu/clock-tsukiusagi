//
//  AppSettingsView.swift
//  TsukiSound
//
//  App settings UI (appearance, language)
//

import SwiftUI

public struct AppSettingsView: View {
    @Binding var selectedTab: Tab
    @AppStorage(FontStyle.userDefaultsKey) private var fontStyleRaw: String = FontStyle.rounded.rawValue
    @ObservedObject private var languageProvider = LanguageProvider.shared

    private var fontStyle: FontStyle {
        FontStyle(rawValue: fontStyleRaw) ?? .rounded
    }

    private var language: AppLanguage {
        languageProvider.language
    }

    public init(selectedTab: Binding<Tab>) {
        _selectedTab = selectedTab
    }

    public var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                DesignTokens.SettingsColors.backgroundGradient
                    .ignoresSafeArea()

                // Settings content
                ScrollView {
                    settingsContent
                }
            }
            .navigationTitle("settings.app.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .dynamicNavigationFont()
            .toolbarBackground(NavigationBarTokens.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBackButton {
                selectedTab = .clock
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedTab = .audioPlayback
                    }) {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .id(languageProvider.language) // Force view refresh on language change
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.sectionSpacing) {

            // MARK: - Appearance Section

            SettingsSection(title: "settings.app.appearance".localized) {
                VStack(alignment: .leading, spacing: 16) {
                    // Font Style
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.app.fontStyle".localized)
                            .dynamicFont(size: DesignTokens.SettingsTypography.itemTitleSize, weight: DesignTokens.SettingsTypography.itemTitleWeight)
                            .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                        ForEach(FontStyle.allCases, id: \.self) { style in
                            fontStyleOption(style)
                        }
                    }
                    .padding(.vertical, DesignTokens.SettingsSpacing.verticalSmall)

                    Divider()
                        .background(DesignTokens.CommonBackgroundColors.cardBorderSubtle)

                    // Language
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.app.language".localized)
                            .dynamicFont(size: DesignTokens.SettingsTypography.itemTitleSize, weight: DesignTokens.SettingsTypography.itemTitleWeight)
                            .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                        ForEach(AppLanguage.allCases) { lang in
                            languageOption(lang)
                        }
                    }
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
                // Selection indicator
                Image(systemName: fontStyle == style ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(fontStyle == style ? DesignTokens.SettingsColors.accent : DesignTokens.SettingsColors.textSecondary)

                Text(style.displayName)
                    .font(fontForStyle(style))
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Language Option

    private func languageOption(_ lang: AppLanguage) -> some View {
        Button(action: {
            languageProvider.language = lang
        }) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: language == lang ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(language == lang ? DesignTokens.SettingsColors.accent : DesignTokens.SettingsColors.textSecondary)

                Text(lang.displayName)
                    .dynamicFont(size: DesignTokens.SettingsTypography.itemTitleSize, weight: .regular)
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)

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
