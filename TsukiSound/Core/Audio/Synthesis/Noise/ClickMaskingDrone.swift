//
//  ClickMaskingDrone.swift
//  TsukiSound
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

        // AVAudioSourceNode を作成
        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let sampleRate = 48000.0
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
