//
//  NavigationBarTokens.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-20.
//  ナビゲーションバーのデザイントークン
//

import SwiftUI

/// ナビゲーションバーのデザイントークン
public struct NavigationBarTokens {

    // MARK: - Colors

    /// ナビゲーションバーの背景色（背景グラデーションより少し濃い）
    public static let backgroundColor = UIColor(
        red: 0x0A/255.0,
        green: 0x0D/255.0,
        blue: 0x15/255.0,
        alpha: 1.0
    )

    /// タイトルテキストの色
    public static let titleColor = UIColor.white

    // MARK: - Typography

    /// モノスペースフォント（AudioTestView用）
    public static func monospacedTitleFont(size: CGFloat = 17, weight: UIFont.Weight = .semibold) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    /// 丸ゴシックフォント（AudioSettingsView用）
    public static func roundedTitleFont(size: CGFloat = 17, weight: UIFont.Weight = .semibold) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }

    // MARK: - Configuration

    /// ナビゲーションバーの appearance を設定
    public static func configureAppearance(titleFont: UIFont) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: titleColor
        ]

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = titleAttributes

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
