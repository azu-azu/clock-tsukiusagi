//
//  NowPlayingController.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-11.
//  Control CenterとロックスクリーンのNow Playing情報を管理
//

import Foundation
import MediaPlayer

/// Now Playing情報コントローラー
/// Control CenterとロックスクリーンにNow Playing情報を表示
@MainActor
public final class NowPlayingController {
    // MARK: - Properties

    // nonisolated(unsafe) because accessed from background thread handlers
    nonisolated(unsafe) private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

    // Retain command targets to prevent deallocation
    // nonisolated(unsafe) because these are accessed from background thread handlers
    nonisolated(unsafe) private var playTarget: Any?
    nonisolated(unsafe) private var pauseTarget: Any?
    nonisolated(unsafe) private var stopTarget: Any?
    nonisolated(unsafe) private var togglePlayPauseTarget: Any?

    // MARK: - Public Methods

    /// Now Playing情報を更新
    /// - Parameters:
    ///   - title: 曲名/プリセット名
    ///   - artist: アーティスト名（オプション）
    ///   - album: アルバム名（オプション）
    ///   - artwork: アートワーク画像（オプション）
    ///   - duration: 再生時間（秒）
    ///   - elapsedTime: 経過時間（秒）
    public func updateNowPlaying(
        title: String,
        artist: String? = nil,
        album: String? = nil,
        artwork: UIImage? = nil,
        duration: TimeInterval? = nil,
        elapsedTime: TimeInterval = 0
    ) {
        var nowPlayingInfo = [String: Any]()

        // 基本情報
        nowPlayingInfo[MPMediaItemPropertyTitle] = title

        if let artist = artist {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }

        if let album = album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }

        // アートワーク
        if let artwork = artwork {
            let artworkImage = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artworkImage
        }

        // 再生時間情報
        if let duration = duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0  // 再生中

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo

    }

    /// 再生状態を更新（再生/一時停止）
    /// - Parameter isPlaying: 再生中かどうか
    public func updatePlaybackState(isPlaying: Bool) {
        guard var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo else {
            return
        }

        // 再生レート: 1.0 = 再生中, 0.0 = 一時停止
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    /// Now Playing情報をクリア
    public func clearNowPlaying() {
        nowPlayingInfoCenter.nowPlayingInfo = nil
    }

    // MARK: - Remote Control Commands

    /// リモートコントロールコマンドをセットアップ
    /// - Parameters:
    ///   - onPlay: 再生ボタン押下時のハンドラ
    ///   - onPause: 一時停止ボタン押下時のハンドラ
    ///   - onStop: 停止ボタン押下時のハンドラ
    /// - Note: nonisolated because MPRemoteCommandCenter handlers run on background threads
    nonisolated public func setupRemoteCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play コマンド
        commandCenter.playCommand.isEnabled = true
        playTarget = commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }

        // Pause コマンド
        commandCenter.pauseCommand.isEnabled = true
        pauseTarget = commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }

        // Stop コマンド
        commandCenter.stopCommand.isEnabled = true
        stopTarget = commandCenter.stopCommand.addTarget { _ in
            onStop()
            return .success
        }

        // Toggle play/pause command (this is what iOS uses for lock screen single button)
        commandCenter.togglePlayPauseCommand.isEnabled = true
        togglePlayPauseTarget = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let strongSelf = self else {
                return .commandFailed
            }

            // Get current playback rate from nowPlayingInfo
            let currentRate = strongSelf.nowPlayingInfoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0

            if currentRate > 0.0 {
                // Currently playing -> pause
                onPause()
            } else {
                // Currently paused -> play
                onPlay()
            }

            return .success
        }

        // Skip Forward/Backward は無効化（音声ドローンには不要）
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
    }

    /// リモートコントロールコマンドを無効化
    public func disableRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.stopCommand.isEnabled = false

    }
}
