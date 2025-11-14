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
    public let breakScheduler: QuietBreakScheduler  // Public for settings UI access
    private let volumeLimiter: SafeVolumeLimiter
    private var settings: AudioSettings

    // Phase 3: Live Activity
    private var activityController: AudioActivityController?

    // Phase 3: Now Playing Controller
    private var nowPlayingController: NowPlayingController?

    // Phase 3: Track Player (file-based playback)
    private var trackPlayer: TrackPlayer?
    @Published public private(set) var currentAudioFile: AudioFilePreset?

    // System Volume Monitoring
    @Published public private(set) var systemVolume: Float = 1.0
    private var volumeObservation: NSKeyValueObservation?
    private let volumeCapLinear: Float = 0.501187  // -6dB = 10^(-6/20)

    private var sessionActivated = false  // セッション二重アクティベート防止フラグ
    private var interruptionObserver: NSObjectProtocol?

    // Ghost task protection: track pending engine stop work items
    private var engineStopWorkItem: DispatchWorkItem?
    private var playbackSessionId = UUID()  // Generational guard against stale stops

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

        // Phase 3: Live Activity Controller (iOS 16.1+)
        if #available(iOS 16.1, *) {
            self.activityController = AudioActivityController()
        }

        // Phase 3: Now Playing Controller
        self.nowPlayingController = NowPlayingController()

        // Attach limiter nodes to engine BEFORE any connections
        volumeLimiter.attachNodes(to: engine.engine)

        // Set masterBusMixer as destination for all audio sources
        engine.setDestination(volumeLimiter.masterBusMixer)

        // コールバック設定
        setupCallbacks()
        setupInterruptionHandling()
        setupBreakSchedulerCallbacks()
        setupNowPlayingCommands()

        // 初期経路を取得して監視開始（起動時から経路変更を検知）
        outputRoute = routeMonitor.currentRoute
        routeMonitor.start()  // 起動時から監視開始

        // システム音量監視を開始
        setupSystemVolumeMonitoring()

        print("   Initial output route: \(outputRoute.displayName) \(outputRoute.icon)")
        print("   Quiet breaks: \(settings.quietBreakEnabled ? "Enabled" : "Disabled")")
        print("   Max output: \(settings.maxOutputDb) dB")
        print("   Live Activity: \(activityController != nil ? "Available" : "Not Available")")
        print("   System volume monitoring: Enabled")
        print("   Volume cap: \(volumeCapLinear) (-6dB)")
        print("   Audio routing: All sources → masterBusMixer → limiter → mainMixer → output")
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        volumeObservation?.invalidate()
        routeMonitor.stop()
        breakScheduler.stop()
    }

    // MARK: - Public Methods

    /// 音声再生を開始
    /// - Parameter preset: 再生するプリセット
    public func play(preset: NaturalSoundPreset) throws {

        // Wrap entire method in do-catch to ensure state cleanup on error
        do {
            try _playInternal(preset: preset)
        } catch {
            // CRITICAL: Cleanup state on error to unlock UI
            print("❌ [AudioService] play() failed: \(error)")
            cleanupStateOnError()
            throw error
        }
    }

    /// Internal play implementation (allows proper error handling)
    private func _playInternal(preset: NaturalSoundPreset) throws {
        // Cancel any pending stop/fade tasks from previous session
        engineStopWorkItem?.cancel()
        fadeTimer?.invalidate()
        engineStopWorkItem = nil
        fadeTimer = nil

        // Generate new playback session ID
        playbackSessionId = UUID()

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

        // CRITICAL: Clear all previous sources before registering new one
        // This prevents multiple sources from playing simultaneously
        engine.clearSources()

        // Phase 2: Configure limiter BEFORE engine starts (avoid runtime reconfiguration)
        // CRITICAL: Use output format (48kHz/2ch) for consistency across all playback types
        let outputFormat = engine.engine.outputNode.inputFormat(forBus: 0)
        volumeLimiter.configure(engine: engine.engine, format: outputFormat)

        // 音源を登録（masterBusMixerに接続される）
        do {
            try registerSource(for: preset)
        } catch {
            print("⚠️ [AudioService] Source registration failed: \(error)")
            throw AudioError.engineStartFailed(error)
        }

        // エンジンを開始（Limiter設定後）
        do {
            try engine.start()
        } catch {
            throw AudioError.engineStartFailed(error)
        }

        // 音量は動的ゲイン補正で自動設定される（システム音量に基づく）
        applyDynamicGainCompensation()

        // 経路監視は既に起動時に開始済み（init()で実行）

        // Phase 2: Quiet Breakスケジューラーを開始
        breakScheduler.start()

        // 状態を更新
        isPlaying = true
        currentPreset = preset
        pauseReason = nil
        outputRoute = routeMonitor.currentRoute

        // Phase 3: Live Activityを更新
        updateLiveActivity()

        // Phase 3: Now Playingを更新
        updateNowPlaying()
        updateNowPlayingState()

    }

    /// 音声再生を停止して完了を待つ（モード切替用）
    /// - Parameters:
    ///   - fadeOut: フェードアウト時間（秒）
    ///   - completion: 停止完了後のコールバック
    public func stopAndWait(fadeOut fadeOutDuration: TimeInterval = 0.5, completion: @escaping () -> Void) {

        // Prevent duplicate stop() calls (ghost fade-out protection)
        guard isPlaying else {
            print("⚠️ [AudioService] stopAndWait() ignored (not playing)")
            completion()  // Still call completion to unblock caller
            return
        }
        isPlaying = false  // Immediately set to prevent re-entrance

        // 1) Stop individual players first (if any)
        var playerFadeDuration: TimeInterval = 0
        if let player = trackPlayer, player.isPlaying {
            playerFadeDuration = settings.crossfadeDuration
            player.stop(fadeOut: playerFadeDuration)
        }

        // 2) Always fade out master volume (regardless of source type)
        let masterFadeDuration = max(fadeOutDuration, playerFadeDuration)
        self.fadeOut(duration: masterFadeDuration)

        // 3) ALWAYS stop engine after fade (unified behavior)
        // Use cancellable WorkItem to prevent ghost stop tasks
        let stopSessionId = playbackSessionId  // Capture current session ID
        engineStopWorkItem?.cancel()  // Cancel any pending stop from previous session

        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Ghost task protection: ignore if session has changed
            guard stopSessionId == self.playbackSessionId else {
                print("🛑 [AudioService] Stale stop ignored (session changed)")
                completion()  // Still call completion to unblock caller
                return
            }

            // Stop engine completely
            self.engine.stop()
            self.volumeLimiter.reset()

            // Disable sources (suspends timers, keeps nodes attached)
            self.engine.disableSources()


            // 4) Cleanup state and auxiliary features
            self.breakScheduler.stop()

            // isPlaying already set to false at the beginning of stopAndWait()
            self.currentPreset = nil
            self.currentAudioFile = nil
            self.pauseReason = nil

            // Phase 3: Live Activityを終了
            self.endLiveActivity()

            // Phase 3: Now Playingをクリア
            self.nowPlayingController?.clearNowPlaying()


            // Call completion handler
            completion()
        }

        engineStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + masterFadeDuration, execute: workItem)
    }

    /// 音声再生を停止
    /// - Parameter fadeOut: フェードアウト時間（秒）
    public func stop(fadeOut fadeOutDuration: TimeInterval = 0.5) {

        // Prevent duplicate stop() calls (ghost fade-out protection)
        guard isPlaying else {
            print("⚠️ [AudioService] stop() ignored (not playing)")
            return
        }
        isPlaying = false  // Immediately set to prevent re-entrance

        // 1) Stop individual players first (if any)
        var playerFadeDuration: TimeInterval = 0
        if let player = trackPlayer, player.isPlaying {
            playerFadeDuration = settings.crossfadeDuration
            player.stop(fadeOut: playerFadeDuration)
        }

        // 2) Always fade out master volume (regardless of source type)
        let masterFadeDuration = max(fadeOutDuration, playerFadeDuration)
        self.fadeOut(duration: masterFadeDuration)

        // 3) ALWAYS stop engine after fade (unified behavior)
        // Use cancellable WorkItem to prevent ghost stop tasks
        let stopSessionId = playbackSessionId  // Capture current session ID
        engineStopWorkItem?.cancel()  // Cancel any pending stop from previous session

        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Ghost task protection: ignore if session has changed
            guard stopSessionId == self.playbackSessionId else {
                print("🛑 [AudioService] Stale stop ignored (session changed)")
                return
            }

            // Stop engine completely
            self.engine.stop()
            self.volumeLimiter.reset()

            // Disable sources (suspends timers, keeps nodes attached)
            self.engine.disableSources()

        }

        engineStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + masterFadeDuration, execute: workItem)

        // 4) Cleanup state and auxiliary features
        breakScheduler.stop()

        // isPlaying already set to false at the beginning of stop()
        currentPreset = nil
        currentAudioFile = nil
        pauseReason = nil

        // Phase 3: Live Activityを終了
        endLiveActivity()

        // Phase 3: Now Playingをクリア
        nowPlayingController?.clearNowPlaying()

    }

    /// 音声再生を一時停止
    /// - Parameter reason: 停止理由
    public func pause(reason: PauseReason) {
        print("⚠️ [AudioService] pause() called, reason: \(reason)")

        // フェードアウト
        fadeOut(duration: 0.5)

        // フェード完了後にエンジンを停止（幽霊タスク防止）
        let pauseSessionId = playbackSessionId
        engineStopWorkItem?.cancel()

        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Ghost task protection
            guard pauseSessionId == self.playbackSessionId else {
                print("🛑 [AudioService] Stale pause-stop ignored (session changed)")
                return
            }

            self.engine.stop()
            print("⚠️ [AudioService] Engine stopped after fade")
        }

        engineStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)

        pauseReason = reason
        isPlaying = false

        // Phase 3: Live Activityを更新
        updateLiveActivity()

        // Phase 3: Now Playing状態を更新
        updateNowPlayingState()

        print("⚠️ [AudioService] Paused with reason: \(reason)")
    }

    /// 音声再生を再開
    public func resume() throws {

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

        // Phase 3: Live Activityを更新
        updateLiveActivity()

        // Phase 3: Now Playing状態を更新
        updateNowPlayingState()

    }

    /// 音量を設定（非推奨：システム音量で自動制御されます）
    /// - Parameter volume: 音量（0.0〜1.0）
    @available(*, deprecated, message: "音量はシステム音量（端末ボタン）で制御されます。このメソッドは無視されます。")
    public func setVolume(_ volume: Float) {
        print("⚠️ [AudioService] setVolume() is deprecated. Volume is now controlled by system volume.")
        // Do nothing - volume is automatically controlled by dynamic gain compensation
    }

    /// 設定を更新
    /// - Parameter settings: 新しい設定
    public func updateSettings(_ settings: AudioSettings) {
        self.settings = settings
        settings.save()
    }

    // MARK: - Private Methods

    /// Cleanup state on error to unlock UI
    private func cleanupStateOnError() {
        print("🧹 [AudioService] Cleaning up state after error")

        // Cancel any pending stop/fade tasks
        engineStopWorkItem?.cancel()
        fadeTimer?.invalidate()
        engineStopWorkItem = nil
        fadeTimer = nil

        // Reset playback state
        isPlaying = false
        currentPreset = nil
        currentAudioFile = nil
        pauseReason = nil

        // Stop engine if running
        if engine.isEngineRunning {
            engine.stop()
        }

        // Reset limiter
        volumeLimiter.reset()

        // Clear Live Activity
        endLiveActivity()

        // Clear Now Playing
        nowPlayingController?.clearNowPlaying()

        print("🧹 [AudioService] State cleanup complete")
    }

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

    private func setupNowPlayingCommands() {
        nowPlayingController?.setupRemoteCommands(
            onPlay: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self, let preset = self.currentPreset else { return }
                    try? self.play(preset: preset)
                }
            },
            onPause: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.pause(reason: .user)
                }
            },
            onStop: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.stop()
                }
            }
        )
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
                    // 自動再開するかチェック
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) && self.settings.autoResumeAfterInterruption {
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

    }

    private func registerSource(for preset: NaturalSoundPreset) throws {

        switch preset {
        case .clickSuppression:
            let source = ClickSuppressionDrone(
                noiseType: NaturalSoundPresets.ClickSuppression.noiseType,
                noiseAmplitude: NaturalSoundPresets.ClickSuppression.noiseAmplitude,
                noiseLowpassCutoff: NaturalSoundPresets.ClickSuppression.noiseLowpassCutoff,
                noiseLFOFrequency: NaturalSoundPresets.ClickSuppression.noiseLFOFrequency,
                noiseLFODepth: NaturalSoundPresets.ClickSuppression.noiseLFODepth,
                droneFrequencies: NaturalSoundPresets.ClickSuppression.droneFrequencies,
                droneAmplitude: NaturalSoundPresets.ClickSuppression.droneAmplitude,
                droneDetuneCents: NaturalSoundPresets.ClickSuppression.droneDetuneCents,
                droneLFOFrequency: NaturalSoundPresets.ClickSuppression.droneLFOFrequency,
                reverbWetDryMix: NaturalSoundPresets.ClickSuppression.reverbWetDryMix
            )
            engine.register(source)

        case .pinkNoise:
            let source = PinkNoise(
                amplitude: NaturalSoundPresets.PinkNoise.amplitude
            )
            engine.register(source)

        case .brownNoise:
            let source = BrownNoise(
                amplitude: NaturalSoundPresets.BrownNoise.amplitude
            )
            engine.register(source)

        case .pleasantDrone:
            let source = PleasantDrone(
                rootFrequency: NaturalSoundPresets.PleasantDrone.rootFrequency,
                chordType: NaturalSoundPresets.PleasantDrone.chordType,
                amplitude: NaturalSoundPresets.PleasantDrone.amplitude,
                amplitudeLFOFrequency: NaturalSoundPresets.PleasantDrone.amplitudeLFOFrequency,
                pitchLFOFrequency: NaturalSoundPresets.PleasantDrone.pitchLFOFrequency,
                pitchLFODepth: NaturalSoundPresets.PleasantDrone.pitchLFODepth,
                noiseLevel: NaturalSoundPresets.PleasantDrone.noiseLevel
            )
            engine.register(source)

        case .pleasantWarm:
            let source = DetunedOscillator(
                baseFrequency: NaturalSoundPresets.PleasantWarm.baseFrequency,
                detuneAmount: NaturalSoundPresets.PleasantWarm.detuneAmount,
                oscillatorCount: NaturalSoundPresets.PleasantWarm.oscillatorCount,
                amplitude: NaturalSoundPresets.PleasantWarm.amplitude,
                noiseLevel: NaturalSoundPresets.PleasantWarm.noiseLevel
            )
            engine.register(source)

        case .pleasantCalm:
            let source = DetunedOscillator(
                baseFrequency: NaturalSoundPresets.PleasantCalm.baseFrequency,
                detuneAmount: NaturalSoundPresets.PleasantCalm.detuneAmount,
                oscillatorCount: NaturalSoundPresets.PleasantCalm.oscillatorCount,
                amplitude: NaturalSoundPresets.PleasantCalm.amplitude,
                noiseLevel: NaturalSoundPresets.PleasantCalm.noiseLevel
            )
            engine.register(source)

        case .pleasantDeep:
            let source = DetunedOscillator(
                baseFrequency: NaturalSoundPresets.PleasantDeep.baseFrequency,
                detuneAmount: NaturalSoundPresets.PleasantDeep.detuneAmount,
                oscillatorCount: NaturalSoundPresets.PleasantDeep.oscillatorCount,
                amplitude: NaturalSoundPresets.PleasantDeep.amplitude,
                noiseLevel: NaturalSoundPresets.PleasantDeep.noiseLevel
            )
            engine.register(source)

        case .ambientFocus:
            let source = AmbientDrone(
                noiseType: NaturalSoundPresets.AmbientFocus.noiseType,
                noiseAmplitude: NaturalSoundPresets.AmbientFocus.noiseAmplitude,
                sineFrequencies: NaturalSoundPresets.AmbientFocus.sineFrequencies,
                sineAmplitude: NaturalSoundPresets.AmbientFocus.sineAmplitude,
                detuneAmount: NaturalSoundPresets.AmbientFocus.detuneAmount,
                lfoAmplitudeFrequency: NaturalSoundPresets.AmbientFocus.lfoAmplitudeFrequency,
                lfoAmplitudeDepth: NaturalSoundPresets.AmbientFocus.lfoAmplitudeDepth
            )
            engine.register(source)

        case .ambientRelax:
            let source = AmbientDrone(
                noiseType: NaturalSoundPresets.AmbientRelax.noiseType,
                noiseAmplitude: NaturalSoundPresets.AmbientRelax.noiseAmplitude,
                sineFrequencies: NaturalSoundPresets.AmbientRelax.sineFrequencies,
                sineAmplitude: NaturalSoundPresets.AmbientRelax.sineAmplitude,
                detuneAmount: NaturalSoundPresets.AmbientRelax.detuneAmount,
                lfoAmplitudeFrequency: NaturalSoundPresets.AmbientRelax.lfoAmplitudeFrequency,
                lfoAmplitudeDepth: NaturalSoundPresets.AmbientRelax.lfoAmplitudeDepth
            )
            engine.register(source)

        case .ambientSleep:
            let source = AmbientDrone(
                noiseType: NaturalSoundPresets.AmbientSleep.noiseType,
                noiseAmplitude: NaturalSoundPresets.AmbientSleep.noiseAmplitude,
                sineFrequencies: NaturalSoundPresets.AmbientSleep.sineFrequencies,
                sineAmplitude: NaturalSoundPresets.AmbientSleep.sineAmplitude,
                detuneAmount: NaturalSoundPresets.AmbientSleep.detuneAmount,
                lfoAmplitudeFrequency: NaturalSoundPresets.AmbientSleep.lfoAmplitudeFrequency,
                lfoAmplitudeDepth: NaturalSoundPresets.AmbientSleep.lfoAmplitudeDepth
            )
            engine.register(source)

        case .windChime:
            let source = WindChime(
                frequencies: NaturalSoundPresets.WindChime.frequencies,
                amplitude: NaturalSoundPresets.WindChime.amplitude,
                minInterval: NaturalSoundPresets.WindChime.minInterval,
                maxInterval: NaturalSoundPresets.WindChime.maxInterval,
                attackTime: NaturalSoundPresets.WindChime.attackTime,
                decayTime: NaturalSoundPresets.WindChime.decayTime,
                sustainLevel: NaturalSoundPresets.WindChime.sustainLevel,
                releaseTime: NaturalSoundPresets.WindChime.releaseTime
            )
            engine.register(source)

        case .tibetanBowl:
            let source = TibetanBowl(
                fundamentalFrequency: NaturalSoundPresets.TibetanBowl.fundamentalFrequency,
                amplitude: NaturalSoundPresets.TibetanBowl.amplitude,
                harmonics: NaturalSoundPresets.TibetanBowl.harmonics,
                vibratoFrequency: NaturalSoundPresets.TibetanBowl.vibratoFrequency,
                vibratoDepth: NaturalSoundPresets.TibetanBowl.vibratoDepth
            )
            engine.register(source)

        case .oceanWaves:
            let source = OceanWaves(
                noiseAmplitude: NaturalSoundPresets.OceanWaves.noiseAmplitude,
                lfoFrequency: NaturalSoundPresets.OceanWaves.lfoFrequency,
                lfoDepth: NaturalSoundPresets.OceanWaves.lfoDepth,
                lfoMinimum: NaturalSoundPresets.OceanWaves.lfoMinimum,
                lfoMaximum: NaturalSoundPresets.OceanWaves.lfoMaximum
            )
            engine.register(source)

        case .oceanWavesSeagulls:
            let source = OceanWavesSeagulls(
                noiseAmplitude: NaturalSoundPresets.OceanWavesSeagulls.noiseAmplitude,
                lfoFrequency: NaturalSoundPresets.OceanWavesSeagulls.lfoFrequency,
                lfoMinimum: NaturalSoundPresets.OceanWavesSeagulls.lfoMinimum,
                lfoMaximum: NaturalSoundPresets.OceanWavesSeagulls.lfoMaximum,
                birdAmplitude: NaturalSoundPresets.OceanWavesSeagulls.birdAmplitude,
                birdMinInterval: NaturalSoundPresets.OceanWavesSeagulls.birdMinInterval,
                birdMaxInterval: NaturalSoundPresets.OceanWavesSeagulls.birdMaxInterval,
                birdMinDuration: NaturalSoundPresets.OceanWavesSeagulls.birdMinDuration,
                birdMaxDuration: NaturalSoundPresets.OceanWavesSeagulls.birdMaxDuration,
                birdFrequencyRange: NaturalSoundPresets.OceanWavesSeagulls.birdFrequencyRange,
                maxConcurrentChirps: NaturalSoundPresets.OceanWavesSeagulls.maxConcurrentChirps
            )
            engine.register(source)

        case .cracklingFire:
            let source = CracklingFire(
                baseAmplitude: NaturalSoundPresets.CracklingFire.baseAmplitude,
                pulseAmplitude: NaturalSoundPresets.CracklingFire.pulseAmplitude,
                minInterval: NaturalSoundPresets.CracklingFire.pulseMinInterval,
                maxInterval: NaturalSoundPresets.CracklingFire.pulseMaxInterval,
                minPulseDuration: NaturalSoundPresets.CracklingFire.pulseMinDuration,
                maxPulseDuration: NaturalSoundPresets.CracklingFire.pulseMaxDuration
            )
            engine.register(source)
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


        let steps = 60  // 60ステップ（60fps想定）
        let stepDuration = duration / Double(steps)
        let volumeStep = startVolume / Float(steps)

        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                currentStep += 1
                let newVolume = max(0.0, startVolume - (volumeStep * Float(currentStep)))
                self.engine.setMasterVolume(newVolume)

                if currentStep >= steps {
                    timer.invalidate()
                    self.fadeTimer = nil
                }
            }
        }
    }

    /// 音量をフェードイン
    /// - Parameter duration: フェード時間（秒）
    private func fadeIn(duration: TimeInterval) {
        fadeTimer?.invalidate()

        let endVolume = targetVolume  // 記憶した音量に戻す


        let steps = 60  // 60ステップ
        let stepDuration = duration / Double(steps)
        let volumeStep = endVolume / Float(steps)

        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                currentStep += 1
                let newVolume = min(endVolume, volumeStep * Float(currentStep))
                self.engine.setMasterVolume(newVolume)

                if currentStep >= steps {
                    timer.invalidate()
                    self.fadeTimer = nil
                }
            }
        }
    }

    // MARK: - Live Activity Integration

    /// Update Live Activity with current state
    private func updateLiveActivity() {
        guard #available(iOS 16.1, *), settings.liveActivityEnabled else { return }
        guard let controller = activityController else { return }

        let route = outputRoute.displayName
        let nextBreak = breakScheduler.nextBreakAt
        let presetName = currentPreset.map { "\($0)" }  // Convert enum to string

        if isPlaying {
            // Start or update activity
            if !controller.isActivityActive {
                controller.startActivity(
                    isPlaying: true,
                    nextBreakAt: nextBreak,
                    outputRoute: route,
                    pauseReason: nil,
                    presetName: presetName
                )
            } else {
                controller.updateActivity(
                    isPlaying: true,
                    nextBreakAt: nextBreak,
                    outputRoute: route,
                    pauseReason: nil,
                    presetName: presetName
                )
            }
        } else {
            // Update with paused state
            if controller.isActivityActive {
                controller.updateActivity(
                    isPlaying: false,
                    nextBreakAt: nextBreak,
                    outputRoute: route,
                    pauseReason: pauseReason?.rawValue,
                    presetName: presetName
                )
            }
        }
    }

    /// End Live Activity
    private func endLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        activityController?.endActivity(after: 3.0)  // Keep visible for 3 seconds
    }

    // MARK: - Now Playing Integration

    /// Update Now Playing info in Control Center
    private func updateNowPlaying() {
        guard let preset = currentPreset else {
            nowPlayingController?.clearNowPlaying()
            return
        }

        let title = "\(preset)"  // Convert enum to string
        nowPlayingController?.updateNowPlaying(
            title: title,
            artist: "Clock Tsukiusagi",
            album: "Natural Sound Drones",
            artwork: nil,  // TODO: Add app icon or preset-specific artwork
            duration: nil, // Infinite duration for continuous playback
            elapsedTime: 0
        )
    }

    /// Update Now Playing playback state
    private func updateNowPlayingState() {
        nowPlayingController?.updatePlaybackState(isPlaying: isPlaying)
    }

    // MARK: - System Volume Monitoring

    /// Setup system volume monitoring with KVO
    private func setupSystemVolumeMonitoring() {
        let audioSession = AVAudioSession.sharedInstance()

        // Get initial system volume
        systemVolume = audioSession.outputVolume

        // Apply initial gain compensation
        applyDynamicGainCompensation()

        // Observe system volume changes via KVO
        volumeObservation = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] session, change in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let newVolume = change.newValue {
                    self.systemVolume = newVolume
                    self.applyDynamicGainCompensation()

                }
            }
        }

        print("   Current system volume: \(String(format: "%.2f", systemVolume)) (\(Int(systemVolume * 100))%)")
    }

    /// Apply dynamic gain compensation to maintain volume cap
    /// Formula: appGain = min(1.0, cap / max(systemVolume, ε))
    /// Result: systemVolume × appGain ≤ cap (0.501187 = -6dB)
    private func applyDynamicGainCompensation() {
        let epsilon: Float = 0.0001  // Avoid division by zero
        let systemVol = max(systemVolume, epsilon)

        // Calculate compensated app gain
        let compensatedGain = min(1.0, volumeCapLinear / systemVol)

        // Apply to main mixer
        engine.setMasterVolume(compensatedGain)

        let finalVolume = systemVol * compensatedGain
        let finalDb = 20.0 * log10(max(finalVolume, epsilon))

        print("   System volume: \(String(format: "%.4f", systemVol)) (\(Int(systemVol * 100))%)")
        print("   App gain: \(String(format: "%.4f", compensatedGain)) (\(Int(compensatedGain * 100))%)")
        print("   Final output: \(String(format: "%.4f", finalVolume)) (\(String(format: "%.1f", finalDb)) dB)")
        print("   Cap: \(String(format: "%.4f", volumeCapLinear)) (-6.0 dB)")

        if finalVolume > volumeCapLinear + 0.001 {
            print("   ⚠️  WARNING: Final volume exceeds cap!")
        } else {
            print("   ✅ Within safe limit")
        }
    }

    // MARK: - Track Player (File-based Playback)

    /// Play audio file using TrackPlayer
    /// - Parameter audioFile: Audio file preset to play
    /// - Throws: Audio errors
    public func playAudioFile(_ audioFile: AudioFilePreset) throws {

        // CRITICAL: Activate session BEFORE getting output format
        // This ensures outputNode.inputFormat returns correct device format (48kHz/2ch)
        if !sessionActivated {
            do {
                try activateAudioSession()
                sessionActivated = true
            } catch {
                throw AudioError.sessionActivationFailed(error)
            }
        }

        // Wrap entire method in do-catch to ensure state cleanup on error
        do {
            try _playAudioFileInternal(audioFile)
        } catch {
            // CRITICAL: Cleanup state on error to unlock UI
            print("❌ [AudioService] playAudioFile() failed: \(error)")
            cleanupStateOnError()
            throw error
        }
    }

    /// Internal playAudioFile implementation (allows proper error handling)
    private func _playAudioFileInternal(_ audioFile: AudioFilePreset) throws {
        // Cancel any pending stop/fade tasks from previous session
        engineStopWorkItem?.cancel()
        fadeTimer?.invalidate()
        engineStopWorkItem = nil
        fadeTimer = nil

        // Generate new playback session ID
        playbackSessionId = UUID()

        // Stop any currently playing audio (synthesis or file)
        if isPlaying {
            engine.stop()
            volumeLimiter.reset()  // Reset limiter when stopping
            isPlaying = false
            currentPreset = nil
            currentAudioFile = nil
        }

        // Always stop engine to reset audio graph for file playback
        if engine.isEngineRunning {
            engine.stop()
            volumeLimiter.reset()  // Reset limiter when stopping
        }

        // Disable synthesis sources for file playback (but don't detach nodes)
        engine.disableSources()

        // Get audio file URL
        guard let url = audioFile.url() else {
            throw AudioError.engineStartFailed(NSError(domain: "AudioService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Audio file not found: \(audioFile.rawValue)"
            ]))
        }

        // Get audio file format first
        let file = try AVAudioFile(forReading: url)

        // Use file's processing format (AVAudioEngine will handle conversion at mixer)
        let fileFormat = file.processingFormat

        print("   File format: \(file.fileFormat.commonFormat.rawValue) (storage format)")
        print("   Processing format: \(fileFormat.commonFormat.rawValue), \(fileFormat.sampleRate) Hz, \(fileFormat.channelCount) ch")
        print("   ⚠️  masterBusMixer will automatically convert to output format")

        // Phase 2: Configure SafeVolumeLimiter BEFORE engine starts
        // CRITICAL: Use OUTPUT format (48kHz/2ch), NOT file format
        // This maintains consistent format throughout the limiter chain
        // Format conversion happens at masterBusMixer (accepts any file format)
        let outputFormat = engine.engine.outputNode.inputFormat(forBus: 0)

        // CRITICAL: Reset limiter configuration state to prevent buffer reuse
        // This ensures fresh audio graph for each file switch
        volumeLimiter.resetConfigurationState()
        volumeLimiter.configure(engine: engine.engine, format: outputFormat)

        print("   Sample rate: \(outputFormat.sampleRate) Hz")
        print("   Channels: \(outputFormat.channelCount)")

        // CRITICAL: Reconfigure TrackPlayer for EVERY file switch
        // This prevents audio buffer cache reuse between different files
        if trackPlayer == nil {
            trackPlayer = TrackPlayer()
        }

        // Detach TrackPlayer node if already attached (force fresh connection)
        if let playerNode = trackPlayer?.playerNode, engine.engine.attachedNodes.contains(playerNode) {
            engine.engine.detach(playerNode)
        }

        // Configure TrackPlayer to connect to masterBusMixer (not mainMixer directly)
        // TrackPlayer uses file's native format, masterBusMixer will convert
        trackPlayer?.configure(
            engine: engine.engine,
            format: fileFormat,
            destination: volumeLimiter.masterBusMixer
        )


        // Start engine (after limiter configuration)
        // Don't start synthesis sources (startSources: false)
        try engine.start(startSources: false)

        // Load audio file
        try trackPlayer?.load(url: url)

        // Start playback with loop settings
        let settings = audioFile.loopSettings
        trackPlayer?.play(loop: settings.shouldLoop, crossfadeDuration: settings.crossfadeDuration)

        // Update state
        isPlaying = true
        currentAudioFile = audioFile
        currentPreset = nil  // File-based playback doesn't use presets
        pauseReason = nil

        // Route monitoring is already running from init

        // Start quiet break scheduler
        breakScheduler.start()

        // Fade in
        fadeIn(duration: settings.fadeInDuration)

        // Update Live Activity
        updateLiveActivity()

        // Update Now Playing
        updateNowPlaying()
        updateNowPlayingState()

    }

}
