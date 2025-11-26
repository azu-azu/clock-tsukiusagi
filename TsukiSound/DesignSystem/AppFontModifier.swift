//
//  AppFontModifier.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-21.
//  アプリ全体のフォントスタイルを動的に適用
//
//  # Architecture
//
//  このファイルはフォントスタイル（Technical/Rounded）を Environment 経由で全画面に配信する。
//
//  ## データフロー
//  1. AppSettings (@AppStorage) がユーザーの選択を保持
//  2. FontStyleProvider が @AppStorage を監視し、変更を publish
//  3. withFontStyleProvider() が Environment に注入
//  4. 各ビューは @Environment(\.fontStyle) または .dynamicFont() で参照
//
//  ## フォント切り替えを削除する場合
//  - DynamicTheme.swift の各サイズ定義を残す
//  - FontStyle を固定値（.rounded）にする
//  - Environment 注入経路はそのまま残す（将来の再導入が容易）
//

import SwiftUI

// MARK: - Font Style Provider

/// アプリ全体のフォントスタイルを提供する ViewModifier
struct AppFontStyleModifier: ViewModifier {
    @ObservedObject var provider: FontStyleProvider

    func body(content: Content) -> some View {
        content
            .environment(\.fontStyle, provider.fontStyle)
    }
}

// MARK: - Dynamic Font Modifier

/// フォントスタイルに基づいて動的にフォントを適用する ViewModifier
///
/// 使用例:
/// ```swift
/// Text("Hello")
///     .dynamicFont(size: DynamicTheme.SettingsTypography.itemTitleSize,
///                  weight: DynamicTheme.SettingsTypography.itemTitleWeight)
/// ```
struct DynamicFont: ViewModifier {
    @Environment(\.fontStyle) private var fontStyle: FontStyle
    let size: CGFloat
    let weight: Font.Weight
    let relativeTo: Font.TextStyle?

    init(size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle? = nil) {
        self.size = size
        self.weight = weight
        self.relativeTo = relativeTo
    }

    func body(content: Content) -> some View {
		if relativeTo != nil {
            content.font(.system(size: size, weight: weight, design: fontStyle.design).width(.standard))
        } else {
            content.font(.system(size: size, weight: weight, design: fontStyle.design))
        }
    }
}

// MARK: - View Extensions

extension View {
    /// アプリ全体のフォントスタイルを Environment に注入
    ///
    /// ContentView で1回だけ呼ぶ:
    /// ```swift
    /// ContentView()
    ///     .withFontStyleProvider(fontStyleProvider)
    /// ```
    func withFontStyleProvider(_ provider: FontStyleProvider) -> some View {
        modifier(AppFontStyleModifier(provider: provider))
    }

    /// 動的フォントを適用
    ///
    /// DynamicTheme のサイズ定義と組み合わせて使用:
    /// ```swift
    /// Text("Title")
    ///     .dynamicFont(size: DynamicTheme.SettingsTypography.itemTitleSize,
    ///                  weight: DynamicTheme.SettingsTypography.itemTitleWeight)
    /// ```
    func dynamicFont(size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle? = nil) -> some View {
        modifier(DynamicFont(size: size, weight: weight, relativeTo: relativeTo))
    }
}
