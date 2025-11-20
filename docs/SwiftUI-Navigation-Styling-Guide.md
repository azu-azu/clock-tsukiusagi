# SwiftUI Navigation Styling Guide

**Version**: 1.0
**Last Updated**: 2025-11-20
**Target**: iOS 17+

## 🎯 結論

**clock-tsukiusagi では UIKit Appearance API を使わず、SwiftUI の標準 Modifier で Navigation Bar をスタイリングする。**

理由：
- iOS 17 では SwiftUI の Navigation API が成熟している
- UIKit Appearance はグローバル適用で画面ごとの差異を表現できない
- DesignTokens の SwiftUI 中心思想と整合性が取れる
- 将来の macOS / watchOS / visionOS 展開に有利

---

## ❌ 使わない方法：UIKit Appearance API

### 従来のアプローチ（非推奨）

```swift
// ❌ これは使わない
let appearance = UINavigationBarAppearance()
appearance.configureWithOpaqueBackground()
appearance.backgroundColor = UIColor(...)
appearance.titleTextAttributes = [.font: UIFont.monospacedSystemFont(...)]
UINavigationBar.appearance().standardAppearance = appearance
```

### 問題点

1. **グローバル適用の制約**
   - `UINavigationBar.appearance()` はアプリ全体に一律適用される
   - Audio 画面と Settings 画面で異なるフォントを使えない
   - 画面ごとのカスタマイズが困難

2. **SwiftUI との競合**
   - SwiftUI の `.toolbarBackground` などと二重管理になる
   - どちらが優先されるか不明瞭
   - デバッグが困難

3. **DesignTokens との不整合**
   - SwiftUI 中心の設計なのに UIKit に依存
   - `UIColor` と `Color` の変換が必要
   - コードが複雑化

4. **プラットフォーム展開の制約**
   - UIKit は iOS/iPadOS 専用
   - macOS / watchOS / visionOS に展開できない

---

## ✅ 推奨方法：SwiftUI 標準 Modifier

### iOS 16+ で使える API

#### 1. カスタムフォント設定

```swift
// モノスペースフォント（Audio 画面用）
.navigationTitle("Audio")
.font(.system(size: 17, weight: .semibold, design: .monospaced))

// 丸ゴシックフォント（Settings 画面用）
.navigationTitle("Settings")
.font(.system(size: 17, weight: .semibold, design: .rounded))
```

**ポイント**：
- `.font(design:)` で monospaced / rounded が指定可能
- UIFont は不要
- 画面ごとに異なるフォントを簡単に設定できる

#### 2. 背景色の完全制御

```swift
.toolbarBackground(
    DesignTokens.SettingsColors.navBarBackground,
    for: .navigationBar
)
.toolbarBackground(.visible, for: .navigationBar)
```

**ポイント**：
- 透明、半透明、単色すべて対応
- `Color` を直接使える（`UIColor` 変換不要）
- `.visible` で明示的に可視化

#### 3. シャドウ/境界線の削除

```swift
// 方法1：境界線を非表示
.toolbarColorScheme(.dark, for: .navigationBar)

// 方法2：完全にカスタマイズ（必要に応じて）
.toolbar {
    // カスタムツールバー
}
```

**ポイント**：
- `.shadowColor = .clear` 相当の制御が可能
- SwiftUI の Modifier で完結

---

## 📐 DesignTokens への統合

### 推奨構造

```swift
// DesignTokens/NavigationBarTokens.swift
public struct NavigationBarTokens {

    // MARK: - Colors

    /// ナビゲーションバーの背景色
    public static let backgroundColor = Color(
        red: 0x0A/255.0,
        green: 0x0D/255.0,
        blue: 0x15/255.0
    )

    /// タイトルテキストの色
    public static let titleColor = Color.white

    // MARK: - Typography

    /// モノスペースタイトルフォント（Audio用）
    public static let monospacedTitleFont = Font.system(
        size: 17,
        weight: .semibold,
        design: .monospaced
    )

    /// 丸ゴシックタイトルフォント（Settings用）
    public static let roundedTitleFont = Font.system(
        size: 17,
        weight: .semibold,
        design: .rounded
    )
}
```

### View での使用例

```swift
// AudioTestView.swift
NavigationView {
    // コンテンツ
}
.navigationTitle("Audio")
.toolbarBackground(
    NavigationBarTokens.backgroundColor,
    for: .navigationBar
)
.toolbarBackground(.visible, for: .navigationBar)
.font(NavigationBarTokens.monospacedTitleFont)

// AudioSettingsView.swift
NavigationView {
    // コンテンツ
}
.navigationTitle("Settings")
.toolbarBackground(
    NavigationBarTokens.backgroundColor,
    for: .navigationBar
)
.toolbarBackground(.visible, for: .navigationBar)
.font(NavigationBarTokens.roundedTitleFont)
```

---

## 🔧 カスタム ViewModifier による共通化（オプション）

繰り返しを避けるため、カスタム Modifier を作成できます：

```swift
// DesignSystem/NavigationBarStyleModifier.swift
public enum NavigationBarFontStyle {
    case monospaced
    case rounded
}

public struct NavigationBarStyleModifier: ViewModifier {
    let fontStyle: NavigationBarFontStyle

    public func body(content: Content) -> some View {
        content
            .toolbarBackground(
                NavigationBarTokens.backgroundColor,
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .font(font(for: fontStyle))
    }

    private func font(for style: NavigationBarFontStyle) -> Font {
        switch style {
        case .monospaced:
            return NavigationBarTokens.monospacedTitleFont
        case .rounded:
            return NavigationBarTokens.roundedTitleFont
        }
    }
}

extension View {
    public func configureNavigationBar(
        fontStyle: NavigationBarFontStyle
    ) -> some View {
        modifier(NavigationBarStyleModifier(fontStyle: fontStyle))
    }
}
```

### 使用例

```swift
// AudioTestView.swift
NavigationView {
    // コンテンツ
}
.navigationTitle("Audio")
.configureNavigationBar(fontStyle: .monospaced)

// AudioSettingsView.swift
NavigationView {
    // コンテンツ
}
.navigationTitle("Settings")
.configureNavigationBar(fontStyle: .rounded)
```

---

## 🆚 比較表

| 項目 | UIKit Appearance | SwiftUI Modifier |
|------|------------------|------------------|
| **iOS バージョン** | iOS 13+ | iOS 16+ |
| **カスタムフォント** | UIFont が必要 | Font.system(design:) で直接指定 |
| **背景色制御** | UIColor 変換が必要 | Color を直接使用 |
| **画面ごとの差異** | 困難（グローバル適用） | 簡単（View ごとに指定） |
| **SwiftUI との整合性** | 低い（UIKit 依存） | 高い（ネイティブ） |
| **macOS 対応** | 不可 | 可能 |
| **コード量** | 多い | 少ない |
| **保守性** | 低い | 高い |

---

## 🚀 マイグレーション手順

現在の `NavigationBarTokens.swift` を SwiftUI 化する場合：

### Step 1: NavigationBarTokens を SwiftUI 型に変更

```swift
// Before: UIColor, UIFont
public static let backgroundColor = UIColor(...)
public static func monospacedTitleFont(...) -> UIFont { ... }

// After: Color, Font
public static let backgroundColor = Color(...)
public static let monospacedTitleFont = Font.system(...)
```

### Step 2: Appearance 設定を削除

```swift
// ❌ 削除
public static func configureAppearance(titleFont: UIFont) {
    let appearance = UINavigationBarAppearance()
    // ...
    UINavigationBar.appearance().standardAppearance = appearance
}
```

### Step 3: View で直接 Modifier を使用

```swift
// 各 View で
.toolbarBackground(NavigationBarTokens.backgroundColor, for: .navigationBar)
.toolbarBackground(.visible, for: .navigationBar)
.font(NavigationBarTokens.monospacedTitleFont)
```

### Step 4: カスタム Modifier を作成（オプション）

共通化したい場合は上記の `NavigationBarStyleModifier` を実装。

---

## 📝 まとめ

- ✅ SwiftUI の `.toolbarBackground` と `.font(design:)` で完結
- ✅ 画面ごとに異なるスタイルを簡単に適用可能
- ✅ DesignTokens との整合性が高い
- ✅ 将来のプラットフォーム展開に有利
- ❌ UIKit Appearance API は使わない

**clock-tsukiusagi は SwiftUI 中心の設計。Navigation Bar も SwiftUI の標準機能で統一する。**
