//
//  LocalAudioEngine.swift
//  clock-tsukiusagi
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

    /// エンジンの状態
    public var isEngineRunning: Bool { isRunning }

    // MARK: - Initialization

    /// エンジンを初期化
    /// - Parameters:
    ///   - sessionManager: オーディオセッションマネージャー
    ///   - settings: 背景再生設定
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
        print("LocalAudioEngine: Configuring audio session...")
        print("LocalAudioEngine: Background audio enabled: \(settings.isBackgroundAudioEnabled)")

        // オーディオセッションをアクティベート
        // まずシンプルな .ambient カテゴリで試す（Background Modes不要）
        do {
            print("LocalAudioEngine: Trying .ambient category first...")
            try sessionManager.activate(
                category: .ambient,
                options: [],
                background: false
            )
            print("LocalAudioEngine: Audio session activated successfully with .ambient")
        } catch {
            print("LocalAudioEngine: .ambient failed, trying .soloAmbient...")
            // .ambient が失敗したら .soloAmbient を試す
            do {
                try sessionManager.activate(
                    category: .soloAmbient,
                    options: [],
                    background: false
                )
                print("LocalAudioEngine: Audio session activated successfully with .soloAmbient")
            } catch {
                print("LocalAudioEngine: Failed to activate audio session with any category")
                throw error
            }
        }

        print("LocalAudioEngine: configure() completed successfully")
    }

    /// 音源を登録
    /// - Parameter source: 登録する音源
    public func register(_ source: AudioSource) throws {
        print("LocalAudioEngine: Registering audio source...")
        let format = engine.outputNode.inputFormat(forBus: 0)
        print("LocalAudioEngine: Output format - sampleRate: \(format.sampleRate), channels: \(format.channelCount)")

        do {
            try source.attachAndConnect(to: engine, format: format)
            sources.append(source)
            print("LocalAudioEngine: Audio source registered successfully. Total sources: \(sources.count)")
        } catch {
            print("LocalAudioEngine: Failed to register audio source - \(error)")
            throw error
        }
    }

    /// エンジンを開始
    public func start() throws {
        guard !isRunning else {
            print("LocalAudioEngine: Already running, skipping start")
            return
        }

        print("LocalAudioEngine: Starting audio engine...")

        // エンジンを開始
        if !engine.isRunning {
            do {
                try engine.start()
                print("LocalAudioEngine: AVAudioEngine started")
            } catch {
                print("LocalAudioEngine: Failed to start AVAudioEngine - \(error)")
                throw error
            }
        }

        // 全ての音源を開始
        do {
            try sources.forEach { try $0.start() }
            print("LocalAudioEngine: All audio sources started")
        } catch {
            print("LocalAudioEngine: Failed to start audio sources - \(error)")
            throw error
        }

        isRunning = true
        print("LocalAudioEngine: Engine is now running")
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

    /// 全体の音量を設定
    /// - Parameter volume: 音量（0.0〜1.0）
    public func setMasterVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        engine.mainMixerNode.outputVolume = clampedVolume
        print("LocalAudioEngine: Master volume set to \(clampedVolume)")
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
