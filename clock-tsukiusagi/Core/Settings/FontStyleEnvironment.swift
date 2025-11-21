//
//  FontStyleEnvironment.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-21.
//  フォントスタイルを Environment 経由で配信
//

import SwiftUI

// MARK: - Environment Key

private struct FontStyleKey: EnvironmentKey {
    static let defaultValue: FontStyle = .rounded
}

extension EnvironmentValues {
    var fontStyle: FontStyle {
        get { self[FontStyleKey.self] }
        set { self[FontStyleKey.self] = newValue }
    }
}

// MARK: - FontStyle Provider

/// アプリ全体にフォントスタイルを提供する ObservableObject
public class FontStyleProvider: ObservableObject {
    @AppStorage(FontStyle.userDefaultsKey) var fontStyle: FontStyle = .rounded
}
