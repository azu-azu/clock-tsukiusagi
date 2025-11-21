//
//  AppFontModifier.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-21.
//  アプリ全体のフォントスタイルを動的に適用
//

import SwiftUI

/// アプリ全体のフォントスタイルを提供する ViewModifier
struct AppFontStyleModifier: ViewModifier {
    @ObservedObject var provider: FontStyleProvider

    func body(content: Content) -> some View {
        content
            .environment(\.fontStyle, provider.fontStyle)
    }
}

/// フォントスタイルに基づいて動的にフォントを適用する ViewModifier
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
        if let textStyle = relativeTo {
            content.font(.system(size: size, weight: weight, design: fontStyle.design).width(.standard))
        } else {
            content.font(.system(size: size, weight: weight, design: fontStyle.design))
        }
    }
}

extension FontStyle {
    var design: Font.Design {
        switch self {
        case .monospaced: return .monospaced
        case .rounded: return .rounded
        }
    }
}

extension View {
    /// アプリ全体のフォントスタイルを提供
    func withFontStyleProvider(_ provider: FontStyleProvider) -> some View {
        modifier(AppFontStyleModifier(provider: provider))
    }

    /// 動的フォントを適用
    func dynamicFont(size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle? = nil) -> some View {
        modifier(DynamicFont(size: size, weight: weight, relativeTo: relativeTo))
    }
}
