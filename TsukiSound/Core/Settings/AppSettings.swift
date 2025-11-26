//
//  AppSettings.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-21.
//  アプリ全般の設定モデル
//

import Foundation
import SwiftUI

/// アプリ全般の設定
public struct AppSettings: Codable {
    /// フォントスタイル
    public var fontStyle: FontStyle

    public init(fontStyle: FontStyle = .rounded) {
        self.fontStyle = fontStyle
    }

    // MARK: - Persistence

    private static let key = "app_settings"

    /// 設定を保存
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    /// 設定を読み込み
    public static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
}

/// フォントスタイル
public enum FontStyle: String, Codable, CaseIterable {
    case monospaced  // テクニカル（等幅）
    case rounded     // ラウンド（丸ゴシック）

    public var displayName: String {
        switch self {
        case .monospaced: return "Technical"
        case .rounded: return "Rounded"
        }
    }

    public var font: Font {
        switch self {
        case .monospaced:
            return Font.system(size: 17, weight: .semibold, design: .monospaced)
        case .rounded:
            return Font.system(size: 17, weight: .semibold, design: .rounded)
        }
    }

    // MARK: - UserDefaults Key

    public static let userDefaultsKey = "app_font_style"
}
