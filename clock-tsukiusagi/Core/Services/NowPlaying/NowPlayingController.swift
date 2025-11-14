//
//  NowPlayingController.swift
//  clock-tsukiusagi
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

    private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

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
        guard var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo else { return }

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
    public func setupRemoteCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play コマンド
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }

        // Pause コマンド
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }

        // Stop コマンド
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { _ in
            onStop()
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
