//
//  NavigationBackModifier.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-22.
//  カスタム Back ボタンとスワイプジェスチャを提供
//

import SwiftUI

/// カスタム Back ボタンとスワイプジェスチャを提供する ViewModifier
///
/// 標準の NavigationView back ボタンを隠し、カスタム "< Back" ボタンを表示。
/// 右スワイプ（50pt以上）で戻る動作も提供。
struct NavigationBackModifier: ViewModifier {
    let onBack: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17, weight: .regular))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // 右スワイプ（50pt以上、垂直移動は100pt未満）で戻る
                        if value.translation.width > 50 && abs(value.translation.height) < 100 {
                            onBack()
                        }
                    }
            )
    }
}

// MARK: - View Extension

extension View {
    /// カスタム Back ボタンとスワイプジェスチャを追加
    ///
    /// 使用例:
    /// ```swift
    /// NavigationView {
    ///     SettingsView()
    ///         .navigationBackButton {
    ///             selectedTab = .clock
    ///         }
    /// }
    /// ```
    ///
    /// - Parameter onBack: 戻る動作を実行するクロージャ
    /// - Returns: Modifier が適用された View
    func navigationBackButton(onBack: @escaping () -> Void) -> some View {
        self.modifier(NavigationBackModifier(onBack: onBack))
    }
}
