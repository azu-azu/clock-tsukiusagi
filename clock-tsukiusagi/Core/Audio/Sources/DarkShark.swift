//
//  DarkShark.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  黒いサメの影音源（ブラウンノイズ + ランダムLFO）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// 黒いサメの影音源
/// ブラウンノイズとランダムLFOで存在の圧を表現します
public final class DarkShark: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // Suspend/resume control
    private let audioState = AudioState()

    // MARK: - Initialization

    /// DarkSharkを初期化
    /// - Parameters:
    ///   - noiseAmplitude: ノイズ音量
    ///   - lfoFrequency: LFO周波数（ランダムな範囲の中央値）
    ///   - lfoMinimum: LFO最小値
    ///   - lfoMaximum: LFO最大値
    public init(
        noiseAmplitude: Float = 0.4,
        lfoFrequency: Double = 0.115,  // 0.05-0.18の中間値
        lfoMinimum: Double = 0.02,
        lfoMaximum: Double = 0.08
    ) {
        let localNoiseAmplitude = noiseAmplitude
        let _ = lfoFrequency  // Note: Using random frequency instead
        let localLFOMin = lfoMinimum
        let localLFOMax = lfoMaximum
        let twoPi = 2.0 * Double.pi

        // ブラウンノイズジェネレータ
        let noiseGen = NoiseGenerator(type: .brown)

        var lfoPhase: Double = 0.0
        // Random LFO frequency variation
        var currentLFOFreq = Double.random(in: 0.05...0.18)
        var lfoFreqChangeCounter = 0

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

                // Calculate LFO with random frequency
                let lfoValue = sin(lfoPhase)
                let normalizedLFO = (lfoValue + 1.0) / 2.0  // 0.0 to 1.0
                let amplitude = Float(localLFOMin + (localLFOMax - localLFOMin) * normalizedLFO)

                // Apply amplitude modulation
                samples?[frame] = noiseSample * localNoiseAmplitude * amplitude

                // Update LFO phase with current frequency
                lfoPhase += twoPi * currentLFOFreq / 48000.0
                if lfoPhase >= twoPi {
                    lfoPhase -= twoPi
                }

                // Randomly change LFO frequency every ~5 seconds
                lfoFreqChangeCounter += 1
                if lfoFreqChangeCounter >= 240000 {  // 48000 * 5
                    currentLFOFreq = Double.random(in: 0.05...0.18)
                    lfoFreqChangeCounter = 0
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
