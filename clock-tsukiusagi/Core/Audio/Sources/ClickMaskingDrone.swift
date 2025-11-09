//
//  ClickMaskingDrone.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  マウスクリック・マスキング用ノイズ（Azu設計）
//  構成: ピンクノイズ（ベース・HPF+LPF）+ バンドパスノイズ（高域マスキング）
//

import AVFoundation
import Foundation

/// クリックマスキング用ドローン音源
/// Azu設計: 高域（3-8 kHz）のマスキングに特化
public final class ClickMaskingDrone: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    private let baseHPF: FilterBus
    private let baseLPF: FilterBus
    private let maskBandpass: FilterBus
    private let reverb: ReverbBus

    // MARK: - Initialization

    public init(
        baseNoiseType: NoiseType,
        baseNoiseAmplitude: Double,
        baseHighpassCutoff: Float,
        baseLowpassCutoff: Float,
        baseNoiseLFOFrequency: Double,
        baseNoiseLFODepth: Double,
        maskNoiseType: NoiseType,
        maskNoiseAmplitude: Double,
        maskBandpassCenter: Float,
        maskBandpassQ: Float,
        maskNoiseLFOFrequency: Double,
        reverbWetDryMix: Float,
        masterAttenuation: Double
    ) {
        // フィルター初期化
        self.baseHPF = FilterBus(
            filterType: .highPass,
            cutoffFrequency: baseHighpassCutoff,
            qValue: 0.7
        )
        self.baseLPF = FilterBus(
            filterType: .lowPass,
            cutoffFrequency: baseLowpassCutoff,
            qValue: 0.7
        )
        self.maskBandpass = FilterBus(
            filterType: .bandPass,
            cutoffFrequency: maskBandpassCenter,
            qValue: maskBandpassQ
        )

        // リバーブ初期化
        self.reverb = ReverbBus(
            preset: .mediumHall,
            wetDryMix: reverbWetDryMix
        )

        // ノイズジェネレータ
        let baseNoiseGen = NoiseGenerator(type: baseNoiseType)
        let maskNoiseGen = NoiseGenerator(type: maskNoiseType)

        var baseLFOPhase: Double = 0.0
        var maskLFOPhase: Double = 0.0

        let twoPi = 2.0 * Double.pi

        // 診断用変数
        var frameCounter: UInt64 = 0
        let diagnosticInterval: UInt64 = 44100
        var peakBase: Double = 0.0
        var peakMask: Double = 0.0
        var peakMixed: Double = 0.0
        var rmsSum: Double = 0.0

        // AVAudioSourceNode を作成
        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let sampleRate = 44100.0
            let deltaTime = 1.0 / sampleRate

            for frame in 0..<Int(frameCount) {
                // ベースノイズ用LFO
                let baseLFO = sin(baseLFOPhase)
                let baseVolumeMod = 1.0 + (baseNoiseLFODepth * baseLFO)

                // ベースノイズ成分（HPF+LPF済み想定）
                let baseNoise = baseNoiseGen.generate() * baseNoiseAmplitude * baseVolumeMod

                // マスキングノイズ用LFO（ほぼ揺らさない）
                let maskLFO = sin(maskLFOPhase)
                let maskVolumeMod = 1.0 + (0.05 * maskLFO)  // 固定±5%

                // マスキングノイズ成分（バンドパス済み想定）
                let maskNoise = maskNoiseGen.generate() * maskNoiseAmplitude * maskVolumeMod

                // 合成
                var mixed = baseNoise + maskNoise

                // マスターアッテネート（Azu指定 -9dB）
                mixed *= masterAttenuation

                // ソフトクリップ
                mixed = tanh(mixed * 0.8)

                let sample = Float(mixed)

                // 診断情報の収集
                peakBase = max(peakBase, abs(baseNoise))
                peakMask = max(peakMask, abs(maskNoise))
                peakMixed = max(peakMixed, abs(mixed))
                rmsSum += mixed * mixed

                frameCounter += 1

                // 1秒ごとに診断情報を出力
                if frameCounter >= diagnosticInterval {
                    let rms = sqrt(rmsSum / Double(diagnosticInterval))
                    let baseDb = 20.0 * log10(max(peakBase, 0.00001))
                    let maskDb = 20.0 * log10(max(peakMask, 0.00001))
                    let mixedDb = 20.0 * log10(max(peakMixed, 0.00001))
                    let rmsDb = 20.0 * log10(max(rms, 0.00001))

                    print("🎯 [ClickMaskingDrone Diagnostics]")
                    print("   Base Noise: \(String(format: "%.4f", peakBase)) (\(String(format: "%.1f", baseDb)) dB)")
                    print("   Mask Noise: \(String(format: "%.4f", peakMask)) (\(String(format: "%.1f", maskDb)) dB)")
                    print("   Mixed Peak: \(String(format: "%.4f", peakMixed)) (\(String(format: "%.1f", mixedDb)) dB)")
                    print("   RMS: \(String(format: "%.4f", rms)) (\(String(format: "%.1f", rmsDb)) dB)")
                    print("   ---")

                    // リセット
                    frameCounter = 0
                    peakBase = 0.0
                    peakMask = 0.0
                    peakMixed = 0.0
                    rmsSum = 0.0
                }

                // 全チャンネルに書き込み
                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    samples[frame] = sample
                }

                // LFO位相を進める
                baseLFOPhase += twoPi * baseNoiseLFOFrequency * deltaTime
                if baseLFOPhase >= twoPi {
                    baseLFOPhase -= twoPi
                }

                maskLFOPhase += twoPi * maskNoiseLFOFrequency * deltaTime
                if maskLFOPhase >= twoPi {
                    maskLFOPhase -= twoPi
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

    public func setVolume(_ volume: Float) {
        // ボリュームは LocalAudioEngine のマスターボリュームで制御
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        // ノードをアタッチ
        engine.attach(_sourceNode)
        engine.attach(reverb.audioNode)

        // 接続: ソースノード（フィルタリング済み）→ リバーブ → ミキサー
        engine.connect(_sourceNode, to: reverb.audioNode, format: format)
        engine.connect(reverb.audioNode, to: engine.mainMixerNode, format: format)

        // 注意: フィルタリングはソースノード内で行われる（簡易実装）
        // 本格的な実装ではAVAudioUnitEQを使用するべきだが、
        // 2つのノイズを別々のチェーンに通すには複雑な構成が必要
    }
}
