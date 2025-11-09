//
//  MultiOscillator.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  複数サイン波合成（倍音構造）
//

import AVFoundation

/// 倍音情報
public struct Harmonic {
    /// 周波数倍率（基音の何倍か）
    public let multiplier: Double
    /// 音量（0.0〜1.0）
    public let amplitude: Double

    public init(multiplier: Double, amplitude: Double) {
        self.multiplier = multiplier
        self.amplitude = amplitude
    }
}

/// 複数サイン波オシレータ
/// 倍音構造を持つ豊かな音色を生成します
public final class MultiOscillator: AudioSource {
    // MARK: - Properties

    private var _sourceNode: AVAudioSourceNode!
    public var sourceNode: AVAudioNode { _sourceNode }

    /// 基音の周波数（Hz）
    public var fundamentalFrequency: Double {
        didSet { fundamentalFrequency = max(20, min(20000, fundamentalFrequency)) }
    }

    /// 全体の音量（0.0〜1.0）
    public var amplitude: Double {
        didSet { amplitude = max(0.0, min(1.0, amplitude)) }
    }

    /// 倍音構造
    public var harmonics: [Harmonic]

    private var phases: [Double] = []
    private let twoPi = 2.0 * Double.pi

    // MARK: - Initialization

    /// 複数オシレータを初期化
    /// - Parameters:
    ///   - fundamentalFrequency: 基音の周波数（Hz）デフォルト: 220Hz（A3）
    ///   - amplitude: 全体の音量 デフォルト: 0.2
    ///   - harmonics: 倍音構造 デフォルトは基音のみ
    public init(
        fundamentalFrequency: Double = 220.0,
        amplitude: Double = 0.2,
        harmonics: [Harmonic] = [Harmonic(multiplier: 1.0, amplitude: 1.0)]
    ) {
        self.fundamentalFrequency = fundamentalFrequency
        self.amplitude = amplitude
        self.harmonics = harmonics
        self.phases = Array(repeating: 0.0, count: harmonics.count)
    }

    // MARK: - Convenience Initializers

    /// チベタンボウル風の倍音構造で初期化
    public static func tibetanBowl(fundamentalFrequency: Double = 220.0) -> MultiOscillator {
        let harmonics = [
            Harmonic(multiplier: 1.0, amplitude: 1.0),   // 基音
            Harmonic(multiplier: 2.0, amplitude: 0.7),   // 2倍音
            Harmonic(multiplier: 3.0, amplitude: 0.5),   // 3倍音
            Harmonic(multiplier: 4.0, amplitude: 0.3),   // 4倍音
            Harmonic(multiplier: 5.0, amplitude: 0.2)    // 5倍音
        ]
        return MultiOscillator(fundamentalFrequency: fundamentalFrequency, amplitude: 0.2, harmonics: harmonics)
    }

    // MARK: - AudioSource Protocol

    public func start() throws {
        // AVAudioSourceNodeは自動的に開始されるため、特別な処理は不要
    }

    public func stop() {
        amplitude = 0.0
    }

    public func setVolume(_ volume: Float) {
        amplitude = Double(volume)
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        let sampleRate = format.sampleRate

        // 位相配列のサイズを調整
        phases = Array(repeating: 0.0, count: harmonics.count)

        // レンダーブロック内で複数の倍音を合成
        _sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // 各フレームでサンプルを計算
            for frame in 0..<Int(frameCount) {
                var mixedSample: Float = 0.0

                // 全ての倍音を合成
                for (index, harmonic) in self.harmonics.enumerated() {
                    let frequency = self.fundamentalFrequency * harmonic.multiplier
                    let phaseIncrement = self.twoPi * frequency / sampleRate

                    let sample = Float(sin(self.phases[index]) * harmonic.amplitude)
                    mixedSample += sample

                    self.phases[index] += phaseIncrement

                    // 位相を2πの範囲内に保つ
                    if self.phases[index] > self.twoPi {
                        self.phases[index] -= self.twoPi
                    }
                }

                // 全体の音量を適用（倍音の数で正規化）
                let normalizedSample = mixedSample / Float(self.harmonics.count) * Float(self.amplitude)

                // 全チャンネルに同じサンプルを書き込み
                for buffer in abl {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = normalizedSample
                }
            }

            return noErr
        }

        // エンジンにアタッチして接続
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}
