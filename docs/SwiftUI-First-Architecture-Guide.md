# SwiftUI-First Architecture Guide

**Version**: 1.0
**Last Updated**: 2025-11-20
**Target**: iOS 17+

## 🎯 結論

**clock-tsukiusagi は SwiftUI-First アプリケーション。UIKit API は原則使用しない。**

理由：
- iOS 17 では SwiftUI が成熟し、UIKit なしで完結できる
- UIKit に依存するとコードが複雑化し、保守性が下がる
- クロスプラットフォーム展開（macOS / watchOS / visionOS）が困難になる
- DesignTokens の SwiftUI 中心思想と整合性が取れる

---

## 📐 アーキテクチャの原則

### ✅ SwiftUI で実装すべきもの

1. **すべての UI コンポーネント**
   - View, Button, Text, Image, etc.
   - NavigationView, TabView, List, ScrollView
   - カスタムコンポーネント

2. **レイアウト**
   - VStack, HStack, ZStack
   - GeometryReader
   - Grid, LazyVGrid, LazyHGrid

3. **スタイリング**
   - Color, Font, Image
   - ViewModifier
   - DesignTokens による統一

4. **アニメーション**
   - .animation(), withAnimation
   - Transition
   - MatchedGeometryEffect

5. **状態管理**
   - @State, @Binding, @ObservedObject
   - @EnvironmentObject
   - @AppStorage

### ❌ UIKit を使わないもの

1. **UI コンポーネント**
   - ~~UILabel, UIButton, UIImageView~~
   - ~~UITableView, UICollectionView~~
   - ~~UINavigationBar, UITabBar~~

2. **Appearance API**
   - ~~UINavigationBar.appearance()~~
   - ~~UITabBar.appearance()~~
   - ~~UIFont, UIColor (SwiftUI 内で)~~

3. **レイアウト**
   - ~~Auto Layout, NSLayoutConstraint~~
   - ~~UIStackView~~

4. **View Controller**
   - ~~UIViewController~~
   - ~~UINavigationController~~
   - ~~UITabBarController~~

### ⚠️ 例外的に UIKit を使う場合

以下のケースのみ、UIKit 使用を許可：

1. **AVFoundation との統合**
   - AVAudioSession（SwiftUI に相当機能なし）
   - AVAudioEngine（オーディオ処理）

2. **UIKit でしか実現できない機能**
   - 特定のシステム API（iOS 17 時点で SwiftUI 未対応のもの）
   - サードパーティライブラリが UIKit 前提の場合

3. **パフォーマンス最適化**
   - 明確なパフォーマンス問題があり、SwiftUI では解決不可能な場合のみ

**重要**: UIKit を使用する場合は、必ず理由をコメントで明記すること。

---

## 🚫 典型的な間違い例

### ❌ 間違い 1: UIKit Appearance API の使用

```swift
// ❌ これは使わない
let appearance = UINavigationBarAppearance()
appearance.configureWithOpaqueBackground()
appearance.backgroundColor = UIColor(...)
appearance.titleTextAttributes = [.font: UIFont.monospacedSystemFont(...)]
UINavigationBar.appearance().standardAppearance = appearance
```

**問題点**:
- グローバル適用で画面ごとの差異を表現できない
- SwiftUI の `.toolbarBackground` と競合する
- `UIColor` と `Color` の変換が必要

**正しい方法**:
```swift
// ✅ SwiftUI の標準 Modifier を使う
.toolbarBackground(
    DesignTokens.NavigationBar.backgroundColor,
    for: .navigationBar
)
.toolbarBackground(.visible, for: .navigationBar)
.font(.system(size: 17, weight: .semibold, design: .monospaced))
```

---

### ❌ 間違い 2: UIFont の使用

```swift
// ❌ これは使わない
public static func monospacedTitleFont() -> UIFont {
    UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold)
}
```

**問題点**:
- SwiftUI の `Font` と型が異なる
- 変換が必要で冗長
- macOS / watchOS で動作しない

**正しい方法**:
```swift
// ✅ SwiftUI の Font を使う
public static let monospacedTitleFont = Font.system(
    size: 17,
    weight: .semibold,
    design: .monospaced
)
```

---

### ❌ 間違い 3: UIColor の使用

```swift
// ❌ これは使わない
public static let backgroundColor = UIColor(
    red: 0x0A/255.0,
    green: 0x0D/255.0,
    blue: 0x15/255.0,
    alpha: 1.0
)
```

**問題点**:
- SwiftUI の `Color` と型が異なる
- Dynamic Color（ダークモード対応）が面倒
- macOS / watchOS で動作しない

**正しい方法**:
```swift
// ✅ SwiftUI の Color を使う
public static let backgroundColor = Color(
    red: 0x0A/255.0,
    green: 0x0D/255.0,
    blue: 0x15/255.0
)
```

---

### ❌ 間違い 4: UIKit と SwiftUI の混在

```swift
// ❌ これは使わない
struct MyView: UIViewRepresentable {
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = "Hello"
        return label
    }
    func updateUIView(_ uiView: UILabel, context: Context) {}
}
```

**問題点**:
- SwiftUI の宣言的 UI と UIKit の命令的 UI が混在
- 状態管理が複雑化
- 保守性が著しく低下

**正しい方法**:
```swift
// ✅ SwiftUI の Text を使う
struct MyView: View {
    var body: some View {
        Text("Hello")
    }
}
```

---

## ✅ SwiftUI で実現できること（iOS 16+）

### 1. カスタムフォント

```swift
// モノスペース
.font(.system(size: 17, weight: .semibold, design: .monospaced))

// 丸ゴシック
.font(.system(size: 17, weight: .semibold, design: .rounded))

// セリフ
.font(.system(size: 17, weight: .semibold, design: .serif))
```

### 2. Navigation Bar のカスタマイズ

```swift
// 背景色
.toolbarBackground(Color.blue, for: .navigationBar)
.toolbarBackground(.visible, for: .navigationBar)

// タイトルモード
.navigationBarTitleDisplayMode(.inline)

// ツールバーアイテム
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        Button("Back") { }
    }
}
```

### 3. 背景グラデーション

```swift
// 線形グラデーション
LinearGradient(
    colors: [.blue, .purple],
    startPoint: .top,
    endPoint: .bottom
)

// 放射状グラデーション
RadialGradient(
    colors: [.blue, .purple],
    center: .center,
    startRadius: 0,
    endRadius: 200
)
```

### 4. カスタムシェイプ

```swift
struct MyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // カスタムパスを描画
        return path
    }
}
```

### 5. アニメーション

```swift
// 暗黙的アニメーション
.animation(.easeInOut, value: isExpanded)

// 明示的アニメーション
withAnimation {
    isExpanded.toggle()
}

// カスタムトランジション
.transition(.asymmetric(
    insertion: .move(edge: .leading),
    removal: .move(edge: .trailing)
))
```

---

## 🆚 UIKit vs SwiftUI 比較表

| 機能 | UIKit | SwiftUI (iOS 16+) | 推奨 |
|------|-------|-------------------|------|
| **ボタン** | UIButton | Button | ✅ SwiftUI |
| **テキスト** | UILabel | Text | ✅ SwiftUI |
| **画像** | UIImageView | Image | ✅ SwiftUI |
| **リスト** | UITableView | List | ✅ SwiftUI |
| **ナビゲーション** | UINavigationController | NavigationStack | ✅ SwiftUI |
| **タブバー** | UITabBarController | TabView | ✅ SwiftUI |
| **カスタムフォント** | UIFont | Font.system(design:) | ✅ SwiftUI |
| **カラー** | UIColor | Color | ✅ SwiftUI |
| **グラデーション** | CAGradientLayer | LinearGradient | ✅ SwiftUI |
| **アニメーション** | UIView.animate | .animation() | ✅ SwiftUI |
| **レイアウト** | Auto Layout | VStack/HStack/ZStack | ✅ SwiftUI |
| **オーディオセッション** | AVAudioSession | なし | ⚠️ UIKit（例外） |

---

## 🔧 DesignTokens との統合

### 推奨構造

```swift
// DesignTokens は SwiftUI 型を使用
public struct DesignTokens {

    public struct Colors {
        /// SwiftUI の Color を使う
        public static let primary = Color(red: 0.2, green: 0.4, blue: 0.8)
        public static let secondary = Color(red: 0.8, green: 0.2, blue: 0.4)
    }

    public struct Typography {
        /// SwiftUI の Font を使う
        public static let headline = Font.system(
            size: 20,
            weight: .bold,
            design: .rounded
        )
        public static let body = Font.system(
            size: 16,
            weight: .regular,
            design: .default
        )
    }

    public struct Spacing {
        /// SwiftUI の CGFloat を使う
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
    }
}
```

### View での使用

```swift
struct MyView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Text("Hello")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.primary)

            Text("World")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
        .padding(DesignTokens.Spacing.large)
    }
}
```

---

## 🚀 UIKit コードの SwiftUI 化手順

### Step 1: UIKit 依存を特定

```bash
# UIKit import を検索
grep -r "import UIKit" clock-tsukiusagi/

# UIKit 型を検索
grep -r "UIColor\|UIFont\|UIView\|UILabel" clock-tsukiusagi/
```

### Step 2: SwiftUI 型に置き換え

| UIKit 型 | SwiftUI 型 | 変換方法 |
|----------|-----------|----------|
| `UIColor` | `Color` | `Color(uiColor: myUIColor)` または直接定義 |
| `UIFont` | `Font` | `Font.system(size:weight:design:)` |
| `CGColor` | `Color` | `Color(cgColor: myCGColor)` |
| `UIImage` | `Image` | `Image(uiImage: myUIImage)` |

### Step 3: Appearance API を削除

```swift
// Before
UINavigationBar.appearance().standardAppearance = appearance

// After
// 削除して、各 View で .toolbarBackground を使用
```

### Step 4: ViewModifier に統合

```swift
// カスタム Modifier を作成して共通化
public struct MyStyleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(DesignTokens.Typography.headline)
            .foregroundColor(DesignTokens.Colors.primary)
    }
}

extension View {
    public func myStyle() -> some View {
        modifier(MyStyleModifier())
    }
}
```

---

## 📋 チェックリスト

新しいコードを追加する際の確認項目：

- [ ] `import UIKit` を使っていないか？
- [ ] `UIColor`, `UIFont` などの UIKit 型を使っていないか？
- [ ] SwiftUI の標準 API で実現可能か確認したか？
- [ ] DesignTokens を使用しているか？
- [ ] UIKit を使う場合、理由をコメントで明記したか？
- [ ] macOS / watchOS / visionOS で動作するか考慮したか？

---

## 🎓 学習リソース

### Apple 公式ドキュメント

- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [What's new in SwiftUI (WWDC)](https://developer.apple.com/videos/)

### 推奨記事

- [SwiftUI vs UIKit: When to use which](https://www.hackingwithswift.com/quick-start/swiftui/swiftui-vs-interface-builder-and-storyboards)
- [Modern SwiftUI Techniques](https://www.pointfree.co/collections/swiftui)

---

## 📝 まとめ

### 原則

1. **SwiftUI-First**: すべて SwiftUI で実装する
2. **UIKit は例外のみ**: AVAudioSession など、SwiftUI に相当機能がない場合のみ
3. **DesignTokens 統一**: SwiftUI 型（Color, Font）で定義
4. **クロスプラットフォーム**: macOS / watchOS / visionOS を考慮

### 禁止事項

- ❌ UIKit Appearance API の使用
- ❌ UIColor, UIFont の DesignTokens での使用
- ❌ UIViewRepresentable の不要な使用
- ❌ UIKit と SwiftUI の無計画な混在

### 例外ルール

UIKit を使用する場合は必ず：
1. コメントで理由を明記
2. 最小限の範囲に限定
3. SwiftUI でラップして使用

---

**clock-tsukiusagi は SwiftUI-First。UIKit は過去のもの。新しい時代の設計で進める。**
