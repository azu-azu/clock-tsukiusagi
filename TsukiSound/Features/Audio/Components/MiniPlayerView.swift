//
//  MiniPlayerView.swift
//  TsukiSound
//
//  Spotify-style floating mini player
//

import SwiftUI

/// Floating mini player shown when audio is playing
struct MiniPlayerView: View {
    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var playlistState: PlaylistState

    var body: some View {
        if audioService.isPlaying, let preset = playlistState.presetForCurrentIndex() {
            NavigationLink {
                TrackListView(category: playlistState.selectedCategory)
            } label: {
                HStack(spacing: 12) {
                    // Track icon
                    Text(preset.icon)
                        .font(.system(size: 28))

                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.englishTitle)
                            .font(.system(
                                size: DesignTokens.SettingsTypography.itemTitleSize,
                                weight: .medium
                            ))
                            .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                            .lineLimit(1)

                        Text("audio.playing".localized)
                            .font(.system(
                                size: DesignTokens.SettingsTypography.captionSize,
                                weight: DesignTokens.SettingsTypography.captionWeight
                            ))
                            .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                    }

                    Spacer()

                    // Stop button
                    Button {
                        audioService.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: -4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()

        // Simulated mini player preview
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("🪐")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Jupiter (Holst)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Text("Playing")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "stop.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
