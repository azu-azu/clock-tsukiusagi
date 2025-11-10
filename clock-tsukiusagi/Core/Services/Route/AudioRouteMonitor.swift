//
//  AudioRouteMonitor.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-10.
//  オーディオ出力経路の監視（イヤホン抜け検知など）
//

import AVFoundation
import Foundation

/// オーディオ出力経路の種類
public enum AudioOutputRoute: Equatable {
    case headphones     // 有線ヘッドホン (.headphones)
    case bluetooth      // Bluetooth (A2DP/LE)
    case speaker        // 内蔵/外部スピーカー (.builtInSpeaker)
    case unknown        // 不明

    /// アイコン表示用の絵文字
    public var icon: String {
        switch self {
        case .headphones: return "🎧"
        case .bluetooth: return "🅱️"
        case .speaker: return "🔊"
        case .unknown: return "❓"
        }
    }

    /// 表示名
    public var displayName: String {
        switch self {
        case .headphones: return "Headphones"
        case .bluetooth: return "Bluetooth"
        case .speaker: return "Speaker"
        case .unknown: return "Unknown"
        }
    }
}

/// オーディオ経路監視プロトコル
public protocol AudioRouteMonitoring {
    var currentRoute: AudioOutputRoute { get }
    var onRouteChanged: ((AudioOutputRoute) -> Void)? { get set }
    var onSpeakerSafety: (() -> Void)? { get set }

    func start()
    func stop()
}

/// オーディオ経路モニター
/// イヤホン抜け→スピーカー切り替えを検知して安全停止を発動
public final class AudioRouteMonitor: AudioRouteMonitoring {
    // MARK: - Properties

    private let session = AVAudioSession.sharedInstance()
    private var settings: AudioSettings

    public var currentRoute: AudioOutputRoute {
        detectCurrentRoute()
    }

    public var onRouteChanged: ((AudioOutputRoute) -> Void)?
    public var onSpeakerSafety: (() -> Void)?

    // MARK: - Initialization

    public init(settings: AudioSettings) {
        self.settings = settings
    }

    // MARK: - Public Methods

    public func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        // 初回の経路を通知
        onRouteChanged?(currentRoute)
    }

    public func stop() {
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    // MARK: - Private Methods

    @objc private func handleRouteChange(_ notification: Notification) {
        // 1. 理由をチェック - デバイス削除時のみ処理
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("🎧 [AudioRouteMonitor] Route change reason: \(reason.description)")

        // デバイス削除（イヤホン抜けなど）以外は経路通知のみ
        guard reason == .oldDeviceUnavailable else {
            let newRoute = detectCurrentRoute()
            print("🎧 [AudioRouteMonitor] Route changed to: \(newRoute.displayName)")
            onRouteChanged?(newRoute)
            return
        }

        // 2. 前の経路をチェック - イヤホン/Bluetooth系だったか？
        guard let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
              let previousOutput = previousRoute.outputs.first else {
            print("⚠️ [AudioRouteMonitor] Could not detect previous route")
            return
        }

        let wasHeadphoneType = [
            AVAudioSession.Port.headphones,
            AVAudioSession.Port.bluetoothA2DP,
            AVAudioSession.Port.bluetoothLE
        ].contains(previousOutput.portType)

        print("🎧 [AudioRouteMonitor] Previous route: \(previousOutput.portType.rawValue), was headphone type: \(wasHeadphoneType)")

        // 3. 現在の経路をチェック - スピーカーになったか？
        let newRoute = detectCurrentRoute()
        print("🎧 [AudioRouteMonitor] Current route: \(newRoute.displayName)")

        // 4. イヤホン→スピーカー かつ 設定で安全停止が有効なら発動
        if wasHeadphoneType && newRoute == .speaker {
            if settings.onlyHeadphoneOutput {
                print("⚠️ [AudioRouteMonitor] Safety pause triggered: headphone→speaker")
                onSpeakerSafety?()
            } else {
                print("🎧 [AudioRouteMonitor] Headphone removed but safety pause disabled")
                onRouteChanged?(newRoute)
            }
        } else {
            onRouteChanged?(newRoute)
        }
    }

    private func detectCurrentRoute() -> AudioOutputRoute {
        guard let output = session.currentRoute.outputs.first else {
            return .unknown
        }

        switch output.portType {
        case .headphones:
            return .headphones
        case .bluetoothA2DP, .bluetoothLE:
            return .bluetooth
        case .builtInSpeaker:
            return .speaker
        default:
            return .unknown
        }
    }
}

// MARK: - RouteChangeReason Description

extension AVAudioSession.RouteChangeReason {
    var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .newDeviceAvailable:
            return "newDeviceAvailable"
        case .oldDeviceUnavailable:
            return "oldDeviceUnavailable"
        case .categoryChange:
            return "categoryChange"
        case .override:
            return "override"
        case .wakeFromSleep:
            return "wakeFromSleep"
        case .noSuitableRouteForCategory:
            return "noSuitableRouteForCategory"
        case .routeConfigurationChange:
            return "routeConfigurationChange"
        @unknown default:
            return "unknown(\(rawValue))"
        }
    }
}
