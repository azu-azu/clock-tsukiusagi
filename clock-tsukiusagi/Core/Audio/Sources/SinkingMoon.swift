//
//  SinkingMoon.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  沈む月音源（柔らかいサイン波 + 超低速フェード）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// 沈む月音源
/// 柔らかいサイン波（432Hz）を超低速フェードして静けさの消失を表現します
public final class SinkingMoon: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // Suspend/resume control
    private let audioState = AudioState()

    // MARK: - Initialization

    /// SinkingMoonを初期化
    /// - Parameters:
    ///   - sineFrequency: サイン波の周波数（デフォルト: 432Hz）
    ///   - sineAmplitude: 基本音量
    ///   - lfoFrequency: LFO周波数（超低速フェード）
    ///   - lfoDepth: LFO深さ
    public init(
        sineFrequency: Double = 432.0,
        sineAmplitude: Double = 0.06,
        lfoFrequency: Double = 0.04,
        lfoDepth: Double = 0.25
    ) {
        let localFrequency = sineFrequency
        let localAmplitude = sineAmplitude
        let localLFOFreq = lfoFrequency
        let localLFODepth = lfoDepth
        let twoPi = 2.0 * Double.pi
        let sampleRate: Double = 48000.0

        var sinePhase: Double = 0.0
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
                // Generate sine wave
                let sineSample = sin(sinePhase)

                // Calculate LFO (very slow fade)
                let lfoValue = sin(lfoPhase)
                let lfoModulation = 1.0 - (localLFODepth * (1.0 - lfoValue) / 2.0)

                // Apply amplitude modulation
                samples?[frame] = Float(sineSample * localAmplitude * lfoModulation)

                // Update phases
                sinePhase += twoPi * localFrequency / sampleRate
                if sinePhase >= twoPi {
                    sinePhase -= twoPi
                }

                lfoPhase += twoPi * localLFOFreq / sampleRate
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
