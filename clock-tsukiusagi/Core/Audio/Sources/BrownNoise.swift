//
//  BrownNoise.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  ブラウンノイズ生成（ランダムウォーク）
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// ブラウンノイズ生成器
/// Fujiko設計: Sleep向け - 低域中心、胎内音に近い
public final class BrownNoise: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    private let amplitude: Double

    // Suspend/resume control (shared with render callback)
    private let audioState = AudioState()

    // MARK: - Initialization

    /// ブラウンノイズを初期化
    /// - Parameter amplitude: 振幅（0.0〜1.0）
    public init(amplitude: Double = 0.12) {
        self.amplitude = amplitude

        // ランダムウォークによるブラウンノイズ生成
        var runningSum: Double = 0.0
        let localAmplitude = amplitude

        // Capture audio state for suspend/resume control
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

            for frame in 0..<Int(frameCount) {
                // ランダムなステップを追加（積分）
                let whiteNoise = Double.random(in: -1.0...1.0)
                runningSum += whiteNoise * 0.02  // ステップサイズを制限

                // クリッピング防止（範囲を-1.0〜1.0に保つ）
                if runningSum > 1.0 {
                    runningSum = 1.0
                } else if runningSum < -1.0 {
                    runningSum = -1.0
                }

                // 振幅を適用
                let sample = Float(runningSum * localAmplitude)

                // 全チャンネルに書き込み
                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    samples[frame] = sample
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
