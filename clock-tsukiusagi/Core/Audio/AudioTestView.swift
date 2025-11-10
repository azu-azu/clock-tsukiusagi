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
    case comfortRelax = "🌙 Comfort Relax"
}

/// オーディオテストビュー
struct AudioTestView: View {
    @State private var audioEngine: LocalAudioEngine?
    @State private var settings = BackgroundAudioToggle()

    @State private var isPlaying = false
    @State private var selectedSound: TestSoundType = .comfortRelax
    @State private var masterVolume: Float = 0.5

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
            .disabled(isPlaying)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var controlSection: some View {
        VStack(spacing: 16) {
            Button(action: togglePlayback) {
                HStack {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    Text(isPlaying ? "停止" : "再生")
                }
                .font(.title3)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isPlaying ? Color.red : Color.blue)
                .cornerRadius(12)
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("音量")
                    .font(.headline)
                Spacer()
                Text("\(Int(masterVolume * 100))%")
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)

                Slider(value: $masterVolume, in: 0...1)
                    .onChange(of: masterVolume) { _, newValue in
                        audioEngine?.setMasterVolume(newValue)
                    }

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("設定")
                .font(.headline)

            Toggle("バックグラウンド再生", isOn: $settings.isBackgroundAudioEnabled)
            Toggle("中断後の自動再開", isOn: $settings.isAutoResumeEnabled)
            Toggle("イヤホン抜けで自動停止", isOn: $settings.stopOnHeadphoneDisconnect)
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
                    .fill(isPlaying ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(isPlaying ? "再生中" : "停止中")
                    .foregroundColor(.secondary)
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
        if isPlaying {
            stopAudio()
        } else {
            playAudio()
        }
    }

    private func playAudio() {
        do {
            print("AudioTestView: Starting audio playback...")
            fflush(stdout)

            // 新しいエンジンを作成
            let sessionManager = AudioSessionManager()
            let engine = LocalAudioEngine(sessionManager: sessionManager, settings: settings)

            print("AudioTestView: Configuring audio session...")
            fflush(stdout)
            // セッションを設定
            try engine.configure()

            print("AudioTestView: configure() returned successfully!")
            fflush(stdout)

            print("AudioTestView: Registering sound source: \(selectedSound.rawValue)")
            fflush(stdout)
            // 選択された音源を登録
            try registerSound(to: engine)

            print("AudioTestView: registerSound() completed!")
            fflush(stdout)

            // 音量を設定
            engine.setMasterVolume(masterVolume)

            print("AudioTestView: Starting audio engine...")
            // エンジンを開始
            try engine.start()

            audioEngine = engine
            isPlaying = true

            // 実機の音量を確認
            let deviceVolume = AVAudioSession.sharedInstance().outputVolume
            print("AudioTestView: Device volume: \(deviceVolume)")
            print("AudioTestView: Master volume: \(masterVolume)")

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
        audioEngine?.stop()
        audioEngine = nil
        isPlaying = false
    }

    private func registerSound(to engine: LocalAudioEngine) throws {
        switch selectedSound {
        case .comfortRelax:
            // Comfort Pack Relax - ピンクノイズ + 低周波ドローン + 呼吸LFO
            let relaxSound = ComfortPackDrone(
                noiseType: NaturalSoundPresets.ComfortRelax.noiseType,
                noiseAmplitude: NaturalSoundPresets.ComfortRelax.noiseAmplitude,
                noiseLowpassCutoff: NaturalSoundPresets.ComfortRelax.noiseLowpassCutoff,
                noiseLFOFrequency: NaturalSoundPresets.ComfortRelax.noiseLFOFrequency,
                noiseLFODepth: NaturalSoundPresets.ComfortRelax.noiseLFODepth,
                droneFrequencies: NaturalSoundPresets.ComfortRelax.droneFrequencies,
                droneAmplitude: NaturalSoundPresets.ComfortRelax.droneAmplitude,
                droneDetuneCents: NaturalSoundPresets.ComfortRelax.droneDetuneCents,
                droneLFOFrequency: NaturalSoundPresets.ComfortRelax.droneLFOFrequency,
                reverbWetDryMix: NaturalSoundPresets.ComfortRelax.reverbWetDryMix
            )
            try engine.register(relaxSound)
        }
    }
}

#Preview {
    AudioTestView()
}
