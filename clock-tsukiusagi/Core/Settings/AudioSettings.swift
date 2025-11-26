//
//  AudioSettings.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-10.
//  オーディオシステムの設定スキーマ
//

import Foundation

/// オーディオシステムの設定
public struct AudioSettings: Codable {
    // MARK: - Route Safety

    /// イヤホン/ヘッドホン出力のみを許可（スピーカー出力時は自動停止）
    public var onlyHeadphoneOutput: Bool = true

    /// 中断後の自動再開を有効化（電話着信など）
    public var autoResumeAfterInterruption: Bool = true

    /// ヘッドホン抜けで自動停止（レガシー設定、onlyHeadphoneOutputを使用）
    @available(*, deprecated, message: "Use onlyHeadphoneOutput instead")
    public var stopOnHeadphoneDisconnect: Bool = true

    // MARK: - Quiet Break (Phase 2)

    /// 無音休憩サイクルを有効化（55分再生/5分休憩）
    public var quietBreakEnabled: Bool = false

    /// 再生時間（分）
    public var playMinutes: Int = 55

    /// 休憩時間（分）
    public var breakMinutes: Int = 5

    // MARK: - Volume Safety (Phase 2)

    /// 最大出力音量（dB）デフォルト: -6dB（約50%）
    public var maxOutputDb: Float = -6.0

    // MARK: - Track Player (Phase 3)

    /// クロスフェード時間（秒）
    public var crossfadeDuration: TimeInterval = 2.0

    // MARK: - UI Features (Phase 3)

    /// Live Activityを有効化
    public var liveActivityEnabled: Bool = true

    /// Picture in Pictureを有効化
    public var pipEnabled: Bool = false

    // MARK: - Air Layer (Transparency Enhancement)

    /// Air Layer（高域透明レイヤー）を有効化
    public var airLayerEnabled: Bool = true

    /// Air Layer 音量（0.01 - 0.1、デフォルト: 0.03）
    public var airLayerVolume: Float = 0.03

    // MARK: - Initialization

    public init(
        onlyHeadphoneOutput: Bool = true,
        autoResumeAfterInterruption: Bool = true,
        quietBreakEnabled: Bool = false,
        playMinutes: Int = 55,
        breakMinutes: Int = 5,
        maxOutputDb: Float = -6.0,
        crossfadeDuration: TimeInterval = 2.0,
        liveActivityEnabled: Bool = true,
        pipEnabled: Bool = false,
        airLayerEnabled: Bool = true,
        airLayerVolume: Float = 0.03
    ) {
        self.onlyHeadphoneOutput = onlyHeadphoneOutput
        self.autoResumeAfterInterruption = autoResumeAfterInterruption
        self.quietBreakEnabled = quietBreakEnabled
        self.playMinutes = playMinutes
        self.breakMinutes = breakMinutes
        self.maxOutputDb = maxOutputDb
        self.crossfadeDuration = crossfadeDuration
        self.liveActivityEnabled = liveActivityEnabled
        self.pipEnabled = pipEnabled
        self.airLayerEnabled = airLayerEnabled
        self.airLayerVolume = airLayerVolume
    }
}

// MARK: - UserDefaults Extension

extension AudioSettings {
    private static let userDefaultsKey = "AudioSettings"

    /// UserDefaultsから設定を読み込み
    public static func load() -> AudioSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(AudioSettings.self, from: data) else {
            return AudioSettings()  // デフォルト設定を返す
        }
        return settings
    }

    /// UserDefaultsに設定を保存
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AudioSettings.userDefaultsKey)
        }
    }
}
