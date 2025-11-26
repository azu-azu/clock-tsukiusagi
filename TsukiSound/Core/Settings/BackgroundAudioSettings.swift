//
//  BackgroundAudioToggle.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-09.
//  バックグラウンド再生設定ブリッジ
//

import Foundation
import SwiftUI

/// バックグラウンド再生の設定を管理するクラス
@Observable
public final class BackgroundAudioToggle {
    // MARK: - Properties

    /// バックグラウンド再生が有効かどうか
    public var isBackgroundAudioEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBackgroundAudioEnabled, forKey: Keys.backgroundAudioEnabled)
        }
    }

    /// 中断後の自動再開が有効かどうか
    public var isAutoResumeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoResumeEnabled, forKey: Keys.autoResumeEnabled)
        }
    }

    /// イヤホン抜けで自動停止するかどうか
    public var stopOnHeadphoneDisconnect: Bool {
        didSet {
            UserDefaults.standard.set(stopOnHeadphoneDisconnect, forKey: Keys.stopOnHeadphoneDisconnect)
        }
    }

    // MARK: - Constants

    private enum Keys {
        static let backgroundAudioEnabled = "backgroundAudioEnabled"
        static let autoResumeEnabled = "autoResumeEnabled"
        static let stopOnHeadphoneDisconnect = "stopOnHeadphoneDisconnect"
    }

    // MARK: - Initialization

    public init() {
        // UserDefaultsから設定を読み込み
        self.isBackgroundAudioEnabled = UserDefaults.standard.bool(forKey: Keys.backgroundAudioEnabled)
        self.isAutoResumeEnabled = UserDefaults.standard.bool(forKey: Keys.autoResumeEnabled)

        // イヤホン抜けでの自動停止はデフォルトでON（安全のため）
        if UserDefaults.standard.object(forKey: Keys.stopOnHeadphoneDisconnect) == nil {
            self.stopOnHeadphoneDisconnect = true
            UserDefaults.standard.set(true, forKey: Keys.stopOnHeadphoneDisconnect)
        } else {
            self.stopOnHeadphoneDisconnect = UserDefaults.standard.bool(forKey: Keys.stopOnHeadphoneDisconnect)
        }
    }

    // MARK: - Public Methods

    /// すべての設定をデフォルトに戻す
    public func resetToDefaults() {
        isBackgroundAudioEnabled = false
        isAutoResumeEnabled = false
        stopOnHeadphoneDisconnect = true
    }
}
