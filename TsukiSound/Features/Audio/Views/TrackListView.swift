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
                        // Bluetooth status
                        bluetoothStatusIndicator

                        // Sound selection section
                        soundSelectionSection
                            .padding(.top, 8)

                        // Play button
                        controlSection
                            .padding(.top, 12)

                        Spacer()

                        // Status section
                        statusSection
                    }
                    .padding(.top, 16)
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
        .onAppear {
            // Set category when view appears
            playlistState.setCategory(category)
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

    @ViewBuilder
    private var bluetoothStatusIndicator: some View {
        HStack(spacing: 8) {
            Spacer()

            Text(audioService.outputRoute.icon)
                .font(.system(size: 20))

            Text(audioService.outputRoute.displayName)
                .dynamicFont(
                    size: DynamicTheme.AudioTestTypography.statusIndicatorSize,
                    weight: DynamicTheme.AudioTestTypography.statusIndicatorWeight
                )
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.SettingsSpacing.cardPadding)
        .padding(.vertical, 6)
    }

    private var soundSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Repeat mode toggle
            repeatModeToggle

            // Playlist with List + onMove
            List {
                ForEach(Array(displayedPresets.enumerated()), id: \.element.id) { index, preset in
                    let isCurrentlyPlaying = playlistState.presetForCurrentIndex() == preset && audioService.isPlaying

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
                }
                .onMove { from, to in
                    playlistState.move(from: from, to: to)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(displayedPresets.count) * 44)
            .environment(\.editMode, .constant(.active))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Play from tapped preset
    private func playFromPreset(_ preset: UISoundPreset) {
        do {
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

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.verticalSmall) {
            Text("audio.status".localized)
                .dynamicFont(
                    size: DynamicTheme.AudioTestTypography.statusTitleSize,
                    weight: DynamicTheme.AudioTestTypography.statusTitleWeight
                )
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            HStack {
                Circle()
                    .fill(
                        audioService.isPlaying
                            ? DesignTokens.SettingsColors.success
                            : DesignTokens.SettingsColors.inactive
                    )
                    .frame(width: 10, height: 10)
                Text(audioService.isPlaying ? "audio.playing".localized : "audio.stopped".localized)
                    .dynamicFont(
                        size: DynamicTheme.AudioTestTypography.statusTextSize,
                        weight: DynamicTheme.AudioTestTypography.statusTextWeight
                    )
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            }

            if let reason = audioService.pauseReason {
                HStack {
                    Text("audio.pauseReason".localized)
                        .dynamicFont(
                            size: DynamicTheme.AudioTestTypography.statusCaptionSize,
                            weight: DynamicTheme.AudioTestTypography.statusCaptionWeight
                        )
                        .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                    Text(reason.rawValue)
                        .dynamicFont(
                            size: DynamicTheme.AudioTestTypography.statusCaptionSize,
                            weight: DynamicTheme.AudioTestTypography.statusCaptionWeight
                        )
                        .foregroundColor(DesignTokens.SettingsColors.warning)
                }
            }

            // Current track
            if let currentPreset = playlistState.presetForCurrentIndex() {
                HStack(spacing: 4) {
                    Text("audio.selected".localized)
                        .dynamicFont(
                            size: DynamicTheme.AudioTestTypography.statusCaptionSize,
                            weight: DynamicTheme.AudioTestTypography.statusCaptionWeight
                        )
                        .foregroundColor(DesignTokens.SettingsColors.textSecondary)

                    Text(currentPreset.englishTitle)
                        .dynamicFont(
                            size: DynamicTheme.AudioTestTypography.statusCaptionSize,
                            weight: DynamicTheme.AudioTestTypography.statusCaptionWeight
                        )
                        .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.SettingsSpacing.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.SettingsLayout.cardCornerRadius)
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
                RoundedRectangle(cornerRadius: DesignTokens.SettingsLayout.cardCornerRadius)
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
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
    }

    // MARK: - Actions

    private func togglePlayback() {
        if audioService.isPlaying {
            stopAudio()
        } else {
            playAudio()
        }
    }

    private func playAudio() {
        do {
            try audioService.playPlaylist()
        } catch let error as NSError {
            let detailedMessage = """
            再生エラー:
            Code: \(error.code)
            Domain: \(error.domain)
            Description: \(error.localizedDescription)
            """
            #if DEBUG
            print("🐛 TrackListView: \(detailedMessage)")
            #endif
            errorMessage = detailedMessage
            showError = true
        } catch {
            errorMessage = "再生エラー: \(error.localizedDescription)"
            #if DEBUG
            print("🐛 TrackListView: \(errorMessage ?? "")")
            #endif
            showError = true
        }
    }

    private func stopAudio() {
        audioService.stop()
    }
}

#Preview {
    NavigationStack {
        TrackListView(category: .tsukiSound)
            .environmentObject(AudioService.shared)
            .environmentObject(AudioService.shared.playlistState)
    }
}
