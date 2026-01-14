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

    /// Whether mini player should be visible (has a selected track)
    private var showMiniPlayer: Bool {
        playlistState.presetForCurrentIndex() != nil
    }

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
        ZStack(alignment: .bottom) {
            DesignTokens.SettingsColors.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Repeat mode toggle
                HStack {
                    repeatModeToggle
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                .padding(.bottom, 12)

                // Track list (fills remaining space)
                trackListSection
                    .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                    .padding(.bottom, showMiniPlayer ? 100 : 32)
            }

            // Floating mini player
            MiniPlayerView()
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showMiniPlayer)
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
        .onAppear {
            // Update category when entering (only if not playing)
            // This ensures MiniPlayer shows a track from this category
            if !audioService.isPlaying {
                playlistState.setCategory(category)
            }
        }
    }

    // MARK: - Sections

    private var repeatModeToggle: some View {
        Button(action: {
            playlistState.repeatMode = playlistState.repeatMode.next
        }) {
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
    }

    private var trackListSection: some View {
        ScrollViewReader { proxy in
            // Calculate once outside ForEach for performance
            let currentPreset = playlistState.presetForCurrentIndex()
            let isCurrentPresetInCategory = currentPreset.map { displayedPresets.contains($0) } ?? false

            List {
                ForEach(displayedPresets) { preset in
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
                                                : DesignTokens.CommonBackgroundColors.cardBorderSubtle,
                                            lineWidth: isCurrentlyPlaying ? 1.5 : 0.5
                                        )
                                )
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
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

}

#Preview {
    NavigationStack {
        TrackListView(category: .tsukiSound)
            .environmentObject(AudioService.shared)
            .environmentObject(AudioService.shared.playlistState)
    }
}
