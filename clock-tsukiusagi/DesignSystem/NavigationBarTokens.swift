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

    /// モノスペースフォント（AudioTestView用）
    public static let monospacedTitleFont = Font.system(
        size: 17,
        weight: .semibold,
        design: .monospaced
    )

    /// 丸ゴシックフォント（AudioSettingsView用）
    public static let roundedTitleFont = Font.system(
        size: 17,
        weight: .semibold,
        design: .rounded
    )
}
