//
//  NavigationBarTokens.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-20.
//  ナビゲーションバーのデザイントークン（SwiftUI-First）
//

import SwiftUI

/// ナビゲーションバーのデザイントークン
public struct NavigationBarTokens {

    // MARK: - Colors

    /// ナビゲーションバーの背景色（背景グラデーションより少し濃い）
    public static let backgroundColor = Color(
        red: 0x0A/255.0,
        green: 0x0D/255.0,
        blue: 0x15/255.0
    )

    /// タイトルテキストの色
    public static let titleColor = Color.white

    // MARK: - Typography

    /// 現在のフォントスタイルに基づいたタイトルフォント
    public static var titleFont: Font {
        let settings = AppSettings.load()
        switch settings.fontStyle {
        case .monospaced:
            return Font.system(size: 17, weight: .semibold, design: .monospaced)
        case .rounded:
            return Font.system(size: 17, weight: .semibold, design: .rounded)
        }
    }

    // MARK: - Legacy (Deprecated)

    /// モノスペースフォント（後方互換性のために残す）
    @available(*, deprecated, message: "Use titleFont instead")
    public static let monospacedTitleFont = Font.system(
        size: 17,
        weight: .semibold,
        design: .monospaced
    )

    /// 丸ゴシックフォント（後方互換性のために残す）
    @available(*, deprecated, message: "Use titleFont instead")
    public static let roundedTitleFont = Font.system(
        size: 17,
        weight: .semibold,
        design: .rounded
    )
}
