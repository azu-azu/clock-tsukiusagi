//
//  AudioSessionManager.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-09.
//  Audio Session管理・中断/経路変化対応
//

import AVFoundation
import Foundation

/// オーディオセッション管理クラス
/// - 中断（電話/通知）対応
/// - ルート変化（イヤホン抜け）対応
/// - バックグラウンド再生対応
public final class AudioSessionManager {
    // MARK: - Properties

    private let notificationCenter = NotificationCenter.default
    private let session = AVAudioSession.sharedInstance()

    /// 中断時のコールバック
    public var onInterruptionBegan: (() -> Void)?
    public var onInterruptionEnded: ((Bool) -> Void)? // Bool: 自動再開すべきか

    /// ルート変化時のコールバック
    public var onRouteChanged: ((AVAudioSession.RouteChangeReason) -> Void)?

    // MARK: - Initialization

    public init() {}

    deinit {
        notificationCenter.removeObserver(self)
    }

    // MARK: - Public Methods

    /// オーディオセッションをアクティベート
    /// - Parameters:
    ///   - category: セッションカテゴリ（デフォルト: .playback）
    ///   - options: セッションオプション
    ///   - background: バックグラウンド再生を有効にするか（Info.plistの設定も必要）
    public func activate(
        category: AVAudioSession.Category = .playback,
        options: AVAudioSession.CategoryOptions = [.mixWithOthers, .allowBluetooth],
        background: Bool = true
    ) throws {

        // 既存のセッションを一旦非アクティブ化（エラーは無視）
        do {
            try session.setActive(false, options: [])
        } catch {
        }

        // カテゴリとモードを設定
        do {
            try session.setCategory(category, mode: .default, options: options)
        } catch let error as NSError {
            throw error
        }

        // サンプルレートを44100Hzに固定（再生ごとの変動を防ぐ）
        do {
            try session.setPreferredSampleRate(44100)
        } catch {
        }

        // セッションをアクティブ化
        do {
            try session.setActive(true, options: [])
        } catch let error as NSError {
            throw error
        }

        // 通知の監視を開始
        observeInterruption()
        observeRouteChange()

    }

    /// オーディオセッションを非アクティブ化
    public func deactivate() throws {
        try session.setActive(false, options: .notifyOthersOnDeactivation)
        notificationCenter.removeObserver(self)
    }

    // MARK: - Private Methods - Interruption Handling

    private func observeInterruption() {
        notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // 中断開始：音声を停止
            onInterruptionBegan?()

        case .ended:
            // 中断終了：オプションに応じて自動再開
            var shouldResume = false

            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            }

            onInterruptionEnded?(shouldResume)

        @unknown default:
            break
        }
    }

    // MARK: - Private Methods - Route Change Handling

    private func observeRouteChange() {
        notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        onRouteChanged?(reason)

        // イヤホン抜けの場合は自動的に処理
        if reason == .oldDeviceUnavailable {
            // 前のルートを確認
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                // ヘッドフォンやBluetoothが抜かれた場合
                let wasUsingHeadphones = previousRoute.outputs.contains { output in
                    output.portType == .headphones ||
                    output.portType == .bluetoothA2DP ||
                    output.portType == .bluetoothHFP ||
                    output.portType == .bluetoothLE
                }

                if wasUsingHeadphones {
                    // イヤホン抜け時の処理はコールバックで通知
                    // 呼び出し側で停止などの処理を実装
                }
            }
        }
    }
}
