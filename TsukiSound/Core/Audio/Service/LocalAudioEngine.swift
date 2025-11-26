//
//  LocalAudioEngine.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-09.
//  メインエンジン・統合管理
//

import AVFoundation
import Foundation

/// ローカル音声合成エンジン
/// 複数の音源を管理し、AVAudioEngineを統合します
public final class LocalAudioEngine {
    // MARK: - Properties

    public let engine = AVAudioEngine()
    private let sessionManager: AudioSessionManager
    private let settings: BackgroundAudioToggle

    private var sources: [AudioSource] = []
    private var isRunning = false
    private var shouldStartSources = true  // 音源の自動起動フラグ

    // Destination node for all sources (set by AudioService to use masterBusMixer)
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

    /// Set destination node for all sources
    /// - Parameter node: Destination audio node (e.g., masterBusMixer)
    public func setDestination(_ node: AVAudioNode) {
        self.destinationNode = node
    }

    /// 音源を登録
    /// - Parameter source: 登録する音源
    public func register(_ source: AudioSource) {
        let format = engine.outputNode.inputFormat(forBus: 0)

        do {
            try source.attachAndConnect(to: engine, format: format)
        } catch {
            return
        }

        if let target = destinationNode {
            engine.disconnectNodeOutput(source.sourceNode)
            engine.connect(source.sourceNode, to: target, format: format)
        }

        sources.append(source)
    }

    /// エンジンを開始
    /// - Parameter startSources: 登録済み音源を起動するかどうか（デフォルト: true）
    public func start(startSources: Bool = true) throws {
        guard !isRunning else {
            return
        }


        // エンジンを開始
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                throw error
            }
        }

        // 音源の自動起動が有効な場合のみ起動
        if startSources && shouldStartSources {
            do {
                try sources.forEach { try $0.start() }
            } catch {
                throw error
            }
        } else {
        }

        isRunning = true
    }

    /// エンジンを停止
    public func stop() {
        guard isRunning else { return }

        // 全ての音源を停止
        sources.forEach { $0.stop() }

        // エンジンを停止
        engine.stop()

        isRunning = false
    }

    /// 音源の自動起動を無効化（TrackPlayer使用時など）
    public func disableSources() {

        // 現在の音源を停止＆サスペンド（ノードは接続されたまま、無音出力）
        sources.forEach {
            $0.stop()
            $0.suspend()  // Silence output + stop diagnostics
        }

        // 次回start()時に音源を起動しない
        shouldStartSources = false

    }

    /// 音源の自動起動を再有効化
    public func enableSources() {

        // Resume all sources (restart audio generation and diagnostics)
        sources.forEach { $0.resume() }

        shouldStartSources = true
    }

    /// すべての音源をクリア（デタッチして削除）
    public func clearSources() {

        // Stop and detach all sources
        sources.forEach {
            $0.stop()
            $0.suspend()
            // Detach the source node from engine
            engine.detach($0.sourceNode)
        }

        // Clear the sources array
        sources.removeAll()

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
