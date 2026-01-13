//
//  MiniPlayerView.swift
//  TsukiSound
//
//  Spotify-style floating mini player
//

import SwiftUI

/// Floating mini player shown when a track is selected (Spotify-style)
struct MiniPlayerView: View {
    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var playlistState: PlaylistState

    var body: some View {
        if let preset = playlistState.presetForCurrentIndex() {
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

                        // Only show pause reason warning (not normal playing/stopped status)
                        if let reason = audioService.pauseReason {
                            Text("⚠️ " + reason.displayName)
                                .font(.system(
                                    size: DesignTokens.SettingsTypography.captionSize,
                                    weight: DesignTokens.SettingsTypography.captionWeight
                                ))
                                .foregroundColor(DesignTokens.SettingsColors.warning)
                        }
                    }

                    Spacer()

                    // Output route indicator (SF Symbol)
                    Image(systemName: audioService.outputRoute.systemImageName)
                        .font(.system(size: 18))
                        .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                        .allowsHitTesting(false)

                    // Waveform visualization
                    CircularWaveformView()
                        .frame(width: 40, height: 40)
                        .allowsHitTesting(false)

                    // Play/Stop toggle button
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: audioService.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(DesignTokens.CommonBackgroundColors.card)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: DesignTokens.CommonBackgroundColors.shadowStrong, radius: 12, x: 0, y: -4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignTokens.CommonBackgroundColors.cardBorderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func togglePlayback() {
        if audioService.isPlaying {
            audioService.stop()
        } else {
            try? audioService.playPlaylist()
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        DesignTokens.CommonBackgroundColors.previewBackground.ignoresSafeArea()

        // Simulated mini player preview
        HStack(spacing: 12) {
            Text("🪐")
                .font(.system(size: 28))

            Text("Jupiter (Holst)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignTokens.CommonTextColors.primary)
                .lineLimit(1)

            Spacer()

            // Output route indicator
            Image(systemName: "headphones")
                .font(.system(size: 18))
                .foregroundColor(DesignTokens.SettingsColors.textSecondary)

            // Waveform placeholder
            Circle()
                .fill(DesignTokens.CommonBackgroundColors.cardHighlight)
                .frame(width: 40, height: 40)

            // Play button
            Image(systemName: "stop.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DesignTokens.CommonTextColors.primary)
                .frame(width: 44, height: 44)
                .background(DesignTokens.CommonBackgroundColors.card)
                .clipShape(Circle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
