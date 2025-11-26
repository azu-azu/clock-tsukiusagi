//
//  NoiseSource.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-09.
//  ホワイトノイズ生成
//

import AVFoundation

/// ホワイトノイズ生成器
/// リアルタイムでホワイトノイズを生成します
public final class NoiseSource: AudioSource {
    // MARK: - Properties

    private var _sourceNode: AVAudioSourceNode!
    public var sourceNode: AVAudioNode { _sourceNode }

    /// 音量（0.0〜1.0）
    public var amplitude: Float {
        didSet { amplitude = max(0.0, min(1.0, amplitude)) }
    }

    // MARK: - Initialization

    /// ノイズソースを初期化
    /// - Parameter amplitude: 音量（0.0〜1.0）デフォルト: 0.1
    public init(amplitude: Float = 0.1) {
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
        amplitude = volume
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        // レンダーブロック内でノイズを生成
        _sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // 各フレームでランダムノイズを生成
            for buffer in abl {
                let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)

                for frame in 0..<Int(frameCount) {
                    // -1.0〜1.0のランダム値を生成
                    let random = Float.random(in: -1.0...1.0)
                    ptr[frame] = random * self.amplitude
                }
            }

            return noErr
        }

        // エンジンにアタッチして接続
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}
