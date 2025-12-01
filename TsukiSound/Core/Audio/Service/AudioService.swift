//
//  AudioService.swift
//  TsukiSound
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

    // MARK: - SignalEngine Source Wrapper

    /// Internal wrapper to handle fade/reset consistently across SignalEngine nodes
    private enum SignalEngineSource {
        case signal(SignalAudioSource)
        case mixer(FinalMixerOutputNode)

        func applyFadeIn(durationMs: Int) {
            switch self {
            case .signal(let source):
                source.applyFadeIn(durationMs: durationMs)
            case .mixer(let node):
                node.applyFadeIn(durationMs: durationMs)
            }
        }

        func applyFadeOut(durationMs: Int) {
            switch self {
            case .signal(let source):
                source.applyFadeOut(durationMs: durationMs)
            case .mixer(let node):
                node.applyFadeOut(durationMs: durationMs)
            }
        }

        func clearFade() {
            switch self {
            case .signal(let source):
                source.clearFade()
            case .mixer(let node):
                node.clearFade()
            }
        }

        func resetEffectsState() {
            switch self {
            case .signal(let source):
                source.resetEffectsState()
            case .mixer(let node):
                node.resetEffectsState()
            }
        }
    }

    // MARK: - Published Properties

    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentPreset: UISoundPreset?
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

    // System Volume Monitoring
    @Published public private(set) var systemVolume: Float = 1.0
    private var volumeObservation: NSKeyValueObservation?
    private let volumeCapLinear: Float = 0.75  // -2.5dB (was -6dB, increased for better audibility)

    private var sessionActivated = false  // セッション二重アクティベート防止フラグ
    private var interruptionObserver: NSObjectProtocol?

    // Ghost task protection: track pending engine stop work items
    private var engineStopWorkItem: DispatchWorkItem?
    private var playbackSessionId = UUID()  // Generational guard against stale stops

    // SignalEngine fade control
    private var currentSignalSource: SignalEngineSource?

    // Preset switching protection: prevent multiple concurrent stop requests
    private var isStopping = false

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

        // Activate audio session before setting up remote commands
        // This ensures MPRemoteCommandCenter can properly register lock screen controls
        do {
            try activateAudioSession()
            sessionActivated = true
        } catch {
            // Continue anyway - will retry on first play()
        }

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
    public func play(preset: UISoundPreset) throws {
        // CRITICAL: 前のセッションのフェードアウトを即座に無効化
        // これにより stopAndWait → play の流れでも前のフェードが新しい再生を邪魔しない
        fadeEnabled = false
        fadeTimer?.invalidate()
        fadeTimer = nil

        // Wrap entire method in do-catch to ensure state cleanup on error
        do {
            try _playInternal(preset: preset)
        } catch {
            // CRITICAL: Cleanup state on error to unlock UI
            cleanupStateOnError()
            throw error
        }
    }

    /// Internal play implementation (allows proper error handling)
    private func _playInternal(preset: UISoundPreset) throws {
        // Cancel any pending stop tasks from previous session
        // Note: fadeTimer は play() で既にキャンセル済み
        engineStopWorkItem?.cancel()
        engineStopWorkItem = nil

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

        // 遅延後にfadeEnabledを再有効化（stopAndWait→play の流れで無効化されているため）
        let currentSessionId = playbackSessionId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self, currentSessionId == self.playbackSessionId else { return }
            self.fadeEnabled = true
        }

        // 経路監視は既に起動時に開始済み（init()で実行）

        // Phase 2: Quiet Breakスケジューラーを開始
        breakScheduler.start()

        // 状態を更新
        isPlaying = true
        currentPreset = preset
        pauseReason = nil
        outputRoute = routeMonitor.currentRoute

        // Phase 3: Live Activityを更新
        // Disabled: Now Playing provides sufficient lock screen integration
        // updateLiveActivity()

        // Phase 3: Now Playingを更新
        updateNowPlaying()
        updateNowPlayingState()

    }

    /// 音声再生を停止して完了を待つ（モード切替用）
    /// - Parameters:
    ///   - fadeOut: フェードアウト時間（秒）
    ///   - completion: 停止完了後のコールバック
    public func stopAndWait(fadeOut fadeOutDuration: TimeInterval = 0.5, completion: @escaping () -> Void) {

        // Prevent concurrent stop requests (preset switching protection)
        guard !isStopping else {
            completion()  // Still call completion to unblock caller
            return
        }

        // Prevent duplicate stop() calls (ghost fade-out protection)
        guard isPlaying else {
            completion()  // Still call completion to unblock caller
            return
        }
        isPlaying = false  // Immediately set to prevent re-entrance
        isStopping = true  // Mark as stopping to prevent concurrent requests

        // Apply fade out to SignalAudioSource
        currentSignalSource?.applyFadeOut(durationMs: Int(fadeOutDuration * 1000))

        // Fade out master volume
        self.fadeOut(duration: fadeOutDuration)

        // ALWAYS stop engine after fade (unified behavior)
        // Use cancellable WorkItem to prevent ghost stop tasks
        let stopSessionId = playbackSessionId  // Capture current session ID
        engineStopWorkItem?.cancel()  // Cancel any pending stop from previous session

        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Ghost task protection: ignore if session has changed
            guard stopSessionId == self.playbackSessionId else {
                completion()  // Still call completion to unblock caller
                return
            }

            // Stop engine completely
            self.engine.stop()
            self.volumeLimiter.reset()

            // Disable sources (suspends timers, keeps nodes attached)
            self.engine.disableSources()

            // Reset effect state to avoid tail carry-over
            self.currentSignalSource?.resetEffectsState()


            // Cleanup state and auxiliary features
            self.breakScheduler.stop()

            // isPlaying already set to false at the beginning of stopAndWait()
            self.currentPreset = nil
            self.clearCurrentSignalSource()
            self.pauseReason = nil

            // Phase 3: Live Activityを終了
            // Disabled: Now Playing provides sufficient lock screen integration
            // self.endLiveActivity()

            // Phase 3: Now Playingをクリア
            self.nowPlayingController?.clearNowPlaying()

            // Reset stopping flag
            self.isStopping = false

            // Call completion handler
            completion()
        }

        engineStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration, execute: workItem)
    }

    /// 音声再生を停止
    /// - Parameter fadeOut: フェードアウト時間（秒）
    public func stop(fadeOut fadeOutDuration: TimeInterval = 0.5) {

        // Prevent duplicate stop() calls (ghost fade-out protection)
        guard isPlaying else {
            return
        }
        isPlaying = false  // Immediately set to prevent re-entrance

        // Apply fade out to SignalAudioSource
        currentSignalSource?.applyFadeOut(durationMs: Int(fadeOutDuration * 1000))

        // Fade out master volume
        self.fadeOut(duration: fadeOutDuration)

        // ALWAYS stop engine after fade (unified behavior)
        // Use cancellable WorkItem to prevent ghost stop tasks
        let stopSessionId = playbackSessionId  // Capture current session ID
        engineStopWorkItem?.cancel()  // Cancel any pending stop from previous session

        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Ghost task protection: ignore if session has changed
            guard stopSessionId == self.playbackSessionId else {
                return
            }

            // Stop engine completely
            self.engine.stop()
            self.volumeLimiter.reset()

            // Disable sources (suspends timers, keeps nodes attached)
            self.engine.disableSources()

            // Reset effect state to avoid tail carry-over
            self.currentSignalSource?.resetEffectsState()

            // Clear SignalEngine reference after reset
            self.clearCurrentSignalSource()

        }

        engineStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration, execute: workItem)

        // Cleanup state and auxiliary features
        breakScheduler.stop()

        // isPlaying already set to false at the beginning of stop()
        currentPreset = nil
        pauseReason = nil

        // Phase 3: Live Activityを終了
        // Disabled: Now Playing provides sufficient lock screen integration
        // endLiveActivity()

        // Phase 3: Now Playingをクリア
        nowPlayingController?.clearNowPlaying()

    }

    /// 音声再生を一時停止
    /// - Parameter reason: 停止理由
    public func pause(reason: PauseReason) {
        // Apply per-source fade to match master fade timing
        currentSignalSource?.applyFadeOut(durationMs: 500)

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
                return
            }

            self.engine.stop()
            self.currentSignalSource?.resetEffectsState()
        }

        engineStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)

        pauseReason = reason
        isPlaying = false

        // Phase 3: Live Activityを更新
        // Disabled: Now Playing provides sufficient lock screen integration
        // updateLiveActivity()

        // Phase 3: Now Playing状態を更新
        updateNowPlayingState()
    }

    /// 音声再生を再開
    public func resume() throws {

        guard let reason = pauseReason else {
            return
        }

        // 安全性チェック: スピーカー出力での停止の場合
        if reason == .routeSafetySpeaker {
            let currentRoute = routeMonitor.currentRoute
            guard currentRoute != .speaker else {
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
        // Disabled: Now Playing provides sufficient lock screen integration
        // updateLiveActivity()

        // Phase 3: Now Playing状態を更新
        updateNowPlayingState()

    }

    /// 音量を設定（非推奨：システム音量で自動制御されます）
    /// - Parameter volume: 音量（0.0〜1.0）
    @available(*, deprecated, message: "音量はシステム音量（端末ボタン）で制御されます。このメソッドは無視されます。")
    public func setVolume(_ volume: Float) {
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

        // Cancel any pending stop/fade tasks
        engineStopWorkItem?.cancel()
        fadeTimer?.invalidate()
        engineStopWorkItem = nil
        fadeTimer = nil

        // Reset playback state
        isPlaying = false
        currentPreset = nil
        resetCurrentSignalEffectsState()
        clearCurrentSignalSource()
        pauseReason = nil

        // Stop engine if running
        if engine.isEngineRunning {
            engine.stop()
        }

        // Reset limiter
        volumeLimiter.reset()

        // Clear Live Activity
        // Disabled: Now Playing provides sufficient lock screen integration
        // endLiveActivity()

        // Clear Now Playing
        nowPlayingController?.clearNowPlaying()

    }

    /// Reset DSP state for current SignalEngine-based source (filters/reverb/fades)
    private func resetCurrentSignalEffectsState() {
        currentSignalSource?.resetEffectsState()
    }

    /// Clear references to the current SignalEngine source
    private func clearCurrentSignalSource() {
        currentSignalSource?.clearFade()
        currentSignalSource = nil
    }

    // MARK: - Preset Mapping

    /// Map UISoundPreset to PureTonePreset (if applicable)
    /// Note: .jupiter uses .cathedralStillness which includes Jupiter melody + organ drone + tree chime
    private func mapToPureTone(_ uiPreset: UISoundPreset) -> PureTonePreset? {
        switch uiPreset {
        case .jupiter:
            return .cathedralStillness  // Jupiter melody is part of cathedralStillness
        case .moonlitGymnopedie:
            return .moonlitGymnopedie
        }
    }

    private func setupCallbacks() {
        // 経路変更時のコールバック
        routeMonitor.onRouteChanged = { [weak self] route in
            guard let self = self else { return }
            Task { @MainActor in
                self.outputRoute = route
            }
        }

        // スピーカー安全停止のコールバック
        routeMonitor.onSpeakerSafety = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.pause(reason: .routeSafetySpeaker)
            }
        }
    }

    private func setupBreakSchedulerCallbacks() {
        // 休憩開始時のコールバック
        breakScheduler.onBreakStart = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.pause(reason: .quietBreak)
            }
        }

        // 休憩終了時のコールバック
        breakScheduler.onBreakEnd = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                try? self.resume()
            }
        }
    }

    private func setupNowPlayingCommands() {
        nowPlayingController?.setupRemoteCommands(
            onPlay: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    guard let preset = self.currentPreset else { return }
                    try? self.play(preset: preset)
                }
            },
            onPause: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    self.pause(reason: .user)
                }
            },
            onStop: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    self.stop()
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

        // まずカテゴリだけ設定（アクティブ化前）
        // Note: .mixWithOthers removed to enable lock screen controls
        // Lock screen controls require exclusive audio session
        do {
            try session.setCategory(.playback, mode: .default, options: [])
        } catch {
            throw error
        }

        // 次にアクティブ化
        do {
            try session.setActive(true, options: [])
        } catch {
            throw error
        }

    }

    private func registerSource(for uiPreset: UISoundPreset) throws {

        // Reset any existing SignalEngine state before switching presets
        resetCurrentSignalEffectsState()
        clearCurrentSignalSource()

        // Handle PureTone presets
        if let pureTonePreset = mapToPureTone(uiPreset) {
            let sources = PureToneBuilder.build(pureTonePreset)
            sources.forEach { engine.register($0) }
            return
        }

    }

    // MARK: - Fade Effects (Phase 2)

    private var fadeTimer: Timer?
    private var targetVolume: Float = 0.5
    private var fadeEnabled: Bool = true  // フェードを許可するかどうか

    /// 音量をフェードアウト
    /// - Parameter duration: フェード時間（秒）
    private func fadeOut(duration: TimeInterval) {
        // フェードが無効化されている場合は何もしない
        guard fadeEnabled else { return }

        fadeTimer?.invalidate()

        let startVolume = engine.engine.mainMixerNode.outputVolume
        targetVolume = startVolume  // 元の音量を記憶
        let fadeSessionId = playbackSessionId  // Capture session ID for stale check

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

                // fadeEnabled と session ID をチェック
                guard self.fadeEnabled, fadeSessionId == self.playbackSessionId else {
                    timer.invalidate()
                    self.fadeTimer = nil
                    return
                }

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
    }

}
