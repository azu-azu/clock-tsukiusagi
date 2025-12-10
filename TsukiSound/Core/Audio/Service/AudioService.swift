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
///
/// Architecture: ADR-0001 (Audio Service Singleton Pattern)
@MainActor
public final class AudioService: ObservableObject {
    // MARK: - Singleton

    public static let shared = AudioService()

    // MARK: - Published Properties

    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentPreset: UISoundPreset?
    @Published public private(set) var outputRoute: AudioOutputRoute = .unknown
    @Published public private(set) var pauseReason: PauseReason?

    /// プレイリスト状態（曲順と現在位置の "地図"）
    /// UI は .environmentObject(audioService.playlistState) で参照
    public let playlistState: PlaylistState

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

    // TrackPlayer for pre-rendered audio files
    private var trackPlayer: TrackPlayer?

    // Preset switching protection: prevent multiple concurrent stop requests
    private var isStopping = false

    // MARK: - Initialization

    private init() {
        // 設定を読み込み
        self.settings = AudioSettings.load()

        // プレイリスト状態を初期化
        self.playlistState = PlaylistState()

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
        fadeTimer?.cancel()
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

        // Start TrackPlayer AFTER engine is running (for file-based presets)
        startTrackPlayerIfNeeded()

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

        // Stop TrackPlayer if active (fade is handled by masterMixer)
        trackPlayer?.stop()

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

            // Cleanup state and auxiliary features
            self.breakScheduler.stop()

            // isPlaying already set to false at the beginning of stopAndWait()
            self.currentPreset = nil
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

        // Stop TrackPlayer if active (fade is handled by masterMixer)
        trackPlayer?.stop()

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

        // Playback Graph: TrackPlayerを再開
        //
        // エンジンとノードは別ライフサイクル。
        // engine.start() だけでは playerNode の再生は再開されない。
        // 明示的に再生を開始する必要がある。
        //
        startTrackPlayerIfNeeded()

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
        fadeTimer?.cancel()
        engineStopWorkItem = nil
        fadeTimer = nil

        // Stop TrackPlayer if active (don't detach here - let engine.stop() handle cleanup)
        trackPlayer?.stop()
        trackPlayer = nil

        // Reset playback state
        isPlaying = false
        currentPreset = nil
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
                    // Session Lifecycle: 中断終了後のセッション再アクティベート
                    //
                    // InterruptionイベントはInterruptionレイヤーの責務だが、
                    // その「結果」としてセッション権限が変わる。
                    // これはSession Lifecycleレイヤーの問題なので明示的に処理する。
                    //
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) && self.settings.autoResumeAfterInterruption {
                            // iOSから権限が戻った → 明示的にセッションを再アクティベート
                            try? AVAudioSession.sharedInstance().setActive(true)
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

        // Stop and cleanup any existing TrackPlayer
        // NOTE: detach is safe here because engine is NOT running at this point
        // (engine.start() is called AFTER registerSource in _playInternal)
        if let player = trackPlayer {
            player.stop()
            // Safe to detach when engine is stopped
            if !engine.isEngineRunning && engine.engine.attachedNodes.contains(player.playerNode) {
                engine.engine.detach(player.playerNode)
            }
            trackPlayer = nil
        }

        // Handle presets with pre-rendered audio files
        switch uiPreset {
        case .jupiter:
            try registerPrerenderedAudioFile(named: "cathedral_stillness")
            return
        case .moonlitGymnopedie:
            try registerPrerenderedAudioFile(named: "moonlit_gymnopedie")
            return
        case .acousticGymnopedie:
            try registerPrerenderedAudioFile(named: "acoustic_gymnopedie")
            return
        }

    }

    /// Register pre-rendered audio file for playback
    /// - Parameter name: Base name of the audio file (without .caf extension)
    /// Note: Does NOT start playback - engine.start() must be called first, then startTrackPlayerIfNeeded()
    private func registerPrerenderedAudioFile(named name: String) throws {
        // Find the audio file in bundle
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else {
            print("⚠️ [AudioService] \(name).caf not found in bundle")
            throw AudioError.engineStartFailed(TrackPlayerError.fileNotLoaded)
        }

        // Get file format first
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            throw TrackPlayerError.fileNotLoaded
        }
        let fileFormat = audioFile.processingFormat
        print("🎵 [AudioService] Audio file format: \(fileFormat.sampleRate) Hz, \(fileFormat.channelCount)ch")

        // Create TrackPlayer
        let player = TrackPlayer()

        // Configure player FIRST (attach to engine and connect to masterBusMixer)
        // Use file's native format - masterBusMixer will handle conversion to output format
        player.configure(engine: engine.engine, format: fileFormat, destination: volumeLimiter.masterBusMixer)

        // Load audio file AFTER configuration
        try player.load(url: url)

        // Setup track finished callback with safety guard
        // CRITICAL: Check instance identity to ignore callbacks from old TrackPlayer instances
        player.onTrackFinished = { [weak self, weak player] in
            guard let self = self,
                  let player = player,
                  self.trackPlayer === player  // Safety: verify this is the current player
            else { return }
            self.handleTrackFinished()
        }

        // Store player - playback will be started after engine.start() in _playInternal
        trackPlayer = player
    }

    /// Start TrackPlayer playback (must be called after engine.start())
    /// Note: Uses loop: false to enable playlist continuous playback via onTrackFinished callback
    private func startTrackPlayerIfNeeded() {
        guard let player = trackPlayer, !player.isPlaying else { return }
        player.play(loop: false)  // Playlist mode: detect track end for next track
        print("🎵 [AudioService] TrackPlayer started (playlist mode)")
    }

    // MARK: - Playlist Playback

    /// Handle track finished event (advance to next track in playlist)
    private func handleTrackFinished() {
        guard isPlaying else { return }  // Ignore if already stopped

        let nextPreset = playlistState.advanceToNext()
        print("🎵 [AudioService] Track finished, advancing to: \(nextPreset)")

        // Play next track without stopping engine (seamless transition)
        do {
            try playNextTrack(preset: nextPreset)
        } catch {
            print("⚠️ [AudioService] Failed to play next track: \(error)")
            stop()
        }
    }

    /// Play next track in playlist (engine already running)
    private func playNextTrack(preset: UISoundPreset) throws {
        // Stop current TrackPlayer but don't stop engine
        trackPlayer?.stop()

        // Detach old player node (safe because we stopped it first)
        // Note: detaching while engine is running is safe if the node is stopped
        if let player = trackPlayer, engine.engine.attachedNodes.contains(player.playerNode) {
            engine.engine.detach(player.playerNode)
        }
        trackPlayer = nil

        // Register new source (creates new TrackPlayer with callback)
        try registerSource(for: preset)

        // Start playback (engine is already running)
        startTrackPlayerIfNeeded()

        // Update state
        currentPreset = preset
        updateNowPlaying()
    }

    /// プレイリスト再生を開始（指定曲から）
    /// - Parameter preset: 開始する曲（nil の場合は現在の曲から）
    public func playPlaylist(startingFrom preset: UISoundPreset? = nil) throws {
        if let preset = preset {
            playlistState.setCurrentIndex(to: preset)
        }
        guard let current = playlistState.presetForCurrentIndex() else { return }
        try play(preset: current)
    }

    // MARK: - Fade Effects (Phase 2)
    //
    // 設計方針:
    // - DispatchSourceTimer を高優先度キューで使用（Timer.scheduledTimer はオーディオに不適切）
    // - Timer は RunLoop に依存し、バックグラウンドで精度が落ちる
    // - DispatchSourceTimer はオーディオスレッドに近い精度で動作
    //

    private var fadeTimer: DispatchSourceTimer?
    private var targetVolume: Float = 0.5
    private var fadeEnabled: Bool = true  // フェードを許可するかどうか

    /// 高優先度キュー（オーディオフェード用）
    private let fadeQueue = DispatchQueue(label: "com.tsukisound.fade", qos: .userInteractive)

    /// 音量をフェードアウト
    /// - Parameter duration: フェード時間（秒）
    private func fadeOut(duration: TimeInterval) {
        // フェードが無効化されている場合は何もしない
        guard fadeEnabled else { return }

        // 既存のタイマーをキャンセル
        fadeTimer?.cancel()
        fadeTimer = nil

        let startVolume = engine.engine.mainMixerNode.outputVolume
        targetVolume = startVolume  // 元の音量を記憶
        let fadeSessionId = playbackSessionId  // Capture session ID for stale check

        let steps = 60  // 60ステップ
        let stepDuration = duration / Double(steps)
        let volumeStep = startVolume / Float(steps)

        var currentStep = 0

        let timer = DispatchSource.makeTimerSource(queue: fadeQueue)
        timer.schedule(deadline: .now(), repeating: stepDuration)
        timer.setEventHandler { [weak self] in
            currentStep += 1

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // fadeEnabled と session ID をチェック
                guard self.fadeEnabled, fadeSessionId == self.playbackSessionId else {
                    self.fadeTimer?.cancel()
                    self.fadeTimer = nil
                    return
                }

                let newVolume = max(0.0, startVolume - (volumeStep * Float(currentStep)))
                self.engine.setMasterVolume(newVolume)

                if currentStep >= steps {
                    self.fadeTimer?.cancel()
                    self.fadeTimer = nil
                }
            }
        }

        fadeTimer = timer
        timer.resume()
    }

    /// 音量をフェードイン
    /// - Parameter duration: フェード時間（秒）
    private func fadeIn(duration: TimeInterval) {
        // 既存のタイマーをキャンセル
        fadeTimer?.cancel()
        fadeTimer = nil

        let endVolume = targetVolume  // 記憶した音量に戻す

        let steps = 60  // 60ステップ
        let stepDuration = duration / Double(steps)
        let volumeStep = endVolume / Float(steps)

        var currentStep = 0

        let timer = DispatchSource.makeTimerSource(queue: fadeQueue)
        timer.schedule(deadline: .now(), repeating: stepDuration)
        timer.setEventHandler { [weak self] in
            currentStep += 1

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let newVolume = min(endVolume, volumeStep * Float(currentStep))
                self.engine.setMasterVolume(newVolume)

                if currentStep >= steps {
                    self.fadeTimer?.cancel()
                    self.fadeTimer = nil
                }
            }
        }

        fadeTimer = timer
        timer.resume()
    }

    // MARK: - Live Activity Integration

    /// Update Live Activity with current state
    private func updateLiveActivity() {
        guard #available(iOS 16.1, *), settings.liveActivityEnabled else { return }
        guard let controller = activityController else { return }

        let route = outputRoute.displayName
        let nextBreak = breakScheduler.nextBreakAt
        let presetName = currentPreset?.displayName  // Use displayName with emoji prefix

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

        nowPlayingController?.updateNowPlaying(
            title: preset.englishTitle,
            artist: "TsukiSound",
            album: "Natural Sound Drones",
            artwork: preset.artworkImage,
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
