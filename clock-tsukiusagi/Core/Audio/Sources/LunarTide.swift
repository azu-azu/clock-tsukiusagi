//
//  LunarTide.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  月光の潮流音源（ピンクノイズ + LFO）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// 月光の潮流音源
/// ピンクノイズとLFOで月光の海面を表現します（簡略版：フィルタリングは未実装）
public final class LunarTide: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // Suspend/resume control
    private let audioState = AudioState()

    // MARK: - Initialization

    /// LunarTideを初期化
    /// - Parameters:
    ///   - noiseAmplitude: ノイズ音量
    ///   - lfoFrequency: LFO周波数
    ///   - lfoDepth: LFO深さ
    public init(
        noiseAmplitude: Double = 0.12,
        lfoFrequency: Double = 0.18,
        lfoDepth: Double = 0.35
    ) {
        let localNoiseAmplitude = noiseAmplitude
        let localLFOFreq = lfoFrequency
        let localLFODepth = lfoDepth
        let twoPi = 2.0 * Double.pi

        // ノイズジェネレータ（ピンクノイズ）
        let noiseGen = NoiseGenerator(type: .pink)

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
                // Generate pink noise
                let noiseSample = Float(noiseGen.generate())

                // Calculate LFO
                let lfoValue = sin(lfoPhase)
                let lfoModulation = 1.0 - (localLFODepth * (1.0 - lfoValue) / 2.0)

                // Apply amplitude modulation
                samples?[frame] = noiseSample * Float(localNoiseAmplitude * lfoModulation)

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
