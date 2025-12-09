//
//  AudioPlaybackView.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-09.
//  音声再生コントロール画面
//

import SwiftUI
import AVFoundation

/// 音源プリセット（SignalEngine による合成音源）
enum AudioSourcePreset: Identifiable {
    case synthesis(UISoundPreset)

    var id: String {
        switch self {
        case .synthesis(let preset):
            return "synthesis_\(preset.rawValue)"
        }
    }

    var displayName: String {
        switch self {
        case .synthesis(let preset):
            return preset.displayName
        }
    }

    var englishTitle: String {
        switch self {
        case .synthesis(let preset):
            return preset.englishTitle
        }
    }
}

// MARK: - Hashable & Equatable conformance
extension AudioSourcePreset: Hashable, Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AudioSourcePreset, rhs: AudioSourcePreset) -> Bool {
        lhs.id == rhs.id
    }

    /// All available audio sources
    static var allSources: [AudioSourcePreset] {
        // All presets are production presets now
        return UISoundPreset.allCases.map { AudioSourcePreset.synthesis($0) }
    }
}

/// 音声再生コントロールビュー
struct AudioPlaybackView: View {
    @EnvironmentObject var audioService: AudioService
    @Binding var selectedTab: Tab

    @State private var errorMessage: String?
    @State private var showError = false

    @AppStorage("showAudioTitle") private var showAudioTitle: Bool = true

    init(selectedTab: Binding<Tab>) {
        _selectedTab = selectedTab
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignTokens.SettingsColors.backgroundGradient
                    .ignoresSafeArea()

                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: DesignTokens.SettingsSpacing.sectionSpacing) {
                            // 上部コンテンツ
                            bluetoothStatusIndicator
                            soundSelectionSection
                            controlSection

                            Spacer(minLength: 24)

                            // 下部コンテンツ（Status〜Waveform）
                            VStack(spacing: DesignTokens.SettingsSpacing.sectionSpacing) {
                                statusSection
                                waveformSection
                            }
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                        .padding(.bottom, DesignTokens.SettingsSpacing.screenBottom)
                        .frame(minHeight: geometry.size.height)
                    }
                }
            }
            .navigationTitle("audio.title".localized)
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
                        selectedTab = .settings
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage ?? "不明なエラー")
            }
        }
    }

    // MARK: - Sections

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
            // Header
            Text("audio.sound".localized)
                .dynamicFont(
                    size: DynamicTheme.AudioTestTypography.headlineSize,
                    weight: DynamicTheme.AudioTestTypography.headlineWeight
                )
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            // Playlist with List + onMove (standard iOS drag)
            List {
                ForEach(Array(audioService.playlistState.orderedPresets.enumerated()), id: \.element.id) { index, preset in
                    PlaylistRowView(
                        preset: preset,
                        isCurrentTrack: index == audioService.playlistState.currentIndex,
                        isPlaying: audioService.isPlaying
                    )
                    .listRowBackground(
                        Rectangle()
                            .fill(DesignTokens.CommonBackgroundColors.cardHighlight)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .onTapGesture {
                        playFromPreset(preset)
                    }
                }
                .onMove { from, to in
                    audioService.playlistState.move(from: from, to: to)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(audioService.playlistState.orderedPresets.count) * 52)
            .environment(\.editMode, .constant(.active))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// タップした曲からプレイリスト再生を開始
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

    private var waveformSection: some View {
        HStack {
            Spacer()
            CircularWaveformView()
                .frame(width: 100, height: 100)
            Spacer()
        }
        .padding(.vertical, 8)
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

            // Current track (from playlist)
            if let currentPreset = audioService.playlistState.presetForCurrentIndex() {
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
            // プレイリスト再生を開始（現在の曲から）
            try audioService.playPlaylist()
        } catch let error as NSError {
            let detailedMessage = """
            再生エラー:
            Code: \(error.code)
            Domain: \(error.domain)
            Description: \(error.localizedDescription)
            """
            print("AudioPlaybackView: \(detailedMessage)")
            errorMessage = detailedMessage
            showError = true
        } catch {
            errorMessage = "再生エラー: \(error.localizedDescription)"
            print("AudioPlaybackView: \(errorMessage ?? "")")
            showError = true
        }
    }

    private func stopAudio() {
        audioService.stop()
    }
}

#Preview {
    AudioPlaybackView(selectedTab: .constant(.audioPlayback))
        .environmentObject(AudioService.shared)
        .environmentObject(AudioService.shared.playlistState)
}
