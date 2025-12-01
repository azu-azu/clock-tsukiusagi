//
//  TrackPlayer.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-11.
//  オーディオファイル再生プレイヤー（WAV対応、シームレスループ＆クロスフェード）
//

import AVFoundation
import Foundation

/// トラック再生プロトコル
@MainActor
public protocol TrackPlaying {
    /// オーディオファイルを読み込み
    /// - Parameter url: ローカルファイルURL
    /// - Throws: ファイル読み込みエラー
    func load(url: URL) throws

    /// 再生を開始
    /// - Parameters:
    ///   - loop: ループ再生を有効化
    ///   - crossfadeDuration: ループ時のクロスフェード時間（秒）
    func play(loop: Bool, crossfadeDuration: TimeInterval)

    /// 再生を停止
    /// - Parameter fadeOut: フェードアウト時間（秒）
    func stop(fadeOut: TimeInterval)

    /// 再生中かどうか
    var isPlaying: Bool { get }
}

/// オーディオファイル再生プレイヤー
/// WAVファイルをシームレスにループ再生（オプションでクロスフェード）
@MainActor
public final class TrackPlayer: TrackPlaying {
    // MARK: - Internal Properties

    // Internal access needed for AudioService to detach/reattach node
    let playerNode = AVAudioPlayerNode()

    // MARK: - Private Properties

    private var audioFile: AVAudioFile?
    private var buffer: AVAudioPCMBuffer?

    private var isLooping = false
    private var crossfadeDuration: TimeInterval = 0.0
    private var fadeOutWorkItem: DispatchWorkItem?  // Track pending fade out

    private weak var engine: AVAudioEngine?

    // MARK: - Public Properties

    public var isPlaying: Bool {
        playerNode.isPlaying
    }

    // MARK: - Initialization

    public init() {
        // Initialization completed
    }

    // MARK: - Configuration

    /// プレイヤーをオーディオエンジンに接続
    /// - Parameters:
    ///   - engine: AVAudioEngine
    ///   - format: オーディオフォーマット（バッファのフォーマット）
    ///   - destination: 接続先ノード（デフォルト: mainMixerNode）
    public func configure(engine: AVAudioEngine, format: AVAudioFormat, destination: AVAudioNode? = nil) {
        self.engine = engine

        // プレイヤーノードをエンジンにアタッチ
        engine.attach(playerNode)

        // 指定された接続先またはメインミキサーに接続
        // NOTE: Mixer will automatically convert format if needed
        let targetNode = destination ?? engine.mainMixerNode
        engine.connect(playerNode, to: targetNode, format: format)
    }

    // MARK: - Public Methods

    public func load(url: URL) throws {
        // 既存のバッファとファイルを明示的にクリア（キャッシュ問題を回避）
        if playerNode.isPlaying {
            playerNode.stop()
        }

        // CRITICAL: Reset playerNode to clear any internal cache
        playerNode.reset()

        // 既存のバッファを解放
        buffer = nil
        audioFile = nil

        // CRITICAL: Force fresh AVAudioFile instance to avoid decode cache
        // Create new file handle each time to prevent iOS from reusing cached decoder
        let file = try AVAudioFile(forReading: url)

        // バッファを作成（ファイルのprocessingFormatをそのまま使用）
        // AVAudioEngine's mixer will handle format conversion automatically
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw TrackPlayerError.bufferCreationFailed
        }

        // ファイル全体をバッファに読み込み
        try file.read(into: buffer)

        // Store references
        self.buffer = buffer
        self.audioFile = file
    }

    public func play(loop: Bool, crossfadeDuration: TimeInterval) {
        guard let buffer = buffer else {
            print("⚠️ [TrackPlayer] No buffer loaded, cannot play")
            return
        }

        // Cancel any pending fade out from previous playback
        fadeOutWorkItem?.cancel()
        fadeOutWorkItem = nil

        self.isLooping = loop
        self.crossfadeDuration = crossfadeDuration

        // 既に再生中の場合は停止
        if playerNode.isPlaying {
            playerNode.stop()
        }

        // プレイヤーノードの音量を最大に設定（マスター音量で制御する）
        playerNode.volume = 1.0

        // 再生開始
        scheduleBuffer(buffer, loop: loop, crossfadeDuration: crossfadeDuration)
        playerNode.play()

    }

    public func stop(fadeOut: TimeInterval) {
        guard playerNode.isPlaying else { return }

        // Cancel any pending fade out work item
        fadeOutWorkItem?.cancel()
        fadeOutWorkItem = nil

        // Stop looping immediately
        isLooping = false

        if fadeOut > 0 {
            // フェードアウト処理（ボリュームランプを使用）
            let currentVolume = playerNode.volume
            playerNode.volume = 0.0

            // Create cancellable work item for fade out completion
            // Note: We need to declare workItem first, then reference it in the closure
            var workItem: DispatchWorkItem!
            workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }

                // Check if this work item was cancelled before execution
                // This prevents "ghost" fade-out tasks from stopping new playback
                if workItem.isCancelled {
                    return
                }

                self.playerNode.stop()
                self.playerNode.reset()  // Clear pending schedules
                self.playerNode.volume = currentVolume  // 音量を元に戻す
                self.fadeOutWorkItem = nil
            }

            fadeOutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut, execute: workItem)
        } else {
            // 即座に停止
            playerNode.stop()
            playerNode.reset()  // Clear pending schedules
        }
    }

    // MARK: - Private Methods

    /// バッファをスケジュール（ループ対応）
    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer, loop: Bool, crossfadeDuration: TimeInterval) {
        if loop {
            // ループ再生：completionCallbackType で次のバッファをスケジュール
            playerNode.scheduleBuffer(
                buffer,
                at: nil,
                options: [],
                completionCallbackType: .dataPlayedBack
            ) { [weak self] callbackType in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isLooping else { return }

                    // 次のバッファをスケジュール（シームレスループ）
                    self.scheduleBuffer(buffer, loop: true, crossfadeDuration: crossfadeDuration)
                }
            }
        } else {
            // 1回再生
            playerNode.scheduleBuffer(
                buffer,
                at: nil,
                options: [],
                completionCallbackType: .dataPlayedBack
            ) { callbackType in
            }
        }
    }
}

// MARK: - Errors

public enum TrackPlayerError: Error, LocalizedError {
    case bufferCreationFailed
    case fileNotLoaded

    public var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "バッファの作成に失敗しました"
        case .fileNotLoaded:
            return "ファイルが読み込まれていません"
        }
    }
}
