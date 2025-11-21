//
//  AudioTestView.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  オーディオシステムのテストビュー
//

import SwiftUI
import AVFoundation

/// 音源プリセット（SignalEngine による合成音源）
enum AudioSourcePreset: Identifiable {
    case synthesis(NaturalSoundPreset)

    var id: String {
        switch self {
        case .synthesis(let preset):
            return "synthesis_\(preset.rawValue)"
        }
    }

    var displayName: String {
        switch self {
        case .synthesis(let preset):
            let icon = preset.isTest ? "♟️ " : ""
            return icon + preset.displayName
        }
    }

    var isTest: Bool {
        switch self {
        case .synthesis(let preset):
            return preset.isTest
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

    /// All available audio sources (production first, then test in debug)
    static var allSources: [AudioSourcePreset] {
        var production: [AudioSourcePreset] = []
        var test: [AudioSourcePreset] = []

        // Collect synthesis presets
        for preset in NaturalSoundPreset.allCases {
            let source = AudioSourcePreset.synthesis(preset)
            if source.isTest {
                #if DEBUG
                test.append(source)
                #endif
            } else {
                production.append(source)
            }
        }

        // Production first, then test
        return production + test
    }
}

/// オーディオテストビュー
struct AudioTestView: View {
    @EnvironmentObject var audioService: AudioService
    @Binding var selectedTab: Tab

    @State private var selectedSource: AudioSourcePreset = .synthesis(.lunarPulse)

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

                ScrollView {
                    VStack(spacing: DesignTokens.SettingsSpacing.sectionSpacing) {
                        bluetoothStatusIndicator
                        soundSelectionSection
                        controlSection
                        statusSection
                        volumeSection

                        Spacer(minLength: DesignTokens.SettingsSpacing.bottomSpacer)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                    .padding(.bottom, DesignTokens.SettingsSpacing.screenBottom)
                }
            }
            .navigationTitle("Audio")
            .navigationBarTitleDisplayMode(.inline)
            .dynamicNavigationFont()
            .toolbarBackground(NavigationBarTokens.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedTab = .clock
                    }) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            selectedTab = .settings
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Button(action: {
                            selectedTab = .appSettings
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }

                // Audio アイコンは非表示（現在のページ）
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
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.SettingsSpacing.cardPadding)
        .padding(.vertical, 6)
    }

    private var soundSelectionSection: some View {
        // ✂️ Wrapper to center the narrower card
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 16) { // ✂️ Uniform spacing of 16pt between all 3 rows
                // ✂️ Title inside card for unified appearance
                Text("音源選択")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                // ✂️ Picker with centered layout
                // ✂️ Using HStack with Spacer() instead of GeometryReader to maintain proper spacing
                HStack {
                    Spacer()
                    Menu {
                        ForEach(AudioSourcePreset.allSources) { source in
                            Button(action: {
                                selectedSource = source
                            }) {
                                Text(source.displayName)
                            }
                            .disabled(audioService.isPlaying)
                        }
                    } label: {
                        HStack {
                            Text(selectedSource.displayName)
                                .font(.system(size: 17, design: .monospaced)) // ✂️ Larger font (15 -> 17)
                                .foregroundColor(DesignTokens.SettingsColors.accent) // ✂️ Blue for standard iOS look
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 14)) // ✂️ Slightly larger chevron (12 -> 14)
                                .foregroundColor(DesignTokens.SettingsColors.accent.opacity(0.6))
                        }
                        .frame(width: UIScreen.main.bounds.width * 0.49) // ✂️ 70% of card (which is 70% of screen) = 0.7 × 0.7 = 0.49
                        .contentShape(Rectangle())
                    }
                    Spacer()
                }

                // ✂️ English name inside card, right-aligned
                HStack {
                    Spacer()
                    Text(selectedSource.englishTitle)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.SettingsSpacing.cardPadding)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.15)) // ✂️ Darker background
            .cornerRadius(DesignTokens.SettingsLayout.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.SettingsLayout.cardCornerRadius)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 6, y: 2) // ✂️ Stronger shadow
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7) // ✂️ Card is 70% of screen width
            Spacer()
        }
    }

    private var controlSection: some View {
        HStack {
            Spacer()
            Button(action: togglePlayback) {
                HStack {
                    Image(systemName: audioService.isPlaying ? "stop.fill" : "play.fill")
                    Text(audioService.isPlaying ? "停止" : "再生")
                }
                .font(DesignTokens.SettingsTypography.headline)
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
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7)
            Spacer()
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.sectionInnerSpacing) {
            HStack {
                Text("音量（端末ボタンで制御）")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(Color.gray.opacity(0.7))
                Spacer()
                Text("\(Int(audioService.systemVolume * 100))%")
                    .font(.system(size: 15, design: .monospaced))
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
        .settingsCardStyle()
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.verticalSmall) {
            Text("ステータス")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            HStack {
                Circle()
                    .fill(
                        audioService.isPlaying
                            ? DesignTokens.SettingsColors.success
                            : DesignTokens.SettingsColors.inactive
                    )
                    .frame(width: 10, height: 10)
                Text(audioService.isPlaying ? "再生中" : "停止中")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            }

            if let reason = audioService.pauseReason {
                HStack {
                    Text("停止理由:")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                    Text(reason.rawValue)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(DesignTokens.SettingsColors.warning)
                }
            }

            // Selected source (inline)
            HStack(spacing: 4) {
                Text("選択中:")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)

                Text(selectedSource.englishTitle)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsCardStyle()
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
            print("AudioTestView: \(detailedMessage)")
            errorMessage = detailedMessage
            showError = true
        } catch {
            errorMessage = "再生エラー: \(error.localizedDescription)"
            print("AudioTestView: \(errorMessage ?? "")")
            showError = true
        }
    }

    private func stopAudio() {
        audioService.stop()
    }
}

#Preview {
    AudioTestView(selectedTab: .constant(.audioTest))
        .environmentObject(AudioService.shared)
}
