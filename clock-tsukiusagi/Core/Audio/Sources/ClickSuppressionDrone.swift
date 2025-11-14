//
//  ClickSuppressionDrone.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  クリック音防止ドローン（ノイズ床 + やわらかドローン + フィルター + リバーブ）
//  Azu & Fujiko設計: たった3レイヤ＋ゆるい揺らぎで"心地よい"を実現
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
    var diagnosticsEnabled = true
}

/// クリック音防止ドローン音源
/// 構成: ノイズ床 + やわらかドローン + 薄い空間
public final class ClickSuppressionDrone: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    private let lowpassFilter: FilterBus
    private let highpassFilter: FilterBus?
    private let reverb: ReverbBus

    // Suspend/resume control (shared with render callback)
    private let audioState = AudioState()

    // MARK: - Initialization

    /// クリック音防止ドローンを初期化
    /// - Parameters:
    ///   - noiseType: ノイズタイプ
    ///   - noiseAmplitude: ノイズ音量
    ///   - noiseLowpassCutoff: ノイズ用LPFカットオフ周波数
    ///   - noiseLFOFrequency: ノイズ用LFO周波数
    ///   - noiseLFODepth: ノイズ用LFO深さ
    ///   - droneFrequencies: ドローンの周波数配列
    ///   - droneAmplitude: ドローンの音量
    ///   - droneDetuneCents: ドローンのデチューン量（cents）
    ///   - droneLFOFrequency: ドローン用LFO周波数
    ///   - reverbWetDryMix: リバーブのWet/Dry（0〜100）
    ///   - highpassCutoff: HPFカットオフ周波数（nilの場合はHPFなし）
    public init(
        noiseType: NoiseType,
        noiseAmplitude: Double,
        noiseLowpassCutoff: Float,
        noiseLFOFrequency: Double,
        noiseLFODepth: Double,
        droneFrequencies: [Double],
        droneAmplitude: Double,
        droneDetuneCents: Double,
        droneLFOFrequency: Double,
        reverbWetDryMix: Float,
        highpassCutoff: Float? = nil
    ) {
        // フィルター初期化
        self.lowpassFilter = FilterBus(
            filterType: .lowPass,
            cutoffFrequency: noiseLowpassCutoff,
            qValue: 0.7
        )

        // HPFはSleep用のみ
        if let hpfCutoff = highpassCutoff {
            self.highpassFilter = FilterBus(
                filterType: .highPass,
                cutoffFrequency: hpfCutoff,
                qValue: 0.7
            )
        } else {
            self.highpassFilter = nil
        }

        // リバーブ初期化（Medium Hall）
        self.reverb = ReverbBus(
            preset: .mediumHall,
            wetDryMix: reverbWetDryMix
        )

        // ノイズジェネレータ
        let noiseGen = NoiseGenerator(type: noiseType)

        // ドローン用の周波数とデチューンを計算
        var droneFreqs: [Double] = []
        var dronePhases: [Double] = []
        let twoPi = 2.0 * Double.pi

        // cents を周波数比に変換する関数
        let centsToRatio: (Double) -> Double = { cents in
            pow(2.0, cents / 1200.0)
        }

        for baseFreq in droneFrequencies {
            // デチューン（±droneDetuneCents）
            let detuneCents = Double.random(in: -droneDetuneCents...droneDetuneCents)
            let detuneRatio = centsToRatio(detuneCents)
            droneFreqs.append(baseFreq * detuneRatio)
            dronePhases.append(Double.random(in: 0..<twoPi))
        }

        var noiseLFOPhase: Double = 0.0
        var droneLFOPhase: Double = 0.0

        let localNoiseAmplitude = noiseAmplitude
        let localNoiseLFOFrequency = noiseLFOFrequency
        let localNoiseLFODepth = noiseLFODepth

        let localDroneAmplitude = droneAmplitude
        let localDroneLFOFrequency = droneLFOFrequency

        // 診断用変数
        var frameCounter: UInt64 = 0
        let diagnosticInterval: UInt64 = 44100  // 1秒ごと
        var peakNoise: Double = 0.0
        var peakDrone: Double = 0.0
        var peakMixed: Double = 0.0
        var rmsSum: Double = 0.0
        var clippingCount: Int = 0

        // Capture audio state for suspend/resume control
        let state = audioState

        // AVAudioSourceNode を作成
        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let sampleRate = 44100.0
            let deltaTime = 1.0 / sampleRate

            // If suspended, output silence
            if state.isSuspended {
                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    for frame in 0..<Int(frameCount) {
                        samples[frame] = 0.0
                    }
                }
                return noErr
            }

            for frame in 0..<Int(frameCount) {
                // ノイズ用LFO（音量変調）- Azu式：オフセット付き
                let noiseLFO = sin(noiseLFOPhase)
                let noiseVolumeMod = 1.0 + (localNoiseLFODepth * noiseLFO)

                // ノイズ成分
                let noise = noiseGen.generate() * localNoiseAmplitude * noiseVolumeMod

                // ドローン用LFO（音量変調 - 呼吸感）- Azu式
                let droneLFO = sin(droneLFOPhase)
                let droneVolumeMod = 1.0 + (0.15 * droneLFO)

                // ドローン成分（複数周波数の合成）
                var droneSum: Double = 0.0
                for i in 0..<dronePhases.count {
                    let sineSample = sin(dronePhases[i])
                    droneSum += sineSample  // ✅ Pure sine wave, no distortion

                    // 位相を進める
                    let phaseIncrement = twoPi * droneFreqs[i] / sampleRate
                    dronePhases[i] += phaseIncrement
                    if dronePhases[i] >= twoPi {
                        dronePhases[i] -= twoPi
                    }
                }
                droneSum *= localDroneAmplitude * droneVolumeMod

                // 合成（ノイズ床 + ドローン）
                let mixed = noise + droneSum  // ✅ No attenuation, no clipping

                let sample = Float(mixed)

                // 診断情報の収集
                peakNoise = max(peakNoise, abs(noise))
                peakDrone = max(peakDrone, abs(droneSum))
                peakMixed = max(peakMixed, abs(mixed))
                rmsSum += mixed * mixed

                // クリッピング検出（ソフトクリップ前の値で）
                let preClip = noise + droneSum
                if abs(preClip * 0.3) > 1.0 {
                    clippingCount += 1
                }

                frameCounter += 1

                // 1秒ごとに診断情報を出力（diagnostics有効時のみ）
                if frameCounter >= diagnosticInterval {
                    if state.diagnosticsEnabled {
                        let rms = sqrt(rmsSum / Double(diagnosticInterval))
                        let noiseDb = 20.0 * log10(max(peakNoise, 0.00001))
                        let droneDb = 20.0 * log10(max(peakDrone, 0.00001))
                        let mixedDb = 20.0 * log10(max(peakMixed, 0.00001))
                        let rmsDb = 20.0 * log10(max(rms, 0.00001))

                        print("   Noise: \(String(format: "%.4f", peakNoise)) (\(String(format: "%.1f", noiseDb)) dB)")
                        print("   Drone: \(String(format: "%.4f", peakDrone)) (\(String(format: "%.1f", droneDb)) dB)")
                        print("   Mixed Peak: \(String(format: "%.4f", peakMixed)) (\(String(format: "%.1f", mixedDb)) dB)")
                        print("   RMS: \(String(format: "%.4f", rms)) (\(String(format: "%.1f", rmsDb)) dB)")
                        if clippingCount > 0 {
                            print("   ⚠️  Clipping: \(clippingCount) samples (\(String(format: "%.1f", Double(clippingCount) / Double(diagnosticInterval) * 100))%)")
                        } else {
                            print("   ✅ No clipping")
                        }
                        print("   ---")
                    }

                    // リセット
                    frameCounter = 0
                    peakNoise = 0.0
                    peakDrone = 0.0
                    peakMixed = 0.0
                    rmsSum = 0.0
                    clippingCount = 0
                }

                // 全チャンネルに書き込み
                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    samples[frame] = sample
                }

                // LFO位相を進める
                noiseLFOPhase += twoPi * localNoiseLFOFrequency * deltaTime
                if noiseLFOPhase >= twoPi {
                    noiseLFOPhase -= twoPi
                }

                droneLFOPhase += twoPi * localDroneLFOFrequency * deltaTime
                if droneLFOPhase >= twoPi {
                    droneLFOPhase -= twoPi
                }
            }

            return noErr
        }
    }

    // MARK: - AudioSource Protocol

    public func start() throws {
        // ソースノードは自動的に動作
    }

    public func stop() {
        // ソースノードは自動的に停止
    }

    public func suspend() {
        audioState.isSuspended = true
        audioState.diagnosticsEnabled = false
    }

    public func resume() {
        audioState.isSuspended = false
        audioState.diagnosticsEnabled = true
    }

    public func setVolume(_ volume: Float) {
        // ボリュームは LocalAudioEngine のマスターボリュームで制御
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        // ノードをアタッチ
        engine.attach(_sourceNode)
        engine.attach(lowpassFilter.audioNode)
        engine.attach(reverb.audioNode)

        if let hpf = highpassFilter {
            engine.attach(hpf.audioNode)
        }

        // 接続: ソースノード → LPF → (HPF) → リバーブ → メインミキサー
        if let hpf = highpassFilter {
            // Sleep用（HPFあり）
            engine.connect(_sourceNode, to: lowpassFilter.audioNode, format: format)
            engine.connect(lowpassFilter.audioNode, to: hpf.audioNode, format: format)
            engine.connect(hpf.audioNode, to: reverb.audioNode, format: format)
            engine.connect(reverb.audioNode, to: engine.mainMixerNode, format: format)
        } else {
            // Focus/Relax用（HPFなし）
            engine.connect(_sourceNode, to: lowpassFilter.audioNode, format: format)
            engine.connect(lowpassFilter.audioNode, to: reverb.audioNode, format: format)
            engine.connect(reverb.audioNode, to: engine.mainMixerNode, format: format)
        }
    }
}
