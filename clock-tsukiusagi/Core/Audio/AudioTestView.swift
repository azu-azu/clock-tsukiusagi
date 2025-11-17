//
//  AudioTestView.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  オーディオシステムのテストビュー
//

import SwiftUI
import AVFoundation

/// テスト用の音源タイプ
enum TestSoundType: String, CaseIterable {
    case synthesis = "🎵 合成音源"
    case audioFile = "📁 音源ファイル"
}

/// オーディオテストビュー
struct AudioTestView: View {
    @EnvironmentObject var audioService: AudioService
    @Binding var selectedTab: Tab

    @State private var selectedSound: TestSoundType = .synthesis
    @State private var selectedSynthesisPreset: NaturalSoundPreset = .clickSuppression
    @State private var selectedAudioFile: AudioFilePreset = .testTone

    @State private var errorMessage: String?
    @State private var showError = false

    init(selectedTab: Binding<Tab>) {
        _selectedTab = selectedTab
        configureNavigationBarAppearance()
    }

    private func configureNavigationBarAppearance() {
        // スクロール時の appearance（ブラーあり）
        let scrolledAppearance = UINavigationBarAppearance()
        scrolledAppearance.configureWithDefaultBackground()
        scrolledAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        scrolledAppearance.backgroundColor = .clear
        scrolledAppearance.shadowColor = .clear

        // Large Title のフォント設定（丸ゴシック体、カスタムサイズ）
        let largeTitleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let largeTitleDescriptor = largeTitleFont.fontDescriptor.withDesign(.rounded) ?? largeTitleFont.fontDescriptor
        scrolledAppearance.largeTitleTextAttributes = [
            .font: UIFont(descriptor: largeTitleDescriptor, size: 28),
            .foregroundColor: UIColor.white
        ]

        // Inline Title のフォント設定（スクロール時）
        let inlineTitleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let inlineTitleDescriptor = inlineTitleFont.fontDescriptor.withDesign(.rounded) ?? inlineTitleFont.fontDescriptor
        scrolledAppearance.titleTextAttributes = [
            .font: UIFont(descriptor: inlineTitleDescriptor, size: 17),
            .foregroundColor: UIColor.white
        ]

        // スクロールしていない時の appearance（完全透明）
        let transparentAppearance = UINavigationBarAppearance()
        transparentAppearance.configureWithTransparentBackground()
        transparentAppearance.backgroundEffect = nil
        transparentAppearance.backgroundColor = .clear
        transparentAppearance.shadowColor = .clear

        // フォント設定をコピー
        transparentAppearance.largeTitleTextAttributes = scrolledAppearance.largeTitleTextAttributes
        transparentAppearance.titleTextAttributes = scrolledAppearance.titleTextAttributes

        UINavigationBar.appearance().standardAppearance = scrolledAppearance  // スクロール時
        UINavigationBar.appearance().scrollEdgeAppearance = transparentAppearance  // スクロール前
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignTokens.SettingsColors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignTokens.SettingsSpacing.sectionSpacing) {
                        soundSelectionSection
                        controlSection
                        volumeSection
                        settingsSection
                        statusSection

                        Spacer(minLength: DesignTokens.SettingsSpacing.bottomSpacer)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                    .padding(.bottom, DesignTokens.SettingsSpacing.screenBottom)
                }
            }
            .navigationTitle("Audio Test")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedTab = .clock
                    }) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedTab = .settings
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                // Audio Test アイコンは非表示（現在のページ）
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage ?? "不明なエラー")
            }
        }
    }

    // MARK: - Sections

    private var soundSelectionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.sectionInnerSpacing) {
            Text("音源選択")
                .font(DesignTokens.SettingsTypography.headline)
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            // Sound type picker (Segmented: Synthesis vs Audio File)
            Picker("音源タイプ", selection: $selectedSound) {
                ForEach(TestSoundType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .tint(DesignTokens.SettingsColors.accent)
            .disabled(audioService.isPlaying)

            Rectangle()
                .fill(DesignTokens.SettingsColors.textSecondary.opacity(0.3))
                .frame(height: 1)

            // Synthesis preset picker (if synthesis type selected)
            if selectedSound == .synthesis {
                Picker("合成プリセット", selection: $selectedSynthesisPreset) {
                    ForEach(NaturalSoundPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .disabled(audioService.isPlaying)

                Text("🎵 \(selectedSynthesisPreset.displayName)")
                    .font(DesignTokens.SettingsTypography.caption)
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            }

            // Audio file picker (if audio file type selected)
            if selectedSound == .audioFile {
                Picker("ファイル", selection: $selectedAudioFile) {
                    ForEach(AudioFilePreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .disabled(audioService.isPlaying)

                Text("📁 \(selectedAudioFile.rawValue).\(selectedAudioFile.fileExtension)")
                    .font(DesignTokens.SettingsTypography.caption)
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            }
        }
        .settingsCardStyle()
    }

    private var controlSection: some View {
        VStack(spacing: DesignTokens.SettingsSpacing.itemSpacing) {
            Button(action: togglePlayback) {
                HStack {
                    Image(systemName: audioService.isPlaying ? "stop.fill" : "play.fill")
                    Text(audioService.isPlaying ? "停止" : "再生")
                }
                .font(DesignTokens.SettingsTypography.headline)
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.SettingsLayout.buttonPadding)
                .background(audioService.isPlaying ? DesignTokens.SettingsColors.danger : DesignTokens.SettingsColors.accent)
                .cornerRadius(DesignTokens.SettingsLayout.buttonCornerRadius)
            }
        }
        .settingsCardStyle()
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.sectionInnerSpacing) {
            HStack {
                Text("音量（端末ボタンで制御）")
                    .font(DesignTokens.SettingsTypography.headline)
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                Spacer()
                Text("\(Int(audioService.systemVolume * 100))%")
                    .font(DesignTokens.SettingsTypography.itemTitle)
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                    .monospacedDigit()
            }

            HStack(spacing: DesignTokens.SettingsSpacing.sectionInnerSpacing) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)

                // Read-only progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.SettingsColors.textSecondary.opacity(0.4))
                            .frame(height: 8)

                        // Filled portion
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.SettingsColors.accent)
                            .frame(width: geometry.size.width * CGFloat(audioService.systemVolume), height: 8)
                    }
                }
                .frame(height: 8)

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            }

            Text("💡 音量は端末のボリュームボタンで調整してください")
                .font(DesignTokens.SettingsTypography.caption)
                .foregroundColor(DesignTokens.SettingsColors.warning)
        }
        .settingsCardStyle()
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.sectionInnerSpacing) {
            Text("設定")
                .font(DesignTokens.SettingsTypography.headline)
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            Text("設定はAudioServiceで管理されます")
                .font(DesignTokens.SettingsTypography.caption)
                .foregroundColor(DesignTokens.SettingsColors.textSecondary)
        }
        .settingsCardStyle()
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.verticalSmall) {
            Text("ステータス")
                .font(DesignTokens.SettingsTypography.headline)
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            HStack {
                Circle()
                    .fill(audioService.isPlaying ? DesignTokens.SettingsColors.success : DesignTokens.SettingsColors.inactive)
                    .frame(width: 10, height: 10)
                Text(audioService.isPlaying ? "再生中" : "停止中")
                    .font(DesignTokens.SettingsTypography.itemTitle)
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
            }

            HStack {
                Text("出力:")
                    .font(DesignTokens.SettingsTypography.caption)
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                Text("\(audioService.outputRoute.icon) \(audioService.outputRoute.displayName)")
                    .font(DesignTokens.SettingsTypography.caption)
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
            }

            if let reason = audioService.pauseReason {
                HStack {
                    Text("停止理由:")
                        .font(DesignTokens.SettingsTypography.caption)
                        .foregroundColor(DesignTokens.SettingsColors.textSecondary)
                    Text(reason.rawValue)
                        .font(DesignTokens.SettingsTypography.caption)
                        .foregroundColor(DesignTokens.SettingsColors.warning)
                }
            }

            // Selected source
            VStack(alignment: .leading, spacing: 4) {
                Text("選択中:")
                    .font(DesignTokens.SettingsTypography.caption)
                    .foregroundColor(DesignTokens.SettingsColors.textSecondary)

                switch selectedSound {
                case .synthesis:
                    Text("🎵 \(selectedSynthesisPreset.displayName)")
                        .font(DesignTokens.SettingsTypography.caption)
                        .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                case .audioFile:
                    Text("📁 \(selectedAudioFile.displayName)")
                        .font(DesignTokens.SettingsTypography.caption)
                        .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                }
            }
        }
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

            // 選択された音源タイプに応じて再生
            switch selectedSound {
            case .synthesis:
                // 合成音源
                try audioService.play(preset: selectedSynthesisPreset)

            case .audioFile:
                // 音源ファイル（TrackPlayer）
                try audioService.playAudioFile(selectedAudioFile)
            }

            // 音量はシステム音量で自動制御される

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
