//
//  DetunedOscillator.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  デチューンされた複数オシレータによる心地よい音源
//

import AVFoundation
import Foundation

// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

/// デチューンされた複数のオシレータを組み合わせた音源
/// Fujiko設計原則: 純粋なサイン波は刺激的すぎるため、わずかにずらした複数の波を重ねる
public final class DetunedOscillator: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    // Suspend/resume control (shared with render callback)
    private let audioState = AudioState()

    private var phases: [Double] = []
    private var frequencies: [Double] = []
    private let oscillatorCount: Int
    private let amplitude: Double
    private let noiseLevel: Double
    private let twoPi = 2.0 * Double.pi

    // MARK: - Initialization

    /// デチューンオシレータを初期化
    /// - Parameters:
    ///   - baseFrequency: 基準周波数（Hz）
    ///   - detuneAmount: デチューン量（Hz）、各オシレータは ±detuneAmount の範囲でずれる
    ///   - oscillatorCount: オシレータの数（デフォルト: 3）
    ///   - amplitude: 振幅（0.0〜1.0）
    ///   - noiseLevel: ノイズ混入量（0.0〜1.0、デフォルト: 0.02）
    public init(
        baseFrequency: Double,
        detuneAmount: Double = 3.0,
        oscillatorCount: Int = 3,
        amplitude: Double = 0.3,
        noiseLevel: Double = 0.02
    ) {
        self.oscillatorCount = max(2, min(oscillatorCount, 5))  // 2-5個に制限
        self.amplitude = amplitude
        self.noiseLevel = noiseLevel

        // 各オシレータの周波数を計算（デチューン）
        for i in 0..<self.oscillatorCount {
            let detune = detuneAmount * (Double(i) / Double(self.oscillatorCount - 1) * 2.0 - 1.0)
            frequencies.append(baseFrequency + detune)
            phases.append(0.0)
        }

        // AVAudioSourceNode を作成
        var localPhases = phases
        let localFrequencies = frequencies
        let localOscillatorCount = self.oscillatorCount
        let localAmplitude = amplitude
        let localNoiseLevel = noiseLevel
        let twoPi = self.twoPi

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

            let sampleRate = 44100.0

            for frame in 0..<Int(frameCount) {
                // 複数のオシレータを合成
                var mixedSample: Double = 0.0

                for i in 0..<localOscillatorCount {
                    let rawSample = sin(localPhases[i])
                    // tanh で波形を整形（柔らかく）
                    let shapedSample = tanh(rawSample * 1.2)
                    mixedSample += shapedSample

                    // 位相を進める
                    let phaseIncrement = twoPi * localFrequencies[i] / sampleRate
                    localPhases[i] += phaseIncrement

                    // 位相を正規化
                    if localPhases[i] >= twoPi {
                        localPhases[i] -= twoPi
                    }
                }

                // 平均化
                mixedSample /= Double(localOscillatorCount)

                // ノイズを追加（空気感）
                let noise = (Double.random(in: -1.0...1.0)) * localNoiseLevel
                mixedSample += noise

                // 振幅を適用
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

        // 位相配列を同期（実際には render block 内で更新されるので不要だが、念のため）
        self.phases = localPhases
    }

    // MARK: - AudioSource Protocol

    public func start() throws {
        // ソースノードは自動的に動作するため、特に処理は不要
    }

    public func stop() {
        // ソースノードは自動的に停止するため、特に処理は不要
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
