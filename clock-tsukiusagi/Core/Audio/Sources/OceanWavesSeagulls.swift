//
//  OceanWavesSeagulls.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-13.
//  波の音 + 海鳥（ノイズ + LFO + ランダムチャープ）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class OceanWavesSeagullsState {
    var isSuspended = false
}

private final class BirdChirpVoice {
    var isActive = false
    var phase: Double = 0.0
    var elapsed: Double = 0.0
    var duration: Double = 0.0
    var frequency: Double = 0.0
    var amplitude: Double = 0.0

    func trigger(frequency: Double, duration: Double, amplitude: Double) {
        self.frequency = frequency
        self.duration = duration
        self.amplitude = amplitude
        self.phase = 0.0
        self.elapsed = 0.0
        self.isActive = true
    }

    func renderSample(deltaTime: Double, sampleRate: Double) -> Double {
        guard isActive else { return 0.0 }

        elapsed += deltaTime
        if elapsed >= duration {
            isActive = false
            return 0.0
        }

        // Smooth fade in/out envelope
        let progress = elapsed / duration
        let envelope = sin(progress * Double.pi)

        let sample = sin(phase) * envelope * amplitude
        phase += 2.0 * Double.pi * frequency / sampleRate
        if phase >= 2.0 * Double.pi {
            phase -= 2.0 * Double.pi
        }
        return sample
    }
}

/// 波音に海鳥のチャープを重ねた音源
public final class OceanWavesSeagulls: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    private let audioState = OceanWavesSeagullsState()

    // MARK: - Initialization

    /// - Parameters:
    ///   - noiseAmplitude: 波ノイズの音量
    ///   - lfoFrequency: 波の周期
    ///   - lfoMinimum: LFO最小音量
    ///   - lfoMaximum: LFO最大音量
    ///   - birdAmplitude: 海鳥チャープの音量
    ///   - birdMinInterval: チャープの最小間隔
    ///   - birdMaxInterval: チャープの最大間隔
    ///   - birdMinDuration: チャープの最小長さ
    ///   - birdMaxDuration: チャープの最大長さ
    ///   - birdFrequencyRange: チャープの周波数帯
    ///   - maxConcurrentChirps: 同時に鳴らす最大チャープ数
    public init(
        noiseAmplitude: Float = 0.3,
        lfoFrequency: Double = 0.2,
        lfoMinimum: Double = 0.1,
        lfoMaximum: Double = 0.6,
        birdAmplitude: Double = 0.25,
        birdMinInterval: Double = 4.0,
        birdMaxInterval: Double = 12.0,
        birdMinDuration: Double = 0.25,
        birdMaxDuration: Double = 0.6,
        birdFrequencyRange: ClosedRange<Double> = 1800.0...3200.0,
        maxConcurrentChirps: Int = 3
    ) {
        let localNoiseAmplitude = noiseAmplitude
        let localLFOFreq = lfoFrequency
        let localLFOMin = lfoMinimum
        let localLFOMax = lfoMaximum

        let localBirdAmplitude = birdAmplitude
        let localBirdMinInterval = birdMinInterval
        let localBirdMaxInterval = birdMaxInterval
        let localBirdMinDuration = birdMinDuration
        let localBirdMaxDuration = birdMaxDuration
        let localBirdFreqRange = birdFrequencyRange
        let localMaxChirps = max(1, maxConcurrentChirps)

        let noiseGen = NoiseGenerator(type: .white)

        var lfoPhase: Double = 0.0
        var chirpElapsed: Double = 0.0
        var nextChirpTime: Double = Double.random(in: localBirdMinInterval...localBirdMaxInterval)
        var voices: [BirdChirpVoice] = (0..<localMaxChirps).map { _ in BirdChirpVoice() }

        let sampleRate = 44100.0
        let deltaTime = 1.0 / sampleRate

        let state = audioState

        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

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
                // 波ノイズ生成
                let lfoValue = sin(lfoPhase)
                let normalizedLFO = (lfoValue + 1.0) / 2.0
                let volumeMod = localLFOMin + (normalizedLFO * (localLFOMax - localLFOMin))
                let noiseSample = noiseGen.generate() * Double(localNoiseAmplitude) * volumeMod

                // 海鳥チャープのトリガー管理
                chirpElapsed += deltaTime
                if chirpElapsed >= nextChirpTime {
                    if let voice = voices.first(where: { !$0.isActive }) ?? voices.randomElement() {
                        let freq = Double.random(in: localBirdFreqRange)
                        let duration = Double.random(in: localBirdMinDuration...localBirdMaxDuration)
                        let ampVariation = Double.random(in: 0.6...1.0)
                        voice.trigger(
                            frequency: freq,
                            duration: duration,
                            amplitude: localBirdAmplitude * ampVariation
                        )
                    }
                    chirpElapsed = 0.0
                    nextChirpTime = Double.random(in: localBirdMinInterval...localBirdMaxInterval)
                }

                var birdsSample: Double = 0.0
                for voice in voices where voice.isActive {
                    birdsSample += voice.renderSample(deltaTime: deltaTime, sampleRate: sampleRate)
                }

                let finalSample = Float(noiseSample + birdsSample)

                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    samples[frame] = finalSample
                }

                lfoPhase += 2.0 * Double.pi * localLFOFreq * deltaTime
                if lfoPhase >= 2.0 * Double.pi {
                    lfoPhase -= 2.0 * Double.pi
                }
            }

            return noErr
        }
    }

    // MARK: - AudioSource

    public func start() throws {
        // ソースノードは自動的に動作
    }

    public func stop() {
        // ソースノードは自動的に停止
    }

    public func suspend() {
        audioState.isSuspended = true
        print("🎵 [OceanWavesSeagulls] Suspended (output silence)")
    }

    public func resume() {
        audioState.isSuspended = false
        print("🎵 [OceanWavesSeagulls] Resumed (output active)")
    }

    public func setVolume(_ volume: Float) {
        // ボリュームは LocalAudioEngine のマスターボリュームで制御
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}
