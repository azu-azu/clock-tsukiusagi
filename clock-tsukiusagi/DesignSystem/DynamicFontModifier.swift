//
//  DynamicFontModifier.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-21.
//  フォントスタイルを動的に反映する ViewModifier
//

import SwiftUI

/// ナビゲーションバーのフォントを動的に反映する ViewModifier
struct DynamicNavigationFont: ViewModifier {
    @AppStorage(FontStyle.userDefaultsKey) private var fontStyleRaw: String = FontStyle.rounded.rawValue

    private var fontStyle: FontStyle {
        FontStyle(rawValue: fontStyleRaw) ?? .rounded
    }

    func body(content: Content) -> some View {
        content
            .font(fontStyle.font)
    }
}

extension View {
    /// ナビゲーションバーのフォントを動的に適用
    func dynamicNavigationFont() -> some View {
        modifier(DynamicNavigationFont())
    }
}
