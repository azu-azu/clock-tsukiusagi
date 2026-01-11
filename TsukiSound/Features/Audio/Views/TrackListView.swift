//
//  TrackListView.swift
//  TsukiSound
//
//  Track list view for a selected category
//

import SwiftUI

/// Track list view displaying presets for a category
struct TrackListView: View {
    let category: AudioCategory?  // nil = All

    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var playlistState: PlaylistState

    @State private var errorMessage: String?
    @State private var showError = false

    /// Presets to display based on category
    private var displayedPresets: [UISoundPreset] {
        guard let category = category else {
            return playlistState.orderedPresets
        }
        let categoryPresets = Set(category.presets)
        return playlistState.orderedPresets.filter { categoryPresets.contains($0) }
    }

    /// Navigation title based on category
    private var navigationTitle: String {
        if let category = category {
            return "\(category.icon) \(category.displayName)"
        }
        return "🎵 " + "category.all".localized
    }

    var body: some View {
        ZStack {
            DesignTokens.SettingsColors.backgroundGradient
                .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Sound selection section
                        soundSelectionSection

                        // Play button
                        controlSection
                            .padding(.top, 12)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                    .padding(.bottom, DesignTokens.SettingsSpacing.screenBottom)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .dynamicNavigationFont()
        .toolbarBackground(NavigationBarTokens.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("エラー", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "不明なエラー")
        }
    }

    // MARK: - Sections

    private var repeatModeToggle: some View {
        Button(action: {
            playlistState.repeatMode = playlistState.repeatMode == .one ? .all : .one
        }) {
            HStack(spacing: 6) {
                Image(systemName: playlistState.repeatMode.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(playlistState.repeatMode.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    private var soundSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Repeat mode toggle
            repeatModeToggle

            // Playlist with List + onMove
            ScrollViewReader { proxy in
                // Calculate once outside ForEach for performance
                let currentPreset = playlistState.presetForCurrentIndex()
                let isCurrentPresetInCategory = currentPreset.map { displayedPresets.contains($0) } ?? false

                List {
                    ForEach(Array(displayedPresets.enumerated()), id: \.element.id) { index, preset in
                        // Only highlight if currently playing AND in current category
                        let isCurrentlyPlaying = currentPreset == preset && audioService.isPlaying && isCurrentPresetInCategory

                        PlaylistRowView(preset: preset)
                            .listRowBackground(
                                Rectangle()
                                    .fill(DesignTokens.CommonBackgroundColors.cardHighlight)
                                    .overlay(
                                        Rectangle()
                                            .stroke(
                                                isCurrentlyPlaying
                                                    ? DesignTokens.SettingsColors.accent
                                                    : Color.white.opacity(0.1),
                                                lineWidth: isCurrentlyPlaying ? 1.5 : 0.5
                                            )
                                    )
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .onTapGesture {
                                playFromPreset(preset)
                            }
                            .id(preset.id) // Required for scrollTo
                    }
                    .onMove { from, to in
                        playlistState.move(from: from, to: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(displayedPresets.count) * 44)
                .environment(\.editMode, .constant(.active))
                .onAppear {
                    // Scroll to currently playing track if it exists in this category
                    if let currentPreset = playlistState.presetForCurrentIndex(),
                       displayedPresets.contains(currentPreset) {
                        proxy.scrollTo(currentPreset.id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Play from tapped preset
    private func playFromPreset(_ preset: UISoundPreset) {
        do {
            // Set category before playing
            playlistState.setCategory(category)
            try audioService.playPlaylist(startingFrom: preset)
        } catch {
            errorMessage = "再生エラー: \(error.localizedDescription)"
            showError = true
        }
    }

    private var controlSection: some View {
        HStack {
            Spacer()
            Button(action: togglePlayback) {
                HStack {
                    Image(systemName: audioService.isPlaying ? "stop.fill" : "play.fill")
                    Text(audioService.isPlaying ? "audio.stop".localized : "audio.play".localized)
                }
                .dynamicFont(
                    size: DynamicTheme.AudioTestTypography.headlineSize,
                    weight: DynamicTheme.AudioTestTypography.headlineWeight
                )
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.SettingsLayout.buttonPadding)
                .background(
                    audioService.isPlaying
                        ? DesignTokens.SettingsColors.danger
                        : DesignTokens.SettingsColors.accent
                )
                .cornerRadius(DesignTokens.SettingsLayout.buttonCornerRadius)
            }
            .frame(maxWidth: 200)
            Spacer()
        }
    }

    // MARK: - Actions

    private func togglePlayback() {
        if audioService.isPlaying {
            audioService.stop()
        } else {
            playAudio()
        }
    }

    private func playAudio() {
        do {
            // Set category before playing
            playlistState.setCategory(category)
            try audioService.playPlaylist()
        } catch {
            errorMessage = "再生エラー: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        TrackListView(category: .tsukiSound)
            .environmentObject(AudioService.shared)
            .environmentObject(AudioService.shared.playlistState)
    }
}
