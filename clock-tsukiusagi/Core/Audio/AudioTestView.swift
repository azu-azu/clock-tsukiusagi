//
//  AudioTestView.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  オーディオシステムのテストビュー
//

import SwiftUI
import AVFoundation

private enum AudioTestColors {
    static let backgroundGradient = LinearGradient(
        colors: [SkyTone.night.gradStart, SkyTone.night.gradEnd],
        startPoint: .top,
        endPoint: .bottom
    )
    static let navBackground = SkyTone.night.gradStart
    static let card = Color.white.opacity(0.1)
    static let accent = Color(hex: "#6CB6FF")
    static let danger = Color(hex: "#FF5C5C")
    static let warning = Color(hex: "#FFC069")
    static let success = Color(hex: "#4ADE80")
    static let inactive = Color.white.opacity(0.25)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
}

private extension View {
    func audioTestCardStyle() -> some View {
        padding()
            .background(AudioTestColors.card)
            .cornerRadius(16)
    }
}

/// テスト用の音源タイプ
enum TestSoundType: String, CaseIterable {
    case synthesis = "🎵 合成音源"
    case audioFile = "📁 音源ファイル"
}

/// オーディオテストビュー
struct AudioTestView: View {
    @EnvironmentObject var audioService: AudioService

    @State private var selectedSound: TestSoundType = .synthesis
    @State private var selectedSynthesisPreset: NaturalSoundPreset = .clickSuppression
    @State private var selectedAudioFile: AudioFilePreset = .testTone

    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                AudioTestColors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        soundSelectionSection
                        controlSection
                        volumeSection
                        settingsSection
                        statusSection
                    }
                    .padding()
                }
            }
            .toolbarBackground(AudioTestColors.navBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle("Audio Test")
            .navigationBarTitleDisplayMode(.large)
            .alert("エラー", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage ?? "不明なエラー")
            }
        }
    }

    // MARK: - Sections

    private var soundSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("音源選択")
                .font(.headline)
                .foregroundColor(AudioTestColors.textPrimary)

            // Sound type picker (Segmented: Synthesis vs Audio File)
            Picker("音源タイプ", selection: $selectedSound) {
                ForEach(TestSoundType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .tint(AudioTestColors.accent)
            .disabled(audioService.isPlaying)

            Rectangle()
                .fill(AudioTestColors.textSecondary.opacity(0.3))
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
                    .font(.caption)
                    .foregroundColor(AudioTestColors.textSecondary)
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
                    .font(.caption)
                    .foregroundColor(AudioTestColors.textSecondary)
            }
        }
        .audioTestCardStyle()
    }

    private var controlSection: some View {
        VStack(spacing: 16) {
            Button(action: togglePlayback) {
                HStack {
                    Image(systemName: audioService.isPlaying ? "stop.fill" : "play.fill")
                    Text(audioService.isPlaying ? "停止" : "再生")
                }
                .font(.title3)
                .foregroundColor(AudioTestColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(audioService.isPlaying ? AudioTestColors.danger : AudioTestColors.accent)
                .cornerRadius(12)
            }
        }
        .audioTestCardStyle()
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("音量（端末ボタンで制御）")
                    .font(.headline)
                    .foregroundColor(AudioTestColors.textPrimary)
                Spacer()
                Text("\(Int(audioService.systemVolume * 100))%")
                    .foregroundColor(AudioTestColors.textSecondary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(AudioTestColors.textSecondary)

                // Read-only progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AudioTestColors.textSecondary.opacity(0.4))
                            .frame(height: 8)

                        // Filled portion
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AudioTestColors.accent)
                            .frame(width: geometry.size.width * CGFloat(audioService.systemVolume), height: 8)
                    }
                }
                .frame(height: 8)

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(AudioTestColors.textSecondary)
            }

            Text("💡 音量は端末のボリュームボタンで調整してください")
                .font(.caption)
                .foregroundColor(AudioTestColors.warning)
        }
        .audioTestCardStyle()
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("設定")
                .font(.headline)
                .foregroundColor(AudioTestColors.textPrimary)

            Text("設定はAudioServiceで管理されます")
                .font(.caption)
                .foregroundColor(AudioTestColors.textSecondary)
        }
        .audioTestCardStyle()
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ステータス")
                .font(.headline)
                .foregroundColor(AudioTestColors.textPrimary)

            HStack {
                Circle()
                    .fill(audioService.isPlaying ? AudioTestColors.success : AudioTestColors.inactive)
                    .frame(width: 10, height: 10)
                Text(audioService.isPlaying ? "再生中" : "停止中")
                    .foregroundColor(AudioTestColors.textSecondary)
            }

            HStack {
                Text("出力:")
                    .font(.caption)
                    .foregroundColor(AudioTestColors.textSecondary)
                Text("\(audioService.outputRoute.icon) \(audioService.outputRoute.displayName)")
                    .font(.caption)
                    .foregroundColor(AudioTestColors.textPrimary)
            }

            if let reason = audioService.pauseReason {
                HStack {
                    Text("停止理由:")
                        .font(.caption)
                        .foregroundColor(AudioTestColors.textSecondary)
                    Text(reason.rawValue)
                        .font(.caption)
                        .foregroundColor(AudioTestColors.warning)
                }
            }

            // Selected source
            VStack(alignment: .leading, spacing: 4) {
                Text("選択中:")
                    .font(.caption)
                    .foregroundColor(AudioTestColors.textSecondary)

                switch selectedSound {
                case .synthesis:
                    Text("🎵 \(selectedSynthesisPreset.displayName)")
                        .font(.caption)
                        .foregroundColor(AudioTestColors.textPrimary)
                case .audioFile:
                    Text("📁 \(selectedAudioFile.displayName)")
                        .font(.caption)
                        .foregroundColor(AudioTestColors.textPrimary)
                }
            }
        }
        .audioTestCardStyle()
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
    AudioTestView()
        .environmentObject(AudioService.shared)
}
