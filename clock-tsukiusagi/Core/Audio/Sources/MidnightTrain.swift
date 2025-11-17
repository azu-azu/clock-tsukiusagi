//
//  MidnightTrain.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  夜汽車音源（ブラウンノイズ + 律動LFO）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// 夜汽車音源
/// ブラウンノイズと律動的なLFOでゴトン…ゴトン…を表現します
public final class MidnightTrain: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // Suspend/resume control
    private let audioState = AudioState()

    // MARK: - Initialization

    /// MidnightTrainを初期化
    /// - Parameters:
    ///   - noiseAmplitude: ノイズ音量
    ///   - lfoFrequency: LFO周波数（ガタンゴトンの周期）
    ///   - lfoMinimum: LFO最小値
    ///   - lfoMaximum: LFO最大値
    public init(
        noiseAmplitude: Float = 0.3,
        lfoFrequency: Double = 1.0,  // 1 Hz for rhythmic pattern
        lfoMinimum: Double = 0.03,
        lfoMaximum: Double = 0.12
    ) {
        let localNoiseAmplitude = noiseAmplitude
        let localLFOFreq = lfoFrequency
        let localLFOMin = lfoMinimum
        let localLFOMax = lfoMaximum
        let twoPi = 2.0 * Double.pi

        // ブラウンノイズジェネレータ
        let noiseGen = NoiseGenerator(type: .brown)

        var lfoPhase: Double = 0.0

        // Capture audio state
        let state = audioState

        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // If suspended, output silence
            if state.isSuspended {
                for buffer in abl {
                    memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }

            guard let buffer = abl.first else { return noErr }
            let samples = buffer.mData?.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                // Generate brown noise
                let noiseSample = Float(noiseGen.generate())

                // Calculate LFO (rhythmic pattern for train sound)
                let lfoValue = sin(lfoPhase)
                let normalizedLFO = (lfoValue + 1.0) / 2.0  // 0.0 to 1.0
                let amplitude = Float(localLFOMin + (localLFOMax - localLFOMin) * normalizedLFO)

                // Apply amplitude modulation
                samples?[frame] = noiseSample * localNoiseAmplitude * amplitude

                // Update LFO phase
                lfoPhase += twoPi * localLFOFreq / 48000.0
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
}
