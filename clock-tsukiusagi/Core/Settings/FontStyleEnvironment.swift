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
///
/// `@AppStorage` の変更を監視し、変更があれば `objectWillChange` を送信して
/// 全ての View を再描画させる。これにより、AppSettings でフォントを変更すると
/// 即座に全画面に反映される。
public class FontStyleProvider: ObservableObject {
    @Published var fontStyle: FontStyle {
        didSet {
            // UserDefaults に保存
            UserDefaults.standard.set(fontStyle.rawValue, forKey: FontStyle.userDefaultsKey)
        }
    }

    public init() {
        // UserDefaults から初期値を読み込み
        if let rawValue = UserDefaults.standard.string(forKey: FontStyle.userDefaultsKey),
           let style = FontStyle(rawValue: rawValue) {
            self.fontStyle = style
        } else {
            self.fontStyle = .rounded
        }

        // UserDefaults の変更を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func userDefaultsDidChange() {
        // 他の画面（AppSettingsView）が @AppStorage で直接変更した場合も検知
        if let rawValue = UserDefaults.standard.string(forKey: FontStyle.userDefaultsKey),
           let newStyle = FontStyle(rawValue: rawValue),
           newStyle != fontStyle {
            DispatchQueue.main.async {
                self.fontStyle = newStyle
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
