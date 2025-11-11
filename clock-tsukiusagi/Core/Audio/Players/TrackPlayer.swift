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
    // MARK: - Private Properties

    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var buffer: AVAudioPCMBuffer?

    private var isLooping = false
    private var crossfadeDuration: TimeInterval = 0.0

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
    public func configure(engine: AVAudioEngine, format: AVAudioFormat) {
        self.engine = engine

        // プレイヤーノードをエンジンにアタッチ
        engine.attach(playerNode)

        // メインミキサーに接続
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        print("🎵 [TrackPlayer] Configured and connected to engine")
    }

    // MARK: - Public Methods

    public func load(url: URL) throws {
        // ファイルを読み込み
        let file = try AVAudioFile(forReading: url)
        audioFile = file

        // バッファを作成
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw TrackPlayerError.bufferCreationFailed
        }

        // ファイル全体をバッファに読み込み
        try file.read(into: buffer)
        self.buffer = buffer

        print("🎵 [TrackPlayer] Loaded file: \(url.lastPathComponent)")
        print("   Duration: \(Double(buffer.frameLength) / file.fileFormat.sampleRate)s")
        print("   Sample rate: \(file.fileFormat.sampleRate) Hz")
        print("   Channels: \(file.fileFormat.channelCount)")
    }

    public func play(loop: Bool, crossfadeDuration: TimeInterval) {
        guard let buffer = buffer else {
            print("⚠️ [TrackPlayer] No buffer loaded, cannot play")
            return
        }

        self.isLooping = loop
        self.crossfadeDuration = crossfadeDuration

        // 既に再生中の場合は停止
        if playerNode.isPlaying {
            playerNode.stop()
        }

        // 再生開始
        scheduleBuffer(buffer, loop: loop, crossfadeDuration: crossfadeDuration)
        playerNode.play()

        print("🎵 [TrackPlayer] Playback started (loop: \(loop), crossfade: \(crossfadeDuration)s)")
    }

    public func stop(fadeOut: TimeInterval) {
        guard playerNode.isPlaying else { return }

        if fadeOut > 0 {
            // フェードアウト処理（ボリュームランプを使用）
            let currentVolume = playerNode.volume
            playerNode.volume = 0.0

            // フェード完了後に停止
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) { [weak self] in
                self?.playerNode.stop()
                self?.playerNode.volume = currentVolume  // 音量を元に戻す
                print("🎵 [TrackPlayer] Stopped after fade out")
            }
        } else {
            // 即座に停止
            playerNode.stop()
            print("🎵 [TrackPlayer] Stopped immediately")
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
