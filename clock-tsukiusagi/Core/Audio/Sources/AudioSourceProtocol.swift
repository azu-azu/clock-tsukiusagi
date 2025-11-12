//
//  AudioSourceProtocol.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  音源の共通インターフェース
//

import AVFoundation

/// 音源の共通プロトコル
public protocol AudioSource: AnyObject {
    /// 音源ノード
    var sourceNode: AVAudioNode { get }

    /// 音源を開始
    func start() throws

    /// 音源を停止
    func stop()

    /// 音源を一時停止（タイマー等の副作用も停止）
    func suspend()

    /// 音源を再開（タイマー等を再起動）
    func resume()

    /// 音量を設定（0.0〜1.0）
    /// - Parameter volume: 音量レベル
    func setVolume(_ volume: Float)

    /// エンジンにアタッチして接続
    /// - Parameters:
    ///   - engine: AVAudioEngine
    ///   - format: オーディオフォーマット
    func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws
}

/// デフォルト実装
public extension AudioSource {
    /// 基本的な接続処理
    func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
    }

    /// デフォルトのsuspend実装（何もしない）
    func suspend() {
        // Override if source has timers or other side effects
    }

    /// デフォルトのresume実装（何もしない）
    func resume() {
        // Override if source has timers or other side effects
    }
}
