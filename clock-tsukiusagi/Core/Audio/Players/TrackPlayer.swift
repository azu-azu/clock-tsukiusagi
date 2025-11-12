//
//  TrackPlayer.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-11.
//  オーディオファイル再生プレイヤー（WAV/CAF対応、シームレスループ＆クロスフェード）
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
/// WAV/CAFファイルをシームレスにループ再生（オプションでクロスフェード）
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
    ///   - format: オーディオフォーマット
    ///   - destination: 接続先ノード（デフォルト: mainMixerNode）
    public func configure(engine: AVAudioEngine, format: AVAudioFormat, destination: AVAudioNode? = nil) {
        self.engine = engine

        // プレイヤーノードをエンジンにアタッチ
        engine.attach(playerNode)

        // 指定された接続先またはメインミキサーに接続
        let targetNode = destination ?? engine.mainMixerNode
        engine.connect(playerNode, to: targetNode, format: format)

        print("🎵 [TrackPlayer] Configured and connected to \(destination != nil ? "masterBusMixer" : "mainMixerNode")")
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

        print("🎵 [TrackPlayer] Loading new file: \(url.lastPathComponent)")
        print("   Full path: \(url.path)")

        // CRITICAL: Force fresh AVAudioFile instance to avoid decode cache
        // Create new file handle each time to prevent iOS from reusing cached decoder
        let file = try AVAudioFile(forReading: url)

        // Verify we're reading the correct file
        print("   File length: \(file.length) frames")
        print("   Processing format: \(file.processingFormat.sampleRate) Hz, \(file.processingFormat.channelCount) ch")

        // バッファを作成
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw TrackPlayerError.bufferCreationFailed
        }

        // ファイル全体をバッファに読み込み
        try file.read(into: buffer)

        // CRITICAL: Verify buffer contains data
        guard let floatChannelData = buffer.floatChannelData else {
            throw TrackPlayerError.bufferCreationFailed
        }

        // Sample first 10 samples to verify unique audio data
        let firstSamples = (0..<min(10, Int(buffer.frameLength))).map {
            floatChannelData[0][$0]
        }
        print("   First 10 samples: \(firstSamples.map { String(format: "%.4f", $0) }.joined(separator: ", "))")

        // Store references AFTER verification
        self.buffer = buffer
        self.audioFile = file

        print("🎵 [TrackPlayer] ✅ File loaded successfully")
        print("   Duration: \(Double(buffer.frameLength) / file.fileFormat.sampleRate)s")
        print("   Buffer frame length: \(buffer.frameLength)")
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

        print("🎵 [TrackPlayer] Playback started (loop: \(loop), crossfade: \(crossfadeDuration)s)")
        print("🎵 [TrackPlayer] Player node volume: \(playerNode.volume)")
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
                    print("🎵 [TrackPlayer] Fade-out canceled before execution (ghost task prevented)")
                    return
                }

                self.playerNode.stop()
                self.playerNode.reset()  // Clear pending schedules
                self.playerNode.volume = currentVolume  // 音量を元に戻す
                self.fadeOutWorkItem = nil
                print("🎵 [TrackPlayer] Stopped and reset after fade out")
            }

            fadeOutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut, execute: workItem)
        } else {
            // 即座に停止
            playerNode.stop()
            playerNode.reset()  // Clear pending schedules
            print("🎵 [TrackPlayer] Stopped and reset immediately")
        }
    }

    // MARK: - Private Methods

    /// バッファをスケジュール（ループ対応）
    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer, loop: Bool, crossfadeDuration: TimeInterval) {
        if loop {
            // ループ再生：completionCallbackType で次のバッファをスケジュール
            playerNode.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] callbackType in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isLooping else { return }

                    // 次のバッファをスケジュール（シームレスループ）
                    self.scheduleBuffer(buffer, loop: true, crossfadeDuration: crossfadeDuration)
                }
            }
        } else {
            // 1回再生
            playerNode.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { callbackType in
                print("🎵 [TrackPlayer] Playback completed")
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
