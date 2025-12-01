//
//  Oscillator.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-09.
//  サイン波オシレータ
//

import AVFoundation

/// サイン波オシレータ
/// リアルタイムでサイン波を生成します
public final class Oscillator: AudioSource {
    // MARK: - Properties

    private var _sourceNode: AVAudioSourceNode!
    public var sourceNode: AVAudioNode { _sourceNode }

    /// 周波数（Hz）
    public var frequency: Double {
        didSet { frequency = max(20, min(20000, frequency)) } // 可聴範囲内に制限
    }

    /// 音量（0.0〜1.0）
    public var amplitude: Double {
        didSet { amplitude = max(0.0, min(1.0, amplitude)) }
    }

    private var phase: Double = 0.0
    private let twoPi = 2.0 * Double.pi

    // MARK: - Initialization

    /// オシレータを初期化
    /// - Parameters:
    ///   - frequency: 周波数（Hz）デフォルト: 220Hz（A3）
    ///   - amplitude: 音量（0.0〜1.0）デフォルト: 0.2
    public init(frequency: Double = 220.0, amplitude: Double = 0.2) {
        self.frequency = frequency
        self.amplitude = amplitude
    }

    // MARK: - AudioSource Protocol

    public func start() throws {
        // AVAudioSourceNodeは自動的に開始されるため、特別な処理は不要
    }

    public func stop() {
        // フェードアウトのため、音量を0にする
        amplitude = 0.0
    }

    public func setVolume(_ volume: Float) {
        amplitude = Double(volume)
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        let sampleRate = format.sampleRate


        // レンダーブロック内で波形を生成
        var renderCount = 0
        _sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = self.twoPi * self.frequency / sampleRate

            // デバッグ: 最初の数回だけログ出力
            if renderCount < 3 {
                renderCount += 1
            }

            // 各フレームでサンプルを計算
            for frame in 0..<Int(frameCount) {
                let sample = Float(sin(self.phase) * self.amplitude)
                self.phase += phaseIncrement

                // 位相を2πの範囲内に保つ
                if self.phase > self.twoPi {
                    self.phase -= self.twoPi
                }

                // 全チャンネルに同じサンプルを書き込み
                for buffer in abl {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = sample
                }
            }

            return noErr
        }

        // エンジンにアタッチして接続
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)

    }
}
