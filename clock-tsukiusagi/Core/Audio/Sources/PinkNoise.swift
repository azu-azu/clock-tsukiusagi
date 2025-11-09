//
//  PinkNoise.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  ピンクノイズ生成（1/f noise）
//

import AVFoundation
import Foundation

/// ピンクノイズ生成器
/// Fujiko設計: Focus向け - サーッと締まる、思考が冴える
public final class PinkNoise: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    private let amplitude: Double

    // MARK: - Initialization

    /// ピンクノイズを初期化
    /// - Parameter amplitude: 振幅（0.0〜1.0）
    public init(amplitude: Double = 0.15) {
        self.amplitude = amplitude

        // Voss-McCartney アルゴリズムによるピンクノイズ生成
        // 複数のホワイトノイズを異なるレートで更新して合成
        var generators: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        var counter: UInt32 = 0
        let localAmplitude = amplitude

        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                // カウンタの各ビットが変化したらそのジェネレータを更新
                let lastCounter = counter
                counter = counter &+ 1
                let diff = lastCounter ^ counter

                for i in 0..<generators.count {
                    if (diff & (1 << i)) != 0 {
                        generators[i] = Double.random(in: -1.0...1.0)
                    }
                }

                // 全ジェネレータを合成
                var sum = generators.reduce(0.0, +)

                // 正規化（7つのジェネレータの平均）
                sum /= Double(generators.count)

                // 振幅を適用
                let sample = Float(sum * localAmplitude)

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

    public func setVolume(_ volume: Float) {
        // ボリュームは LocalAudioEngine のマスターボリュームで制御
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}
