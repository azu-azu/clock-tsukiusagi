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
    case clickSuppression = "🔇 クリック音防止"
}

/// オーディオテストビュー
struct AudioTestView: View {
    @EnvironmentObject var audioService: AudioService

    @State private var selectedSound: TestSoundType = .clickSuppression

    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 音源選択
                    soundSelectionSection

                    // コントロール
                    controlSection

                    // 音量調整
                    volumeSection

                    // 設定
                    settingsSection

                    // ステータス
                    statusSection
                }
                .padding()
            }
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

            Picker("音源", selection: $selectedSound) {
                ForEach(TestSoundType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .disabled(audioService.isPlaying)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var controlSection: some View {
        VStack(spacing: 16) {
            Button(action: togglePlayback) {
                HStack {
                    Image(systemName: audioService.isPlaying ? "stop.fill" : "play.fill")
                    Text(audioService.isPlaying ? "停止" : "再生")
                }
                .font(.title3)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(audioService.isPlaying ? Color.red : Color.blue)
                .cornerRadius(12)
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("音量（端末ボタンで制御）")
                    .font(.headline)
                Spacer()
                Text("\(Int(audioService.systemVolume * 100))%")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)

                // Read-only progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)

                        // Filled portion
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(audioService.systemVolume), height: 8)
                    }
                }
                .frame(height: 8)

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.secondary)
            }

            Text("💡 音量は端末のボリュームボタンで調整してください")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("設定")
                .font(.headline)

            Text("設定はAudioServiceで管理されます")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ステータス")
                .font(.headline)

            HStack {
                Circle()
                    .fill(audioService.isPlaying ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(audioService.isPlaying ? "再生中" : "停止中")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("出力:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(audioService.outputRoute.icon) \(audioService.outputRoute.displayName)")
                    .font(.caption)
            }

            if let reason = audioService.pauseReason {
                HStack {
                    Text("停止理由:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(reason.rawValue)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Text("選択中: \(selectedSound.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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
            print("AudioTestView: Starting audio playback via AudioService...")

            // AudioServiceに再生を依頼（プリセットを指定）
            try audioService.play(preset: .clickSuppression)

            // 音量はシステム音量で自動制御される

            print("AudioTestView: Audio playback started successfully")

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
