# Environment と ObservableObject の落とし穴ガイド

**作成日**: 2025-11-21
**対象**: SwiftUI アプリ開発全般

---

## 概要

SwiftUI で `@AppStorage` と `ObservableObject` を組み合わせて Environment 経由で設定値を配信する際、**設定変更が即座に全画面に反映されない**という問題が発生することがあります。

このドキュメントでは、その原因と解決策を汎用的に解説します。

---

## 問題の症状

### 典型的なシナリオ

1. アプリに **Settings 画面**と**他の画面**がある
2. Settings 画面で `@AppStorage` を使って設定値を変更
3. **Settings 画面自体**は即座に反映される
4. しかし、**他の画面**（別タブ、サイドメニューなど）には反映されない
5. アプリを再起動すると反映される

### 具体例

```swift
// Settings 画面
@AppStorage("theme") var theme: String = "light"

// 他の画面
@Environment(\.theme) var theme: String  // ← 変更が反映されない
```

---

## 根本原因

### 原因1: ObservableObject が `@AppStorage` の変更を通知していない

SwiftUI では、`@AppStorage` は **View 内でのみ自動的に再描画をトリガー**します。

しかし、`ObservableObject` のプロパティとして `@AppStorage` を使った場合：

```swift
// ❌ 問題のあるコード
class ThemeProvider: ObservableObject {
    @AppStorage("theme") var theme: String = "light"
}
```

**何が起こるか：**
1. Settings 画面が `@AppStorage` を直接変更
2. UserDefaults は更新される
3. **しかし `ThemeProvider` は `objectWillChange` を送信しない**
4. Environment が更新されない
5. 他の画面が再描画されない

### 原因2: View が画面遷移時に再生成されている

一部の画面では「反映されている」ように見える場合があります：

```swift
// ContentView.swift
switch selectedTab {
case .settings:
    SettingsView()  // ← 設定変更
case .home:
    HomeView()      // ← 画面遷移で「反映されたように見える」
}
```

**実際の動作：**
- Settings → Home に遷移
- `HomeView` が**新しく生成される**
- 生成時に**最新の UserDefaults を読み込む**
- → 反映されているように見える

**しかし：**
- これは「リアルタイム反映」ではない
- 同じ画面を開いたままでは反映されない
- サイドメニューなど常に存在する View には反映されない

---

## 解決策

### ✅ 正しい実装パターン

```swift
import SwiftUI
import Combine

// MARK: - ObservableObject with UserDefaults Sync

class ThemeProvider: ObservableObject {
    // @Published で変更を通知
    @Published var theme: String {
        didSet {
            // UserDefaults に保存
            UserDefaults.standard.set(theme, forKey: "theme")
        }
    }

    init() {
        // UserDefaults から初期値を読み込み
        self.theme = UserDefaults.standard.string(forKey: "theme") ?? "light"

        // UserDefaults の変更を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func userDefaultsDidChange() {
        // 他の画面が @AppStorage で直接変更した場合も検知
        if let newTheme = UserDefaults.standard.string(forKey: "theme"),
           newTheme != theme {
            DispatchQueue.main.async {
                self.theme = newTheme
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

### データフロー

```
Settings 画面が @AppStorage 変更
  ↓
UserDefaults に書き込み
  ↓
UserDefaults.didChangeNotification 発火
  ↓
ThemeProvider.userDefaultsDidChange() が呼ばれる
  ↓
theme プロパティが更新される（@Published）
  ↓
objectWillChange が送信される
  ↓
Environment(\.theme) が更新される
  ↓
全ての画面が即座に再描画される
```

---

## Environment への配信

### EnvironmentKey の定義

```swift
import SwiftUI

// MARK: - Environment Key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: String = "light"
}

extension EnvironmentValues {
    var theme: String {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

### App レベルでの注入

```swift
import SwiftUI

@main
struct MyApp: App {
    @StateObject private var themeProvider = ThemeProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.theme, themeProvider.theme)
        }
    }
}
```

または ViewModifier 経由：

```swift
struct AppThemeModifier: ViewModifier {
    @ObservedObject var provider: ThemeProvider

    func body(content: Content) -> some View {
        content
            .environment(\.theme, provider.theme)
    }
}

extension View {
    func withThemeProvider(_ provider: ThemeProvider) -> some View {
        modifier(AppThemeModifier(provider: provider))
    }
}

// 使用例
ContentView()
    .withThemeProvider(themeProvider)
```

---

## View での使用

### パターン1: Environment で読む

```swift
struct HomeView: View {
    @Environment(\.theme) var theme: String

    var body: some View {
        Text("Current theme: \(theme)")
    }
}
```

### パターン2: ViewModifier で使う

```swift
struct DynamicThemedText: ViewModifier {
    @Environment(\.theme) private var theme: String

    func body(content: Content) -> some View {
        content
            .foregroundColor(theme == "dark" ? .white : .black)
    }
}

extension View {
    func themedText() -> some View {
        modifier(DynamicThemedText())
    }
}

// 使用例
Text("Hello")
    .themedText()  // ← theme が変わると自動的に色が変わる
```

---

## よくある間違い

### ❌ 間違い1: @AppStorage を ObservableObject でそのまま使う

```swift
// ❌ 動かない
class SettingsProvider: ObservableObject {
    @AppStorage("setting") var setting: String = "default"
}
```

**問題**: `objectWillChange` が送信されない

### ❌ 間違い2: View が Environment を監視していない

```swift
// ❌ 再描画されない
struct MyView: View {
    // @Environment(\.theme) を持っていない

    var body: some View {
        Text("Hello")
            .themedText()  // ← modifier は Environment を読んでいるが View 自体は監視していない
    }
}
```

**注意**: 実際には、`.themedText()` modifier 自体が `@Environment` を持っているので、多くの場合は動作します。しかし、明示的に `@Environment` を持つ方が確実です。

### ❌ 間違い3: 画面遷移での「見かけの反映」に騙される

```swift
// Settings → Home に遷移すると「反映された」ように見える
// しかし、Home 画面を開いたままでは反映されない
```

**対策**: Settings 画面を開いたまま、別の方法（デバッガなど）で UserDefaults を変更して、即座に反映されるかテストする。

---

## チェックリスト

設定値の Environment 配信を実装する際のチェックリスト：

- [ ] `ObservableObject` は `@Published` を使っている
- [ ] `UserDefaults.didChangeNotification` を監視している
- [ ] `didSet` で UserDefaults に保存している
- [ ] `EnvironmentKey` を定義している
- [ ] App レベルで `.environment()` または `.withProvider()` で注入している
- [ ] 各 View で `.modifier()` または `@Environment` で読んでいる
- [ ] **Settings 画面を開いたまま、他の画面で即座に反映されるかテストした**

---

## 実装例（完全版）

### 1. Model 定義

```swift
// ThemeStyle.swift
import Foundation

enum ThemeStyle: String, Codable, CaseIterable {
    case light
    case dark

    static let userDefaultsKey = "app_theme"
}
```

### 2. Provider 実装

```swift
// ThemeProvider.swift
import SwiftUI
import Combine

class ThemeProvider: ObservableObject {
    @Published var theme: ThemeStyle {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: ThemeStyle.userDefaultsKey)
        }
    }

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: ThemeStyle.userDefaultsKey),
           let style = ThemeStyle(rawValue: rawValue) {
            self.theme = style
        } else {
            self.theme = .light
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func userDefaultsDidChange() {
        if let rawValue = UserDefaults.standard.string(forKey: ThemeStyle.userDefaultsKey),
           let newTheme = ThemeStyle(rawValue: rawValue),
           newTheme != theme {
            DispatchQueue.main.async {
                self.theme = newTheme
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

### 3. Environment Key

```swift
// ThemeEnvironment.swift
import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: ThemeStyle = .light
}

extension EnvironmentValues {
    var theme: ThemeStyle {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

### 4. App レベルでの統合

```swift
// MyApp.swift
import SwiftUI

@main
struct MyApp: App {
    @StateObject private var themeProvider = ThemeProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.theme, themeProvider.theme)
        }
    }
}
```

### 5. Settings 画面

```swift
// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @AppStorage(ThemeStyle.userDefaultsKey) private var themeRaw: String = ThemeStyle.light.rawValue

    private var theme: ThemeStyle {
        ThemeStyle(rawValue: themeRaw) ?? .light
    }

    var body: some View {
        VStack {
            Text("Theme Settings")
                .font(.title)

            ForEach(ThemeStyle.allCases, id: \.self) { style in
                Button(action: {
                    themeRaw = style.rawValue
                }) {
                    HStack {
                        Text(style.rawValue.capitalized)
                        Spacer()
                        if theme == style {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .padding()
    }
}
```

### 6. 他の画面での使用

```swift
// HomeView.swift
import SwiftUI

struct HomeView: View {
    @Environment(\.theme) var theme: ThemeStyle

    var body: some View {
        VStack {
            Text("Home Screen")
                .font(.title)
                .foregroundColor(theme == .dark ? .white : .black)

            Text("Current theme: \(theme.rawValue)")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme == .dark ? Color.black : Color.white)
    }
}
```

---

## デバッグ方法

### 問題が起きたら確認すること

1. **Provider が通知しているか？**
   ```swift
   init() {
       // ...
       print("🔔 ThemeProvider initialized")
   }

   @objc private func userDefaultsDidChange() {
       print("🔔 UserDefaults changed detected")
       // ...
   }
   ```

2. **Environment が更新されているか？**
   ```swift
   struct HomeView: View {
       @Environment(\.theme) var theme: ThemeStyle

       var body: some View {
           Text("Theme: \(theme.rawValue)")
               .onChange(of: theme) { newValue in
                   print("🔔 HomeView detected theme change: \(newValue)")
               }
       }
   }
   ```

3. **画面遷移なしで反映されるか？**
   - Settings 画面を開いたまま
   - Xcode の Debug Memory Graph で UserDefaults を直接変更
   - 他の画面が即座に変わるか確認

---

## パフォーマンスへの影響

### NotificationCenter の監視によるオーバーヘッド

`UserDefaults.didChangeNotification` は **全ての UserDefaults 変更**で発火します。

**対策**:
1. 変更前と変更後を比較して、実際に変わった場合のみ更新
2. 複数の設定値を1つの Provider で管理する場合、各設定値ごとに比較

```swift
@objc private func userDefaultsDidChange() {
    var changed = false

    if let newTheme = UserDefaults.standard.string(forKey: ThemeStyle.userDefaultsKey),
       let theme = ThemeStyle(rawValue: newTheme),
       theme != self.theme {
        self.theme = theme
        changed = true
    }

    // 他の設定値も同様にチェック

    if changed {
        // 必要に応じて追加の処理
    }
}
```

---

## まとめ

### 重要なポイント

1. **`@AppStorage` を `ObservableObject` で使う場合は `@Published` + `NotificationCenter` で監視**
2. **画面遷移での「見かけの反映」に騙されない**
3. **Settings 画面を開いたまま、他の画面で即座に反映されるかテスト**
4. **Environment 経由で全画面に配信すれば、リアルタイム反映が実現できる**

### この実装パターンが有効なケース

- テーマ切り替え（Light/Dark）
- フォントスタイル切り替え
- 言語切り替え
- 表示単位切り替え（摂氏/華氏、km/mile など）
- その他、アプリ全体に影響する設定値

---

**関連ドキュメント**:
- [Apple Documentation: ObservableObject](https://developer.apple.com/documentation/combine/observableobject)
- [Apple Documentation: Environment](https://developer.apple.com/documentation/swiftui/environment)
- [Apple Documentation: AppStorage](https://developer.apple.com/documentation/swiftui/appstorage)

---

**更新履歴**:
- 2025-11-21: 初版作成
