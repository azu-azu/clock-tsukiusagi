//
//  CategorySelectorView.swift
//  TsukiSound
//
//  Horizontal scrollable category selector for audio presets
//

import SwiftUI

/// Category selector chip button
struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(icon)
                Text(title)
                    .font(.system(size: DesignTokens.SettingsTypography.itemTitleSize,
                                  weight: DesignTokens.SettingsTypography.itemTitleWeight))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ?
                        DesignTokens.SettingsColors.accent :
                        Color.white.opacity(0.1))
            .foregroundColor(isSelected ?
                             DesignTokens.CosmosColors.background :
                             DesignTokens.SettingsColors.textPrimary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

/// Horizontal scrollable category selector
struct CategorySelectorView: View {
    @EnvironmentObject var playlistState: PlaylistState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" option
                CategoryChip(
                    title: "category.all".localized,
                    icon: "🎵",
                    isSelected: playlistState.selectedCategory == nil
                ) {
                    playlistState.setCategory(nil)
                }

                // Category buttons
                ForEach(AudioCategory.allCases) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: playlistState.selectedCategory == category
                    ) {
                        playlistState.setCategory(category)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.SettingsSpacing.cardPadding)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CategorySelectorView()
            .environmentObject(PlaylistState())
    }
}
