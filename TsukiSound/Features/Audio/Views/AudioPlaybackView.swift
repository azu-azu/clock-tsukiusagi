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

    @State private var selectedSource: AudioSourcePreset = .synthesis(.jupiter)

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
                                volumeSection
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
            .onChange(of: selectedSource) { oldValue, newValue in
                // Automatic preset switching when playing
                guard oldValue != newValue else { return }

                if audioService.isPlaying {
                    // Stop current playback and switch to new preset
                    audioService.stopAndWait(fadeOut: 0.5) {
                        playAudio()
                    }
                }
                // If not playing, just update the selection (no automatic playback)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("audio.sound".localized)
                .dynamicFont(
                    size: DynamicTheme.AudioTestTypography.headlineSize,
                    weight: DynamicTheme.AudioTestTypography.headlineWeight
                )
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            HStack {
                Spacer()
                Menu {
                    ForEach(AudioSourcePreset.allSources) { source in
                        Button(action: {
                            selectedSource = source
                        }) {
                            Text(source.displayName)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedSource.displayName)
                            .dynamicFont(
                                size: DynamicTheme.AudioTestTypography.soundMenuSize,
                                weight: DynamicTheme.AudioTestTypography.soundMenuWeight
                            )
                            .foregroundColor(DesignTokens.SettingsColors.accent)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.SettingsColors.accent.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                Spacer()
            }

            HStack {
                Spacer()
                Text(selectedSource.englishTitle)
                    .dynamicFont(
                        size: DynamicTheme.AudioTestTypography.englishTitleSize,
                        weight: DynamicTheme.AudioTestTypography.englishTitleWeight
                    )
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.SettingsSpacing.cardPadding)
        .background(
            ZStack {
                // 背景色（cardHighlight: より濃いめ）
                RoundedRectangle(cornerRadius: DesignTokens.SettingsLayout.cardCornerRadius)
                    .fill(DesignTokens.CommonBackgroundColors.cardHighlight)
                // 上辺ハイライト（光）
                RoundedRectangle(cornerRadius: DesignTokens.SettingsLayout.cardCornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
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

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.sectionInnerSpacing) {
            HStack {
                Text("audio.volume".localized)
                    .dynamicFont(
                        size: DynamicTheme.AudioTestTypography.volumeLabelSize,
                        weight: DynamicTheme.AudioTestTypography.volumeLabelWeight
                    )
                    .foregroundColor(Color.gray.opacity(0.7))
                Spacer()
                Text("\(Int(audioService.systemVolume * 100))%")
                    .dynamicFont(
                        size: DynamicTheme.AudioTestTypography.volumeLabelSize,
                        weight: DynamicTheme.AudioTestTypography.volumeLabelWeight
                    )
                    .foregroundColor(Color.gray.opacity(0.7))
            }

            HStack(spacing: DesignTokens.SettingsSpacing.sectionInnerSpacing) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(Color.gray.opacity(0.6))

                // Read-only progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)

                        // Filled portion
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: geometry.size.width * CGFloat(audioService.systemVolume), height: 8)
                    }
                }
                .frame(height: 8)

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(Color.gray.opacity(0.6))
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

            // Selected source (inline)
            HStack(spacing: 4) {
                Text("audio.selected".localized)
                    .dynamicFont(
                        size: DynamicTheme.AudioTestTypography.statusCaptionSize,
                        weight: DynamicTheme.AudioTestTypography.statusCaptionWeight
                    )
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)

                Text(selectedSource.englishTitle)
                    .dynamicFont(
                        size: DynamicTheme.AudioTestTypography.statusCaptionSize,
                        weight: DynamicTheme.AudioTestTypography.statusCaptionWeight
                    )
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
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
            // SignalEngine による合成音源を再生
            switch selectedSource {
            case .synthesis(let preset):
                try audioService.play(preset: preset)
            }

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
}
