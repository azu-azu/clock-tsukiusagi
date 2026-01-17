//
//  FullPlayerView.swift
//  TsukiSound
//
//  Full-screen player view shown as a sheet from MiniPlayer.
//  This view does NOT own navigation - it notifies the coordinator.
//

import SwiftUI

/// Full-screen player view (Spotify/Apple Music style)
/// Navigation is delegated to AudioPlayerCoordinator to prevent nested sheets.
struct FullPlayerView: View {
    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var playlistState: PlaylistState
    @EnvironmentObject var coordinator: AudioPlayerCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient
            DesignTokens.SettingsColors.backgroundGradient
                .ignoresSafeArea()

            if let preset = playlistState.presetForCurrentIndex() {
                VStack(spacing: 0) {
                    // Header with close and category buttons
                    headerBar

                    Spacer()

                    // Track name
                    Text(preset.englishTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                        .padding(.bottom, 24)

                    // Track description
                    descriptionCard(preset: preset)
                        .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)

                    Spacer()

                    // Playback controls
                    playbackControls
                        .padding(.bottom, 32)

                    // Status bar (repeat mode + output route)
                    statusBar
                        .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                        .padding(.bottom, 40)
                }
            } else {
                // No track selected
                Text("audio.noTrack".localized)
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            // Close button (left)
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Category navigation (right) - shows category name, notifies coordinator
            Button {
                coordinator.dismissFullPlayer(
                    navigateTo: .category(playlistState.selectedCategory)
                )
            } label: {
                HStack(spacing: 4) {
                    Text(categoryDisplayName)
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(DesignTokens.SettingsColors.accent)
            }
        }
        .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
        .padding(.top, 16)
    }

    // MARK: - Category Display Name

    private var categoryDisplayName: String {
        if let category = playlistState.selectedCategory {
            return category.displayName
        } else {
            return "category.all".localized
        }
    }

    // MARK: - Description Card

    private func descriptionCard(preset: UISoundPreset) -> some View {
        Text(preset.description)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignTokens.CommonBackgroundColors.cardSubtle)
            )
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 48) {
            // Previous track
            Button {
                skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
            }

            // Play/Stop button
            Button {
                togglePlayback()
            } label: {
                Image(systemName: audioService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
            }

            // Next track
            Button {
                skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            // Repeat mode toggle
            Button {
                playlistState.repeatMode = playlistState.repeatMode.next
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: playlistState.repeatMode.icon)
                        .font(.system(size: 14, weight: .medium))
                    Text(playlistState.repeatMode.displayName)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(
                    playlistState.repeatMode == .off
                        ? DesignTokens.SettingsColors.textSecondary
                        : DesignTokens.SettingsColors.accent
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignTokens.CommonBackgroundColors.cardSubtle)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    playlistState.repeatMode == .off
                                        ? DesignTokens.CommonBackgroundColors.cardBorderSubtle
                                        : DesignTokens.SettingsColors.accent.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
            }

            Spacer()

            // Output route indicator
            HStack(spacing: 6) {
                Image(systemName: audioService.outputRoute.systemImageName)
                    .font(.system(size: 16))
                Text(audioService.outputRoute.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(DesignTokens.SettingsColors.textSecondary)

            // Pause reason warning
            if let reason = audioService.pauseReason {
                Text("⚠️ " + reason.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.SettingsColors.warning)
                    .padding(.leading, 8)
            }
        }
    }

    // MARK: - Actions

    private func togglePlayback() {
        if audioService.isPlaying {
            audioService.stop()
        } else {
            try? audioService.playPlaylist()
        }
    }

    private func skipToNext() {
        let nextPreset = playlistState.advanceToNext()
        try? audioService.playPlaylist(startingFrom: nextPreset)
    }

    private func skipToPrevious() {
        let presets = playlistState.displayedPresets
        guard !presets.isEmpty else { return }

        // Calculate previous index
        let currentIndex = playlistState.currentIndex
        let previousIndex = currentIndex > 0 ? currentIndex - 1 : presets.count - 1
        let previousPreset = presets[previousIndex]

        playlistState.setCurrentIndex(to: previousPreset)
        try? audioService.playPlaylist(startingFrom: previousPreset)
    }
}

#Preview {
    FullPlayerView()
        .environmentObject(AudioService.shared)
        .environmentObject(AudioService.shared.playlistState)
        .environmentObject(AudioPlayerCoordinator())
}
