//
//  CategoryCard.swift
//  TsukiSound
//
//  Category card for grid selection view
//

import SwiftUI

/// Category card for grid display
struct CategoryCard: View {
    let title: String
    let icon: String
    let trackCount: Int
    let onPlayTapped: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 44))

                Text(title)
                    .font(.system(
                        size: DesignTokens.SettingsTypography.itemTitleSize,
                        weight: DesignTokens.SettingsTypography.itemTitleWeight
                    ))
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                Text("\(trackCount) " + "audio.sound".localized)
                    .font(.system(
                        size: DesignTokens.SettingsTypography.captionSize,
                        weight: DesignTokens.SettingsTypography.captionWeight
                    ))
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)

            // Play button
            if let onPlayTapped = onPlayTapped {
                Button(action: onPlayTapped) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.borderless)
                .frame(width: 44, height: 44)  // Minimum tap target
                .padding(12)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 16) {
            CategoryCard(title: "All", icon: "🎵", trackCount: 20, onPlayTapped: {
                print("Play All")
            })
            CategoryCard(title: "TsukiSound", icon: "🌙", trackCount: 11, onPlayTapped: {
                print("Play TsukiSound")
            })
        }
        .padding()
    }
}
