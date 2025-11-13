//
//  TibetanBowl.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-13.
//  チベタンボウル風音源（倍音 + ビブラート）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// チベタンボウル風音源
/// 倍音構造とビブラートで深みのある音を生成します
public final class TibetanBowl: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // Suspend/resume control
    private let audioState = AudioState()

    // MARK: - Initialization

    /// TibetanBowlを初期化
    /// - Parameters:
    ///   - fundamentalFrequency: 基音の周波数
    ///   - amplitude: 音量
    ///   - harmonics: 倍音構造
    ///   - vibratoFrequency: ビブラート周波数
    ///   - vibratoDepth: ビブラート深さ
    public init(
        fundamentalFrequency: Double,
        amplitude: Double = 0.2,
        harmonics: [Harmonic],
        vibratoFrequency: Double = 5.0,
        vibratoDepth: Double = 0.02
    ) {
        let localFundamental = fundamentalFrequency
        let localAmplitude = amplitude
        let localHarmonics = harmonics
        let localVibratoFreq = vibratoFrequency
        let localVibratoDepth = vibratoDepth
        let twoPi = 2.0 * Double.pi

        // 各倍音の位相を初期化
        var harmonicPhases: [Double] = []
        for _ in localHarmonics {
            harmonicPhases.append(0.0)
        }

        var vibratoPhase: Double = 0.0

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
                // ビブラート（周波数変調）
                let vibratoLFO = sin(vibratoPhase)
                let pitchModulation = vibratoLFO * localVibratoDepth

                // 全倍音を合成
                var mixedSample: Double = 0.0

                for (i, harmonic) in localHarmonics.enumerated() {
                    let harmonicFreq = localFundamental * harmonic.multiplier
                    let modulatedFreq = harmonicFreq * (1.0 + pitchModulation)

                    let sineSample = sin(harmonicPhases[i])
                    mixedSample += sineSample * harmonic.amplitude

                    // 位相を進める
                    let phaseIncrement = twoPi * modulatedFreq / sampleRate
                    harmonicPhases[i] += phaseIncrement
                    if harmonicPhases[i] >= twoPi {
                        harmonicPhases[i] -= twoPi
                    }
                }

                // 平均化
                if !localHarmonics.isEmpty {
                    mixedSample /= Double(localHarmonics.count)
                }

                // 音量を適用
                let finalSample = Float(mixedSample * localAmplitude)

                // 全チャンネルに書き込み
                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    samples[frame] = finalSample
                }

                // ビブラート位相を進める
                vibratoPhase += twoPi * localVibratoFreq * deltaTime
                if vibratoPhase >= twoPi {
                    vibratoPhase -= twoPi
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
        print("🎵 [TibetanBowl] Suspended (output silence)")
    }

    public func resume() {
        audioState.isSuspended = false
        print("🎵 [TibetanBowl] Resumed (output active)")
    }

    public func setVolume(_ volume: Float) {
        // ボリュームは LocalAudioEngine のマスターボリュームで制御
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}
