//
//  LocalAudioEngine.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-09.
//  メインエンジン・統合管理（TrackPlayer専用）
//

import AVFoundation
import Foundation

/// ローカル音声エンジン
/// AVAudioEngineをラップし、TrackPlayerと連携
public final class LocalAudioEngine {
    // MARK: - Properties

    public let engine = AVAudioEngine()
    private let sessionManager: AudioSessionManager
    private let settings: BackgroundAudioToggle

    private var isRunning = false

    // Destination node for TrackPlayer (set by AudioService to use masterBusMixer)
    private weak var destinationNode: AVAudioNode?

    /// エンジンの状態
    public var isEngineRunning: Bool { isRunning }

    // MARK: - Initialization

    /// エンジンを初期化
    /// - Parameters:
    ///   - sessionManager: オーディオセッションマネージャー
    ///   - settings: バックグラウンド再生設定
    public init(
        sessionManager: AudioSessionManager = AudioSessionManager(),
        settings: BackgroundAudioToggle = BackgroundAudioToggle()
    ) {
        self.sessionManager = sessionManager
        self.settings = settings

        setupSessionCallbacks()
    }

    // MARK: - Public Methods

    /// エンジンとセッションを設定
    public func configure() throws {

        // オーディオセッションをアクティベート
        // .playback カテゴリを使う（サイレントスイッチを無視）
        do {
            try sessionManager.activate(
                category: .playback,
                options: [.mixWithOthers],
                background: false
            )
        } catch {
            // .playback が失敗したら .ambient を試す
            do {
                try sessionManager.activate(
                    category: .ambient,
                    options: [],
                    background: false
                )
            } catch {
                throw error
            }
        }

    }

    /// Set destination node for TrackPlayer
    /// - Parameter node: Destination audio node (e.g., masterBusMixer)
    public func setDestination(_ node: AVAudioNode) {
        self.destinationNode = node
    }

    /// エンジンを開始
    public func start() throws {
        guard !isRunning else { return }

        // エンジンを開始
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                throw error
            }
        }

        isRunning = true
    }

    /// エンジンを停止
    public func stop() {
        guard isRunning else { return }

        // エンジンを停止
        engine.stop()

        isRunning = false
    }

    /// 全体の音量を設定
    /// - Parameter volume: 音量（0.0〜1.0）
    public func setMasterVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        engine.mainMixerNode.outputVolume = clampedVolume
    }

    // MARK: - Private Methods

    private func setupSessionCallbacks() {
        // 中断開始時の処理
        sessionManager.onInterruptionBegan = { [weak self] in
            self?.stop()
        }

        // 中断終了時の処理
        sessionManager.onInterruptionEnded = { [weak self] shouldResume in
            guard let self = self else { return }

            // ユーザー設定で自動再開が有効 かつ システムが再開を推奨している場合のみ再開
            if self.settings.isAutoResumeEnabled && shouldResume {
                try? self.start()
            }
        }

        // ルート変化時の処理
        sessionManager.onRouteChanged = { [weak self] reason in
            guard let self = self else { return }

            // イヤホン抜けの場合
            if reason == .oldDeviceUnavailable && self.settings.stopOnHeadphoneDisconnect {
                self.stop()
            }
        }
    }
}
