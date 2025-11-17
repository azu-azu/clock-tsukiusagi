//
//  WindChime.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-13.
//  癒しのチャイム音源（ランダムトリガー + エンベロープ）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// 癒しのチャイム音源
/// ペンタトニックスケールの音をランダムなタイミングで鳴らします
public final class WindChime: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // Suspend/resume control
    private let audioState = AudioState()

    // MARK: - Initialization

    /// WindChimeを初期化
    /// - Parameters:
    ///   - frequencies: ペンタトニックスケールの周波数配列
    ///   - amplitude: 音量
    ///   - minInterval: 最小間隔（秒）
    ///   - maxInterval: 最大間隔（秒）
    ///   - attackTime: アタック時間
    ///   - decayTime: ディケイ時間
    ///   - sustainLevel: サステインレベル
    ///   - releaseTime: リリース時間
    public init(
        frequencies: [Double],
        amplitude: Double = 0.3,
        minInterval: Double = 2.0,
        maxInterval: Double = 8.0,
        attackTime: Double = 0.01,
        decayTime: Double = 3.0,
        sustainLevel: Double = 0.0,
        releaseTime: Double = 1.0
    ) {
        let localFrequencies = frequencies
        let localAmplitude = amplitude
        let twoPi = 2.0 * Double.pi

        // 各周波数用の位相とエンベロープ
        class ChimeVoice {
            var phase: Double = 0.0
            var envelope: Double = 0.0
            var envelopeStage: EnvelopeStage = .idle
            var elapsedTime: Double = 0.0
            let frequency: Double

            init(frequency: Double) {
                self.frequency = frequency
            }

            func trigger() {
                envelopeStage = .attack
                elapsedTime = 0.0
                phase = 0.0
            }

            func updateEnvelope(deltaTime: Double, attackTime: Double, decayTime: Double,
                               sustainLevel: Double, releaseTime: Double) -> Double {
                elapsedTime += deltaTime

                switch envelopeStage {
                case .idle:
                    envelope = 0.0

                case .attack:
                    let progress = min(elapsedTime / attackTime, 1.0)
                    envelope = progress
                    if progress >= 1.0 {
                        envelopeStage = .decay
                        elapsedTime = 0.0
                    }

                case .decay:
                    let progress = min(elapsedTime / decayTime, 1.0)
                    envelope = 1.0 - ((1.0 - sustainLevel) * progress)
                    if progress >= 1.0 {
                        envelopeStage = .sustain
                        elapsedTime = 0.0
                    }

                case .sustain:
                    envelope = sustainLevel

                case .release:
                    let progress = min(elapsedTime / releaseTime, 1.0)
                    envelope = sustainLevel * (1.0 - progress)
                    if progress >= 1.0 {
                        envelopeStage = .idle
                        elapsedTime = 0.0
                    }
                }

                return envelope
            }
        }

        // 各周波数用のボイスを作成
        var voices: [ChimeVoice] = []
        for freq in localFrequencies {
            voices.append(ChimeVoice(frequency: freq))
        }

        // ランダムトリガー用の状態
        var triggerElapsed: Double = 0.0
        var nextTriggerTime = Double.random(in: minInterval...maxInterval)

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

            let sampleRate = 48000.0
            let deltaTime = 1.0 / sampleRate

            for frame in 0..<Int(frameCount) {
                // ランダムトリガーの更新
                triggerElapsed += deltaTime
                if triggerElapsed >= nextTriggerTime {
                    // ランダムに周波数を選んでトリガー
                    let randomIndex = Int.random(in: 0..<voices.count)
                    voices[randomIndex].trigger()

                    triggerElapsed = 0.0
                    nextTriggerTime = Double.random(in: minInterval...maxInterval)
                }

                // 全ボイスを合成
                var mixedSample: Double = 0.0

                for voice in voices {
                    // エンベロープを更新
                    let env = voice.updateEnvelope(
                        deltaTime: deltaTime,
                        attackTime: attackTime,
                        decayTime: decayTime,
                        sustainLevel: sustainLevel,
                        releaseTime: releaseTime
                    )

                    if env > 0.001 {
                        // サイン波を生成
                        let sineSample = sin(voice.phase)
                        mixedSample += sineSample * env

                        // 位相を進める
                        let phaseIncrement = twoPi * voice.frequency / sampleRate
                        voice.phase += phaseIncrement
                        if voice.phase >= twoPi {
                            voice.phase -= twoPi
                        }
                    }
                }

                // 音量を適用
                let finalSample = Float(mixedSample * localAmplitude)

                // 全チャンネルに書き込み
                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    samples[frame] = finalSample
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
