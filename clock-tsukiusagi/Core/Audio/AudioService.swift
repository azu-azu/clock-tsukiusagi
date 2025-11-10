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
    private let breakScheduler: QuietBreakScheduler
    private let volumeLimiter: SafeVolumeLimiter
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

        // Phase 2: Quiet Break Scheduler
        self.breakScheduler = QuietBreakScheduler(
            isEnabled: settings.quietBreakEnabled,
            playDuration: TimeInterval(settings.playMinutes * 60),
            breakDuration: TimeInterval(settings.breakMinutes * 60),
            fadeDuration: 1.0
        )

        // Phase 2: Safe Volume Limiter
        self.volumeLimiter = SafeVolumeLimiter(
            maxOutputDb: settings.maxOutputDb
        )

        // コールバック設定
        setupCallbacks()
        setupInterruptionHandling()
        setupBreakSchedulerCallbacks()

        // 初期経路を取得して監視開始（起動時から経路変更を検知）
        outputRoute = routeMonitor.currentRoute
        routeMonitor.start()  // 起動時から監視開始

        print("🎵 [AudioService] Initialized as singleton")
        print("   Initial output route: \(outputRoute.displayName) \(outputRoute.icon)")
        print("   Quiet breaks: \(settings.quietBreakEnabled ? "Enabled" : "Disabled")")
        print("   Max output: \(settings.maxOutputDb) dB")
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        routeMonitor.stop()
        breakScheduler.stop()
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

        // Phase 2: 音量リミッターを設定
        let format = engine.engine.outputNode.inputFormat(forBus: 0)
        volumeLimiter.configure(engine: engine.engine, format: format)

        // エンジンを開始
        do {
            try engine.start()
        } catch {
            throw AudioError.engineStartFailed(error)
        }

        // 経路監視は既に起動時に開始済み（init()で実行）

        // Phase 2: Quiet Breakスケジューラーを開始
        breakScheduler.start()

        // 状態を更新
        isPlaying = true
        currentPreset = preset
        pauseReason = nil
        outputRoute = routeMonitor.currentRoute

        print("🎵 [AudioService] Playback started successfully")
    }

    /// 音声再生を停止
    /// - Parameter fadeOut: フェードアウト時間（秒）
    public func stop(fadeOut fadeOutDuration: TimeInterval = 0.5) {
        print("🎵 [AudioService] stop() called")

        // フェードアウト
        self.fadeOut(duration: fadeOutDuration)

        // フェード完了後にエンジンを停止
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) { [weak self] in
            self?.engine.stop()
            print("🎵 [AudioService] Engine stopped after fade")
        }

        // 経路監視は停止しない（常に監視してUIを更新）

        // Phase 2: Quiet Breakスケジューラーを停止
        breakScheduler.stop()

        isPlaying = false
        currentPreset = nil
        pauseReason = nil

        // セッションはアクティブのまま（高速再開のため）
        print("🎵 [AudioService] Playback stopping with fade")
    }

    /// 音声再生を一時停止
    /// - Parameter reason: 停止理由
    public func pause(reason: PauseReason) {
        print("⚠️ [AudioService] pause() called, reason: \(reason)")

        // フェードアウト
        fadeOut(duration: 0.5)

        // フェード完了後にエンジンを停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.engine.stop()
            print("⚠️ [AudioService] Engine stopped after fade")
        }

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

        // フェードイン
        fadeIn(duration: 0.5)

        // Phase 2: Quiet Breakスケジューラーを再開（ただし.quietBreak理由の場合は除く）
        // .quietBreak の場合はスケジューラー自身が自動再開を管理している
        if reason != .quietBreak {
            breakScheduler.start()
        }

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

    private func setupBreakSchedulerCallbacks() {
        // 休憩開始時のコールバック
        breakScheduler.onBreakStart = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                print("⏰ [AudioService] Quiet break started")
                self.pause(reason: .quietBreak)
            }
        }

        // 休憩終了時のコールバック
        breakScheduler.onBreakEnd = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                print("⏰ [AudioService] Quiet break ended - resuming")
                try? self.resume()
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
        print("🎵 [AudioService] Activating audio session...")

        let session = AVAudioSession.sharedInstance()

        print("   Current state:")
        print("     Category: \(session.category.rawValue)")
        print("     Mode: \(session.mode.rawValue)")

        // 既にアクティブかチェック
        let isActive = session.isOtherAudioPlaying
        print("     Is other audio playing: \(isActive)")

        // まずカテゴリだけ設定（アクティブ化前）
        do {
            print("   Setting category to .playback...")
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            print("   ✅ Category set")
        } catch {
            print("   ❌ setCategory failed: \(error)")
            throw error
        }

        // 次にアクティブ化
        do {
            print("   Activating session...")
            try session.setActive(true, options: [])
            print("   ✅ Session activated")
        } catch {
            print("   ❌ setActive failed: \(error)")
            throw error
        }

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

    // MARK: - Fade Effects (Phase 2)

    private var fadeTimer: Timer?
    private var targetVolume: Float = 0.5

    /// 音量をフェードアウト
    /// - Parameter duration: フェード時間（秒）
    private func fadeOut(duration: TimeInterval) {
        fadeTimer?.invalidate()

        let startVolume = engine.engine.mainMixerNode.outputVolume
        targetVolume = startVolume  // 元の音量を記憶

        print("🎵 [AudioService] Fade out: \(startVolume) → 0.0 over \(duration)s")

        let steps = 60  // 60ステップ（60fps想定）
        let stepDuration = duration / Double(steps)
        let volumeStep = startVolume / Float(steps)

        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let newVolume = max(0.0, startVolume - (volumeStep * Float(currentStep)))
            self.engine.setMasterVolume(newVolume)

            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimer = nil
                print("🎵 [AudioService] Fade out complete")
            }
        }
    }

    /// 音量をフェードイン
    /// - Parameter duration: フェード時間（秒）
    private func fadeIn(duration: TimeInterval) {
        fadeTimer?.invalidate()

        let endVolume = targetVolume  // 記憶した音量に戻す

        print("🎵 [AudioService] Fade in: 0.0 → \(endVolume) over \(duration)s")

        let steps = 60  // 60ステップ
        let stepDuration = duration / Double(steps)
        let volumeStep = endVolume / Float(steps)

        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let newVolume = min(endVolume, volumeStep * Float(currentStep))
            self.engine.setMasterVolume(newVolume)

            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimer = nil
                print("🎵 [AudioService] Fade in complete")
            }
        }
    }
}
