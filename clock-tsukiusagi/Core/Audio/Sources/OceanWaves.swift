//
//  OceanWaves.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-13.
//  波の音（ローパスフィルタ付きノイズ + LFO）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// 波の音音源
/// ノイズとLFOで波の強弱を表現します
public final class OceanWaves: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // Suspend/resume control
    private let audioState = AudioState()

    // MARK: - Initialization

    /// OceanWavesを初期化
    /// - Parameters:
    ///   - noiseAmplitude: ノイズ音量
    ///   - lfoFrequency: LFO周波数（波の強弱周期）
    ///   - lfoDepth: LFO深さ
    ///   - lfoMinimum: LFO最小値
    ///   - lfoMaximum: LFO最大値
    public init(
        noiseAmplitude: Float = 0.3,
        lfoFrequency: Double = 0.2,
        lfoDepth: Double = 0.8,
        lfoMinimum: Double = 0.1,
        lfoMaximum: Double = 0.6
    ) {
        let localNoiseAmplitude = noiseAmplitude
        let localLFOFreq = lfoFrequency
        let _ = lfoDepth  // Note: depth is controlled by lfoMinimum/lfoMaximum range
        let localLFOMin = lfoMinimum
        let localLFOMax = lfoMaximum
        let twoPi = 2.0 * Double.pi

        // ノイズジェネレータ（ホワイトノイズ）
        let noiseGen = NoiseGenerator(type: .white)

        var lfoPhase: Double = 0.0

        // Capture audio state
        let state = audioState

        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

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

            let sampleRate = 44100.0
            let deltaTime = 1.0 / sampleRate

            for frame in 0..<Int(frameCount) {
                // LFOによる音量変調（波の強弱）
                let lfoValue = sin(lfoPhase)
                // 0.0〜1.0の範囲に正規化
                let normalizedLFO = (lfoValue + 1.0) / 2.0
                // lfoMinimum〜lfoMaximumの範囲にマッピング
                let volumeMod = localLFOMin + (normalizedLFO * (localLFOMax - localLFOMin))

                // ノイズを生成
                let noise = noiseGen.generate() * Double(localNoiseAmplitude)

                // 音量変調を適用
                let finalSample = Float(noise * volumeMod)

                // 全チャンネルに書き込み
                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    samples[frame] = finalSample
                }

                // LFO位相を進める
                lfoPhase += twoPi * localLFOFreq * deltaTime
                if lfoPhase >= twoPi {
                    lfoPhase -= twoPi
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
    }

    public func resume() {
        audioState.isSuspended = false
    }

    public func setVolume(_ volume: Float) {
        // ボリュームは LocalAudioEngine のマスターボリュームで制御
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}
