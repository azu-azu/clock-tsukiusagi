//
//  AudioRouteMonitor.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-10.
//  オーディオ出力経路の監視（イヤホン抜け検知など）
//

import AVFoundation
import Foundation

/// オーディオ出力経路の種類
public enum AudioOutputRoute: Equatable {
    case headphones           // 有線ヘッドホン (.headphones)
    case bluetoothHeadphones  // Bluetooth ヘッドホン (over-ear)
    case bluetoothEarbuds     // Bluetooth イヤホン (AirPods等 in-ear)
    case speaker              // 内蔵/外部スピーカー (.builtInSpeaker)
    case unknown              // 不明

    /// SF Symbol name for the output route
    public var systemImageName: String {
        switch self {
        case .headphones: return "headphones"
        case .bluetoothHeadphones: return "headphones"
        case .bluetoothEarbuds: return "airpodspro"
        case .speaker: return "speaker.wave.2.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Localization key
    private var localizationKey: String {
        switch self {
        case .headphones: return "route.headphones"
        case .bluetoothHeadphones: return "route.bluetooth"
        case .bluetoothEarbuds: return "route.bluetooth"
        case .speaker: return "route.speaker"
        case .unknown: return "route.unknown"
        }
    }

    /// 表示名（ローカライズ済み）
    public var displayName: String {
        localizationKey.localized
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
        // 1. 理由をチェック
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        #if DEBUG
        print("🎧 [AudioRouteMonitor] Route change reason: \(reason.description)")
        #endif

        // 現在の経路を取得
        let newRoute = detectCurrentRoute()
        #if DEBUG
        print("🎧 [AudioRouteMonitor] Current route: \(newRoute.displayName) (\(newRoute.systemImageName))")
        #endif

        // 常に経路変更を通知（UIをリアルタイム更新）
        onRouteChanged?(newRoute)

        // デバイス削除（イヤホン抜けなど）の場合のみ安全停止チェック
        guard reason == .oldDeviceUnavailable else {
            return
        }

        // 2. 前の経路をチェック - イヤホン/Bluetooth系だったか？
        guard let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
              let previousOutput = previousRoute.outputs.first else {
            #if DEBUG
            print("⚠️ [AudioRouteMonitor] Could not detect previous route")
            #endif
            return
        }

        let wasHeadphoneType = [
            AVAudioSession.Port.headphones,
            AVAudioSession.Port.bluetoothA2DP,
            AVAudioSession.Port.bluetoothLE
        ].contains(previousOutput.portType)

        #if DEBUG
        print("🎧 [AudioRouteMonitor] Previous route: \(previousOutput.portType.rawValue), was headphone type: \(wasHeadphoneType)")
        #endif

        // 3. イヤホン→スピーカー かつ 設定で安全停止が有効なら発動
        if wasHeadphoneType && newRoute == .speaker {
            if settings.onlyHeadphoneOutput {
                #if DEBUG
                print("⚠️ [AudioRouteMonitor] Safety pause triggered: headphone→speaker")
                #endif
                onSpeakerSafety?()
            } else {
                #if DEBUG
                print("🎧 [AudioRouteMonitor] Headphone removed but safety pause disabled")
                #endif
            }
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
            // Detect earbuds vs headphones based on device name
            return detectBluetoothType(portName: output.portName)
        case .builtInSpeaker:
            return .speaker
        default:
            return .unknown
        }
    }

    /// Detect if Bluetooth device is earbuds or headphones based on port name
    private func detectBluetoothType(portName: String) -> AudioOutputRoute {
        let lowercaseName = portName.lowercased()

        // Known earbuds patterns
        let earbudsPatterns = [
            "airpods",      // Apple AirPods
            "earbuds",      // Generic earbuds
            "buds",         // Samsung Galaxy Buds, etc.
            "earpods",      // Apple EarPods (wired but just in case)
            "wf-",          // Sony WF series (e.g., WF-1000XM4)
            "jabra elite",  // Jabra earbuds
            "pixel buds",   // Google Pixel Buds
            "freebuds",     // Huawei FreeBuds
            "liberty",      // Anker Soundcore Liberty
        ]

        for pattern in earbudsPatterns {
            if lowercaseName.contains(pattern) {
                return .bluetoothEarbuds
            }
        }

        // Default to headphones for unknown Bluetooth devices
        return .bluetoothHeadphones
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
