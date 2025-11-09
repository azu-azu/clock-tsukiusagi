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
    case oscillator = "サイン波 (220Hz)"
    case noise = "ホワイトノイズ"
    case oceanWaves = "波の音"
    case cracklingFire = "焚き火"
    case tibetanBowl = "チベタンボウル"
    case windChime = "癒しチャイム"
    case pleasantWarm = "心地よい音（温かい）"
    case pleasantCalm = "心地よい音（穏やか）"
    case pleasantDeep = "心地よい音（深い）"
    case pleasantDrone = "心地よいドローン"
    case ambientFocus = "🎯 Focus（集中）"
    case ambientRelax = "🌿 Relax（リラックス）"
    case ambientSleep = "😴 Sleep（睡眠）"
}

/// オーディオテストビュー
struct AudioTestView: View {
    @State private var audioEngine: LocalAudioEngine?
    @State private var settings = BackgroundAudioToggle()

    @State private var isPlaying = false
    @State private var selectedSound: TestSoundType = .oscillator
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

            Toggle("背景再生", isOn: $settings.isBackgroundAudioEnabled)
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
        case .oscillator:
            // シンプルなサイン波
            let osc = Oscillator(frequency: 220.0, amplitude: 0.3)
            try engine.register(osc)

        case .noise:
            // ホワイトノイズ
            let noise = NoiseSource(amplitude: 0.15)
            try engine.register(noise)

        case .oceanWaves:
            // 波の音（ノイズ + フィルタ + リバーブ）
            // ※本格的な実装は別途必要
            let noise = NoiseSource(amplitude: NaturalSoundPresets.OceanWaves.noiseAmplitude)
            try engine.register(noise)

        case .cracklingFire:
            // 焚き火（バンドパスノイズ + パルス）
            let baseNoise = BandpassNoise(
                centerFrequency: NaturalSoundPresets.CracklingFire.baseCenterFrequency,
                bandwidth: NaturalSoundPresets.CracklingFire.baseBandwidth,
                amplitude: NaturalSoundPresets.CracklingFire.baseAmplitude
            )
            try engine.register(baseNoise)

            let pulse = PulseGenerator(amplitude: NaturalSoundPresets.CracklingFire.pulseAmplitude)
            pulse.minimumDuration = NaturalSoundPresets.CracklingFire.pulseMinDuration
            pulse.maximumDuration = NaturalSoundPresets.CracklingFire.pulseMaxDuration
            pulse.minimumInterval = NaturalSoundPresets.CracklingFire.pulseMinInterval
            pulse.maximumInterval = NaturalSoundPresets.CracklingFire.pulseMaxInterval
            try engine.register(pulse)

        case .tibetanBowl:
            // チベタンボウル（複数オシレータ + 倍音）
            let bowl = MultiOscillator.tibetanBowl(
                fundamentalFrequency: NaturalSoundPresets.TibetanBowl.fundamentalFrequency
            )
            try engine.register(bowl)

        case .windChime:
            // 癒しチャイム（シンプル版 - 単一周波数）
            // ※本格的な実装（ランダムトリガー + エンベロープ）は別途必要
            let freq = NaturalSoundPresets.WindChime.frequencies.randomElement() ?? 1320.0
            let osc = Oscillator(frequency: freq, amplitude: NaturalSoundPresets.WindChime.amplitude)
            try engine.register(osc)

        case .pleasantWarm:
            // 心地よい音（温かい）- デチューンオシレータ
            let warmSound = DetunedOscillator(
                baseFrequency: NaturalSoundPresets.PleasantWarm.baseFrequency,
                detuneAmount: NaturalSoundPresets.PleasantWarm.detuneAmount,
                oscillatorCount: NaturalSoundPresets.PleasantWarm.oscillatorCount,
                amplitude: NaturalSoundPresets.PleasantWarm.amplitude,
                noiseLevel: NaturalSoundPresets.PleasantWarm.noiseLevel
            )
            try engine.register(warmSound)

        case .pleasantCalm:
            // 心地よい音（穏やか）- デチューンオシレータ
            let calmSound = DetunedOscillator(
                baseFrequency: NaturalSoundPresets.PleasantCalm.baseFrequency,
                detuneAmount: NaturalSoundPresets.PleasantCalm.detuneAmount,
                oscillatorCount: NaturalSoundPresets.PleasantCalm.oscillatorCount,
                amplitude: NaturalSoundPresets.PleasantCalm.amplitude,
                noiseLevel: NaturalSoundPresets.PleasantCalm.noiseLevel
            )
            try engine.register(calmSound)

        case .pleasantDeep:
            // 心地よい音（深い）- デチューンオシレータ
            let deepSound = DetunedOscillator(
                baseFrequency: NaturalSoundPresets.PleasantDeep.baseFrequency,
                detuneAmount: NaturalSoundPresets.PleasantDeep.detuneAmount,
                oscillatorCount: NaturalSoundPresets.PleasantDeep.oscillatorCount,
                amplitude: NaturalSoundPresets.PleasantDeep.amplitude,
                noiseLevel: NaturalSoundPresets.PleasantDeep.noiseLevel
            )
            try engine.register(deepSound)

        case .pleasantDrone:
            // 心地よいドローン - 和音 + LFO変調
            let droneSound = PleasantDrone(
                rootFrequency: NaturalSoundPresets.PleasantDrone.rootFrequency,
                chordType: NaturalSoundPresets.PleasantDrone.chordType,
                amplitude: NaturalSoundPresets.PleasantDrone.amplitude,
                amplitudeLFOFrequency: NaturalSoundPresets.PleasantDrone.amplitudeLFOFrequency,
                pitchLFOFrequency: NaturalSoundPresets.PleasantDrone.pitchLFOFrequency,
                pitchLFODepth: NaturalSoundPresets.PleasantDrone.pitchLFODepth,
                noiseLevel: NaturalSoundPresets.PleasantDrone.noiseLevel
            )
            try engine.register(droneSound)

        case .ambientFocus:
            // Endel風 Focus - ピンクノイズ + 高め周波数 + 速めLFO
            let focusSound = AmbientDrone(
                noiseType: NaturalSoundPresets.AmbientFocus.noiseType,
                noiseAmplitude: NaturalSoundPresets.AmbientFocus.noiseAmplitude,
                sineFrequencies: NaturalSoundPresets.AmbientFocus.sineFrequencies,
                sineAmplitude: NaturalSoundPresets.AmbientFocus.sineAmplitude,
                detuneAmount: NaturalSoundPresets.AmbientFocus.detuneAmount,
                lfoAmplitudeFrequency: NaturalSoundPresets.AmbientFocus.lfoAmplitudeFrequency,
                lfoAmplitudeDepth: NaturalSoundPresets.AmbientFocus.lfoAmplitudeDepth
            )
            try engine.register(focusSound)

        case .ambientRelax:
            // Endel風 Relax - ホワイトノイズ + 中域 + ゆっくりLFO
            let relaxSound = AmbientDrone(
                noiseType: NaturalSoundPresets.AmbientRelax.noiseType,
                noiseAmplitude: NaturalSoundPresets.AmbientRelax.noiseAmplitude,
                sineFrequencies: NaturalSoundPresets.AmbientRelax.sineFrequencies,
                sineAmplitude: NaturalSoundPresets.AmbientRelax.sineAmplitude,
                detuneAmount: NaturalSoundPresets.AmbientRelax.detuneAmount,
                lfoAmplitudeFrequency: NaturalSoundPresets.AmbientRelax.lfoAmplitudeFrequency,
                lfoAmplitudeDepth: NaturalSoundPresets.AmbientRelax.lfoAmplitudeDepth
            )
            try engine.register(relaxSound)

        case .ambientSleep:
            // Endel風 Sleep - ブラウンノイズ + 低域 + 超ゆっくりLFO
            let sleepSound = AmbientDrone(
                noiseType: NaturalSoundPresets.AmbientSleep.noiseType,
                noiseAmplitude: NaturalSoundPresets.AmbientSleep.noiseAmplitude,
                sineFrequencies: NaturalSoundPresets.AmbientSleep.sineFrequencies,
                sineAmplitude: NaturalSoundPresets.AmbientSleep.sineAmplitude,
                detuneAmount: NaturalSoundPresets.AmbientSleep.detuneAmount,
                lfoAmplitudeFrequency: NaturalSoundPresets.AmbientSleep.lfoAmplitudeFrequency,
                lfoAmplitudeDepth: NaturalSoundPresets.AmbientSleep.lfoAmplitudeDepth
            )
            try engine.register(sleepSound)
        }
    }
}

#Preview {
    AudioTestView()
}
