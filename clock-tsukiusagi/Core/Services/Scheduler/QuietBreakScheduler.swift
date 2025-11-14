//
//  QuietBreakScheduler.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-10.
//  無音休憩スケジューラー（55分再生/5分休憩サイクル）
//

import Foundation
import UIKit

/// 無音休憩スケジュール管理プロトコル
public protocol QuietBreakScheduling {
    var isEnabled: Bool { get set }
    var playDuration: TimeInterval { get set }
    var breakDuration: TimeInterval { get set }
    var fadeDuration: TimeInterval { get set }
    var nextBreakAt: Date? { get }
    var onBreakStart: (() -> Void)? { get set }
    var onBreakEnd: (() -> Void)? { get set }

    func start()
    func stop()
    func reset()
}

/// 無音休憩スケジューラー
/// 指定時間ごとに自動的に休憩を挟む（デフォルト: 55分再生/5分休憩）
public final class QuietBreakScheduler: QuietBreakScheduling {
    // MARK: - Properties

    public var isEnabled: Bool
    public var playDuration: TimeInterval  // 55 * 60 = 3300秒
    public var breakDuration: TimeInterval  // 5 * 60 = 300秒
    public var fadeDuration: TimeInterval  // 0.5〜1.5秒

    public var nextBreakAt: Date? { _nextBreakAt }
    public var onBreakStart: (() -> Void)?
    public var onBreakEnd: (() -> Void)?

    private var _nextBreakAt: Date?
    private var timer: DispatchSourceTimer?
    private var phase: Phase = .idle
    private var appLifecycleObserver: NSObjectProtocol?

    /// スケジューラーの状態
    private enum Phase {
        case idle
        case playing(startedAt: Date)
        case breaking(startedAt: Date)
    }

    // MARK: - Initialization

    public init(
        isEnabled: Bool = false,
        playDuration: TimeInterval = 55 * 60,  // 55分
        breakDuration: TimeInterval = 5 * 60,  // 5分
        fadeDuration: TimeInterval = 0.5  // 0.5秒
    ) {
        self.isEnabled = isEnabled
        self.playDuration = playDuration
        self.breakDuration = breakDuration
        self.fadeDuration = fadeDuration

        setupLifecycleObservers()
    }

    deinit {
        stop()
        if let observer = appLifecycleObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    public func start() {
        guard isEnabled else {
            return
        }

        // 次の休憩時刻を計算（真値）
        let now = Date()
        _nextBreakAt = now.addingTimeInterval(playDuration)

        // タイマーを開始
        scheduleTimer(for: playDuration)
        phase = .playing(startedAt: now)
    }

    public func stop() {
        timer?.cancel()
        timer = nil
        phase = .idle
        _nextBreakAt = nil
    }

    public func reset() {
        stop()
        if isEnabled {
            start()
        }
    }

    // MARK: - Private Methods

    private func scheduleTimer(for interval: TimeInterval) {
        timer?.cancel()

        let newTimer = DispatchSource.makeTimerSource(queue: .main)
        newTimer.schedule(wallDeadline: .now() + interval)
        newTimer.setEventHandler { [weak self] in
            self?.handleTimerFired()
        }
        newTimer.resume()

        timer = newTimer
    }

    private func handleTimerFired() {
        switch phase {
        case .playing:
            // 休憩開始を通知
            onBreakStart?()

            // 次の再生開始時刻を計算
            let now = Date()
            _nextBreakAt = now.addingTimeInterval(breakDuration)

            // 休憩タイマーをスケジュール
            scheduleTimer(for: breakDuration)
            phase = .breaking(startedAt: now)

        case .breaking:
            // 再生再開を通知
            onBreakEnd?()

            // 次の休憩時刻を計算
            let now = Date()
            _nextBreakAt = now.addingTimeInterval(playDuration)

            // 再生タイマーをスケジュール
            scheduleTimer(for: playDuration)
            phase = .playing(startedAt: now)

        case .idle:
            break
        }
    }

    private func setupLifecycleObservers() {
        // アプリがバックグラウンドから復帰した時にタイマーを再計算
        appLifecycleObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWakeFromSleep()
        }
    }

    private func handleWakeFromSleep() {
        guard let nextBreak = _nextBreakAt else { return }

        let now = Date()
        let remaining = nextBreak.timeIntervalSince(now)

        if remaining > 0 {
            // まだ時間がある - タイマーを再スケジュール
            scheduleTimer(for: remaining)
        } else {
            // 時間切れ - 即座にトリガー
            handleTimerFired()
        }
    }
}
