//
//  CracklingFire.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-13.
//  焚き火の音（バンドパスノイズ + ランダムパルス）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// 焚き火の音音源
/// ベースノイズとランダムなパルス音で焚き火の音を表現します
public final class CracklingFire: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // Suspend/resume control
    private let audioState = AudioState()

    // MARK: - Initialization

    /// CracklingFireを初期化
    /// - Parameters:
    ///   - baseAmplitude: ベースノイズ音量
    ///   - pulseAmplitude: パルス音量
    ///   - minInterval: パルス最小間隔
    ///   - maxInterval: パルス最大間隔
    ///   - pulseDuration: パルス持続時間
    public init(
        baseAmplitude: Float = 0.25,
        pulseAmplitude: Float = 0.6,
        minInterval: Double = 0.5,
        maxInterval: Double = 3.0,
        minPulseDuration: Double = 0.01,
        maxPulseDuration: Double = 0.05
    ) {
        let localBaseAmplitude = baseAmplitude
        let localPulseAmplitude = pulseAmplitude

        // ノイズジェネレータ（ピンクノイズ）
        let noiseGen = NoiseGenerator(type: .pink)

        // パルス用の状態
        var pulseActive = false
        var pulseEnvelope: Double = 0.0
        var pulseElapsed: Double = 0.0
        var pulseDuration: Double = 0.0

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

            let sampleRate = 44100.0
            let deltaTime = 1.0 / sampleRate

            for frame in 0..<Int(frameCount) {
                // ランダムトリガーの更新
                triggerElapsed += deltaTime
                if triggerElapsed >= nextTriggerTime {
                    // 新しいパルスをトリガー
                    pulseActive = true
                    pulseElapsed = 0.0
                    pulseDuration = Double.random(in: minPulseDuration...maxPulseDuration)
                    pulseEnvelope = 1.0

                    triggerElapsed = 0.0
                    nextTriggerTime = Double.random(in: minInterval...maxInterval)
                }

                // パルスエンベロープの更新
                if pulseActive {
                    pulseElapsed += deltaTime
                    if pulseElapsed < pulseDuration {
                        // 減衰エンベロープ（指数減衰）
                        let progress = pulseElapsed / pulseDuration
                        pulseEnvelope = 1.0 - progress
                    } else {
                        pulseActive = false
                        pulseEnvelope = 0.0
                    }
                }

                // ベースノイズ（低域）
                let baseNoise = noiseGen.generate() * Double(localBaseAmplitude)

                // パルス音（ノイズバースト）
                let pulseNoise = pulseActive ? (Double.random(in: -1.0...1.0) * Double(localPulseAmplitude) * pulseEnvelope) : 0.0

                // 合成
                let mixed = baseNoise + pulseNoise

                let finalSample = Float(mixed)

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
        print("🎵 [CracklingFire] Suspended (output silence)")
    }

    public func resume() {
        audioState.isSuspended = false
        print("🎵 [CracklingFire] Resumed (output active)")
    }

    public func setVolume(_ volume: Float) {
        // ボリュームは LocalAudioEngine のマスターボリュームで制御
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}
