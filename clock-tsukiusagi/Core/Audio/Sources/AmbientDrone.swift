//
//  AmbientDrone.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  アンビエントドローン（ノイズ + サイン波 + LFO変調）
//  Fujiko設計: Focus/Relax/Sleepモード向けの"静寂のゆらぎ"
//

import AVFoundation
import Foundation

/// アンビエントドローン音源
/// Fujiko設計原則: "音楽を鳴らす"のではなく、"静寂をどう揺らすか"をデザインする
public final class AmbientDrone: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // MARK: - Initialization

    /// アンビエントドローンを初期化
    /// - Parameters:
    ///   - noiseType: ノイズタイプ（pink/white/brown）
    ///   - noiseAmplitude: ノイズ音量
    ///   - sineFrequencies: サイン波の周波数配列（空の場合はサイン波なし）
    ///   - sineAmplitude: サイン波の音量
    ///   - detuneAmount: サイン波のデチューン量（Hz）
    ///   - lfoAmplitudeFrequency: 音量LFOの周波数（Hz）
    ///   - lfoAmplitudeDepth: 音量LFOの深さ（0.0〜1.0）
    public init(
        noiseType: NoiseType,
        noiseAmplitude: Double = 0.10,
        sineFrequencies: [Double] = [],
        sineAmplitude: Double = 0.05,
        detuneAmount: Double = 2.0,
        lfoAmplitudeFrequency: Double = 0.15,
        lfoAmplitudeDepth: Double = 0.2
    ) {
        // ローカル変数としてノイズジェネレータを準備
        let noiseGen = NoiseGenerator(type: noiseType)

        // サイン波の位相を初期化
        var sinePhases: [Double] = []
        var sineFreqs: [Double] = []
        let twoPi = 2.0 * Double.pi

        for baseFreq in sineFrequencies {
            // デチューン（±detuneAmount）
            let detune = Double.random(in: -detuneAmount...detuneAmount)
            sineFreqs.append(baseFreq + detune)
            sinePhases.append(Double.random(in: 0..<twoPi))
        }

        var lfoPhase: Double = 0.0

        let localNoiseAmplitude = noiseAmplitude
        let localSineAmplitude = sineAmplitude
        let localLFOFrequency = lfoAmplitudeFrequency
        let localLFODepth = lfoAmplitudeDepth

        // AVAudioSourceNode を作成
        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let sampleRate = 44100.0
            let deltaTime = 1.0 / sampleRate

            for frame in 0..<Int(frameCount) {
                // LFOによる音量変調
                let lfoValue = sin(lfoPhase)
                let volumeMod = 1.0 - (localLFODepth * 0.5) + (lfoValue * localLFODepth * 0.5)

                // ノイズ成分
                let noise = noiseGen.generate() * localNoiseAmplitude

                // サイン波成分
                var sineSum: Double = 0.0
                for i in 0..<sinePhases.count {
                    let sineSample = sin(sinePhases[i])
                    // tanh で柔らかく
                    sineSum += tanh(sineSample * 1.1)

                    // 位相を進める
                    let phaseIncrement = twoPi * sineFreqs[i] / sampleRate
                    sinePhases[i] += phaseIncrement
                    if sinePhases[i] >= twoPi {
                        sinePhases[i] -= twoPi
                    }
                }
                sineSum *= localSineAmplitude

                // 合成
                var mixed = noise + sineSum

                // 音量変調を適用
                mixed *= volumeMod

                let sample = Float(mixed)

                // 全チャンネルに書き込み
                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    samples[frame] = sample
                }

                // LFO位相を進める
                lfoPhase += twoPi * localLFOFrequency * deltaTime
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

    public func setVolume(_ volume: Float) {
        // ボリュームは LocalAudioEngine のマスターボリュームで制御
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}

// MARK: - NoiseType

/// ノイズタイプ
public enum NoiseType {
    case pink       // ピンクノイズ（Focus向け）
    case white      // ホワイトノイズ（Relax向け）
    case brown      // ブラウンノイズ（Sleep向け）
}

// MARK: - NoiseGenerator

/// ノイズ生成器（内部用）
private class NoiseGenerator {
    private let type: NoiseType

    // ピンクノイズ用
    private var pinkGenerators: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    private var pinkCounter: UInt32 = 0

    // ブラウンノイズ用
    private var brownRunningSum: Double = 0.0

    init(type: NoiseType) {
        self.type = type
    }

    func generate() -> Double {
        switch type {
        case .pink:
            return generatePink()
        case .white:
            return generateWhite()
        case .brown:
            return generateBrown()
        }
    }

    private func generateWhite() -> Double {
        return Double.random(in: -1.0...1.0)
    }

    private func generatePink() -> Double {
        // Voss-McCartney アルゴリズム
        let lastCounter = pinkCounter
        pinkCounter = pinkCounter &+ 1
        let diff = lastCounter ^ pinkCounter

        for i in 0..<pinkGenerators.count {
            if (diff & (1 << i)) != 0 {
                pinkGenerators[i] = Double.random(in: -1.0...1.0)
            }
        }

        let sum = pinkGenerators.reduce(0.0, +)
        return sum / Double(pinkGenerators.count)
    }

    private func generateBrown() -> Double {
        // ランダムウォーク
        let whiteNoise = Double.random(in: -1.0...1.0)
        brownRunningSum += whiteNoise * 0.02

        // クリッピング防止
        if brownRunningSum > 1.0 {
            brownRunningSum = 1.0
        } else if brownRunningSum < -1.0 {
            brownRunningSum = -1.0
        }

        return brownRunningSum
    }
}
