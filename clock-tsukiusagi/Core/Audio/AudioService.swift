//
//  AudioService.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-10.
//  オーディオシステムの統合サービス（Singleton）
//

import AVFoundation
import Combine
import Foundation

/// 停止理由
public enum PauseReason: String, Codable {
    case user                   // ユーザー操作
    case routeSafetySpeaker     // イヤホン抜け→スピーカー（安全停止）
    case quietBreak             // 無音休憩（Phase 2）
    case interruption           // システム中断（電話など）
}

/// オーディオエラー
public enum AudioError: Error, LocalizedError {
    case unsafeToResume(String)
    case sessionActivationFailed(Error)
    case engineStartFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .unsafeToResume(let reason):
            return "再開できません: \(reason)"
        case .sessionActivationFailed(let error):
            return "オーディオセッションの開始に失敗: \(error.localizedDescription)"
        case .engineStartFailed(let error):
            return "オーディオエンジンの開始に失敗: \(error.localizedDescription)"
        }
    }
}

/// オーディオサービス（Singleton）
/// アプリ全体で1つのインスタンスを共有し、画面遷移に関わらず音声再生を継続する
@MainActor
public final class AudioService: ObservableObject {
    // MARK: - Singleton

    public static let shared = AudioService()

    // MARK: - Published Properties

    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentPreset: NaturalSoundPreset?
    @Published public private(set) var outputRoute: AudioOutputRoute = .unknown
    @Published public private(set) var pauseReason: PauseReason?

    // MARK: - Private Properties

    private let engine: LocalAudioEngine
    private let sessionManager: AudioSessionManager
    private let routeMonitor: AudioRouteMonitor
    private var settings: AudioSettings

    private var sessionActivated = false  // セッション二重アクティベート防止フラグ
    private var interruptionObserver: NSObjectProtocol?

    // MARK: - Initialization

    private init() {
        // 設定を読み込み
        self.settings = AudioSettings.load()

        // コンポーネントを初期化
        self.sessionManager = AudioSessionManager()
        self.engine = LocalAudioEngine(
            sessionManager: sessionManager,
            settings: BackgroundAudioToggle()  // 既存のクラスを使用（互換性のため）
        )
        self.routeMonitor = AudioRouteMonitor(settings: settings)

        setupCallbacks()
        setupInterruptionHandling()

        print("🎵 [AudioService] Initialized as singleton")
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        routeMonitor.stop()
    }

    // MARK: - Public Methods

    /// 音声再生を開始
    /// - Parameter preset: 再生するプリセット
    public func play(preset: NaturalSoundPreset) throws {
        print("🎵 [AudioService] play() called with preset: \(preset)")

        // セッションを一度だけアクティベート
        if !sessionActivated {
            do {
                try activateAudioSession()
                sessionActivated = true
            } catch {
                throw AudioError.sessionActivationFailed(error)
            }
        }

        // Note: LocalAudioEngine.configure()は呼ばない
        // セッション管理はAudioServiceで行うため、二重アクティベートを避ける

        // 音源を登録
        do {
            try registerSource(for: preset)
        } catch {
            print("⚠️ [AudioService] Source registration failed: \(error)")
            throw AudioError.engineStartFailed(error)
        }

        // 音量を初期設定
        engine.setMasterVolume(0.5)

        // エンジンを開始
        do {
            try engine.start()
        } catch {
            throw AudioError.engineStartFailed(error)
        }

        // 経路監視を開始
        routeMonitor.start()

        // 状態を更新
        isPlaying = true
        currentPreset = preset
        pauseReason = nil
        outputRoute = routeMonitor.currentRoute

        print("🎵 [AudioService] Playback started successfully")
    }

    /// 音声再生を停止
    /// - Parameter fadeOut: フェードアウト時間（秒）
    public func stop(fadeOut: TimeInterval = 0.5) {
        print("🎵 [AudioService] stop() called")

        // TODO: フェードアウト実装（Phase 2）
        // fadeOut(duration: fadeOut)

        engine.stop()
        routeMonitor.stop()

        isPlaying = false
        currentPreset = nil
        pauseReason = nil

        // セッションはアクティブのまま（高速再開のため）
        print("🎵 [AudioService] Playback stopped")
    }

    /// 音声再生を一時停止
    /// - Parameter reason: 停止理由
    public func pause(reason: PauseReason) {
        print("⚠️ [AudioService] pause() called, reason: \(reason)")

        // TODO: フェードアウト実装（Phase 2）
        // fadeOut(duration: 0.5)

        engine.stop()

        pauseReason = reason
        isPlaying = false

        print("⚠️ [AudioService] Paused with reason: \(reason)")
    }

    /// 音声再生を再開
    public func resume() throws {
        print("🎵 [AudioService] resume() called")

        guard let reason = pauseReason else {
            print("⚠️ [AudioService] No pause reason, cannot resume")
            return
        }

        // 安全性チェック: スピーカー出力での停止の場合
        if reason == .routeSafetySpeaker {
            let currentRoute = routeMonitor.currentRoute
            guard currentRoute != .speaker else {
                print("⚠️ [AudioService] Still on speaker output, unsafe to resume")
                throw AudioError.unsafeToResume("まだスピーカー出力です")
            }
        }

        // エンジンを再開
        do {
            try engine.start()
        } catch {
            throw AudioError.engineStartFailed(error)
        }

        // TODO: フェードイン実装（Phase 2）
        // fadeIn(duration: 0.5)

        isPlaying = true
        pauseReason = nil

        print("🎵 [AudioService] Resumed successfully")
    }

    /// 音量を設定
    /// - Parameter volume: 音量（0.0〜1.0）
    public func setVolume(_ volume: Float) {
        engine.setMasterVolume(volume)
    }

    /// 設定を更新
    /// - Parameter settings: 新しい設定
    public func updateSettings(_ settings: AudioSettings) {
        self.settings = settings
        settings.save()
        print("🎵 [AudioService] Settings updated")
    }

    // MARK: - Private Methods

    private func setupCallbacks() {
        // 経路変更時のコールバック
        routeMonitor.onRouteChanged = { [weak self] route in
            guard let self = self else { return }
            Task { @MainActor in
                self.outputRoute = route
                print("🎧 [AudioService] Route changed to: \(route.displayName) \(route.icon)")
            }
        }

        // スピーカー安全停止のコールバック
        routeMonitor.onSpeakerSafety = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                print("⚠️ [AudioService] Speaker safety triggered - pausing playback")
                self.pause(reason: .routeSafetySpeaker)
            }
        }
    }

    private func setupInterruptionHandling() {
        // システム中断（電話着信、Siriなど）のハンドリング
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            Task { @MainActor in
                switch type {
                case .began:
                    print("⚠️ [AudioService] Interruption began")
                    self.pause(reason: .interruption)

                case .ended:
                    print("🎵 [AudioService] Interruption ended")
                    // 自動再開するかチェック
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) && self.settings.autoResumeAfterInterruption {
                            print("🎵 [AudioService] Auto-resuming after interruption")
                            try? self.resume()
                        }
                    }

                @unknown default:
                    break
                }
            }
        }
    }

    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        print("🎵 [AudioService] Activating audio session...")
        print("   Category: .playback")
        print("   Mode: .default")
        print("   Options: [.mixWithOthers, .allowBluetooth]")

        try session.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers, .allowBluetooth]
        )

        // バッファサイズを設定（低レイテンシ）
        try session.setPreferredIOBufferDuration(0.005)  // 5ms

        try session.setActive(true)

        print("🎵 [AudioService] Audio session activated successfully")
    }

    private func registerSource(for preset: NaturalSoundPreset) throws {
        print("🎵 [AudioService] Registering source for preset: \(preset)")

        switch preset {
        case .comfortRelax:
            let source = ComfortPackDrone(
                noiseType: NaturalSoundPresets.ComfortRelax.noiseType,
                noiseAmplitude: NaturalSoundPresets.ComfortRelax.noiseAmplitude,
                noiseLowpassCutoff: NaturalSoundPresets.ComfortRelax.noiseLowpassCutoff,
                noiseLFOFrequency: NaturalSoundPresets.ComfortRelax.noiseLFOFrequency,
                noiseLFODepth: NaturalSoundPresets.ComfortRelax.noiseLFODepth,
                droneFrequencies: NaturalSoundPresets.ComfortRelax.droneFrequencies,
                droneAmplitude: NaturalSoundPresets.ComfortRelax.droneAmplitude,
                droneDetuneCents: NaturalSoundPresets.ComfortRelax.droneDetuneCents,
                droneLFOFrequency: NaturalSoundPresets.ComfortRelax.droneLFOFrequency,
                reverbWetDryMix: NaturalSoundPresets.ComfortRelax.reverbWetDryMix
            )
            try engine.register(source)
        }
    }

    // TODO: Phase 2 でフェード処理を実装
    // private func fadeOut(duration: TimeInterval) { }
    // private func fadeIn(duration: TimeInterval) { }
}
