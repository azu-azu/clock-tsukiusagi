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

        print("🎵 [AudioService] Initialized as singleton")
        print("   Initial output route: \(outputRoute.displayName) \(outputRoute.icon)")
        print("   Quiet breaks: \(settings.quietBreakEnabled ? "Enabled" : "Disabled")")
        print("   Max output: \(settings.maxOutputDb) dB")
        print("   Live Activity: \(activityController != nil ? "Available" : "Not Available")")
        print("   System volume monitoring: Enabled")
        print("   Volume cap: \(volumeCapLinear) (-6dB)")
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

        // 音量は動的ゲイン補正で自動設定される（システム音量に基づく）
        applyDynamicGainCompensation()

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

        // Phase 3: Live Activityを更新
        updateLiveActivity()

        // Phase 3: Now Playingを更新
        updateNowPlaying()
        updateNowPlayingState()

        print("🎵 [AudioService] Playback started successfully")
    }

    /// 音声再生を停止
    /// - Parameter fadeOut: フェードアウト時間（秒）
    public func stop(fadeOut fadeOutDuration: TimeInterval = 0.5) {
        print("🎵 [AudioService] stop() called")
        print("🎵 [AudioService] Current preset: \(String(describing: currentPreset))")
        print("🎵 [AudioService] Current audio file: \(currentAudioFile?.displayName ?? "none")")

        // Stop synthesis engine (if playing)
        if currentPreset != nil {
            // フェードアウト
            self.fadeOut(duration: fadeOutDuration)

            // フェード完了後にエンジンを停止
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) { [weak self] in
                self?.engine.stop()
                self?.engine.clearSources()  // Clear sources to prevent restart
                print("🎵 [AudioService] Synthesis engine stopped and cleared after fade")
            }
        }

        // Stop TrackPlayer (if playing audio file)
        if currentAudioFile != nil {
            stopTrackPlayer()
        }

        // 経路監視は停止しない（常に監視してUIを更新）

        // Phase 2: Quiet Breakスケジューラーを停止
        breakScheduler.stop()

        isPlaying = false
        currentPreset = nil
        currentAudioFile = nil
        pauseReason = nil

        // Phase 3: Live Activityを終了
        endLiveActivity()

        // Phase 3: Now Playingをクリア
        nowPlayingController?.clearNowPlaying()

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

        // Phase 3: Live Activityを更新
        updateLiveActivity()

        // Phase 3: Now Playing状態を更新
        updateNowPlayingState()

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

        // Phase 3: Live Activityを更新
        updateLiveActivity()

        // Phase 3: Now Playing状態を更新
        updateNowPlayingState()

        print("🎵 [AudioService] Resumed successfully")
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

            Task { @MainActor [weak self] in
                guard let self = self else { return }

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

            Task { @MainActor [weak self] in
                guard let self = self else { return }

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

                    print("🔊 [AudioService] System volume changed: \(String(format: "%.2f", newVolume)) (\(Int(newVolume * 100))%)")
                }
            }
        }

        print("🔊 [AudioService] System volume monitoring started")
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

        print("🔊 [AudioService] Dynamic gain compensation applied")
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
        print("🎵 [AudioService] ========================================")
        print("🎵 [AudioService] playAudioFile() called with: \(audioFile.displayName)")
        print("🎵 [AudioService] ========================================")

        // Stop and clear synthesis engine if playing
        if isPlaying && currentPreset != nil {
            engine.stop()
            engine.clearSources()  // Clear synthesis sources from array
            isPlaying = false
            currentPreset = nil
        } else if isPlaying {
            // Stop engine even if no preset (to clear any lingering sources)
            engine.stop()
            engine.clearSources()  // Clear any lingering sources from array
        }

        // Don't call stop() - it would stop TrackPlayer too

        // Get audio file URL
        guard let url = audioFile.url() else {
            throw AudioError.engineStartFailed(NSError(domain: "AudioService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Audio file not found: \(audioFile.rawValue)"
            ]))
        }

        // Get audio file format first
        let file = try AVAudioFile(forReading: url)
        let fileFormat = file.processingFormat

        print("🎵 [AudioService] Audio file format:")
        print("   Channels: \(fileFormat.channelCount)")
        print("   Sample rate: \(fileFormat.sampleRate) Hz")

        // Start engine BEFORE configuring TrackPlayer
        // (TrackPlayer needs engine to be running to attach nodes)
        try engine.start()

        // Initialize TrackPlayer if needed
        if trackPlayer == nil {
            trackPlayer = TrackPlayer()

            // Configure TrackPlayer with file's format (ensures channel count matches)
            trackPlayer?.configure(engine: engine.engine, format: fileFormat)

            print("🎵 [AudioService] TrackPlayer configured and connected to engine")
        }

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

        print("🎵 [AudioService] Audio file playback started successfully")
    }

    /// Stop TrackPlayer
    private func stopTrackPlayer() {
        guard let player = trackPlayer, player.isPlaying else { return }

        let fadeOut = settings.crossfadeDuration
        player.stop(fadeOut: fadeOut)

        currentAudioFile = nil

        print("🎵 [AudioService] TrackPlayer stopped")
    }
}
