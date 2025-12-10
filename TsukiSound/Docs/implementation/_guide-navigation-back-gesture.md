# Navigation Back Gesture - カスタム戻る操作実装ガイド

**作成日**: 2025-11-22
**最終更新**: 2025-12-10

## 概要

Settings/Audio画面でのカスタムBackボタンの実装ガイドです。

本アプリはタブベースのナビゲーション（`selectedTab`による画面切り替え）を採用しているため、標準のNavigationViewの戻る動作では正しく機能しません。`NavigationBackModifier`を使用することで、カスタムBackボタンを提供します。

**注意**: スワイプによる画面遷移は `ContentView.swift` の `sideMenuDragGesture()` で一元管理されています。詳細は `_guide-navigation-design.md` の「スワイプナビゲーション」セクションを参照してください。

---

## なぜカスタム実装が必要か

### 標準NavigationViewの問題

SwiftUIの標準NavigationViewは、`NavigationLink`によるpush/pop方式を前提としています。しかし、本アプリでは以下の理由からこの方式を採用していません：

1. **タブベースのナビゲーション**: `@State var selectedTab: Tab`で画面を切り替える
2. **状態の明示的管理**: どの画面が表示されているかを明確に把握したい
3. **シンプルな構造**: NavigationStackの階層管理を避け、フラットな画面遷移を実現

### 本アプリのナビゲーション方式

```swift
// ContentView.swift
@State private var selectedTab: Tab = .clock

// 画面遷移は selectedTab を変更するだけ
selectedTab = .settings  // Settings画面に移動
selectedTab = .clock     // Clock画面に戻る
```

このため、標準の戻るボタンではなく、**selectedTabを変更するカスタム実装**が必要です。

---

## NavigationBackModifier

### 提供機能

`NavigationBackModifier`は以下の機能を提供します：

1. **カスタムBackボタン** - 左上に "< Back" ボタンを表示

**注意**: スワイプジェスチャーは `ContentView.swift` で一元管理されるため、このModifierでは提供しません。

**実装場所**: `DesignSystem/Navigation/NavigationBackModifier.swift`

---

## 使用方法

### 基本的な使い方

```swift
import SwiftUI

struct AudioSettingsView: View {
    @Binding var selectedTab: Tab

    var body: some View {
        NavigationView {
            ScrollView {
                // Settings content
            }
            .navigationTitle("Audio Settings")
            .navigationBackButton {
                selectedTab = .clock  // Clock画面に戻る
            }
        }
    }
}
```

### パラメータ

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| `onBack` | `() -> Void` | 戻る動作を実行するクロージャ |

通常は`selectedTab`を`.clock`に変更する処理を指定します。

---

## 実装詳細

### NavigationBackModifier.swift

```swift
struct NavigationBackModifier: ViewModifier {
    let onBack: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)  // 標準ボタンを非表示
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
    }
}
```

---

## 実装例

### AudioSettingsView

```swift
struct AudioSettingsView: View {
    @Binding var selectedTab: Tab
    @StateObject private var settings = AudioSettings()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Settings sections
                }
                .padding(.horizontal, 24)
            }
            .background(DesignTokens.SettingsColors.backgroundGradient)
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.large)
            .dynamicNavigationFont()
            .toolbarBackground(NavigationBarTokens.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBackButton {
                selectedTab = .audioPlayback  // ← Audio画面に戻る
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedTab = .audioPlayback  // Audioページに移動
                    }) {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }
}
```

### AppSettingsView

```swift
struct AppSettingsView: View {
    @Binding var selectedTab: Tab

    var body: some View {
        NavigationView {
            ScrollView {
                // App settings content
            }
            .navigationTitle("App Settings")
            .navigationBackButton {
                selectedTab = .settings  // ← AudioSettings画面に戻る
            }
        }
    }
}
```

### 戻り先の設計

| 画面 | Backボタンの戻り先 |
|------|-------------------|
| Audio | Clock |
| AudioSettings | Audio |
| AppSettings | AudioSettings |

**ポイント**: Backボタンは直前のタブ（`Tab.previous`）に戻る設計です。

---

## _guide-navigation-design.mdとの関係

### 役割分担

| ドキュメント | 担当範囲 |
|-------------|---------|
| **_guide-navigation-design.md** | ナビゲーションバーの外観設計、スワイプナビゲーション、タブ管理 |
| **_guide-navigation-back-gesture.md**（本ドキュメント） | カスタムBackボタンの実装 |

### 統合された実装例

```swift
.navigationTitle("Audio Settings")
.navigationBarTitleDisplayMode(.large)
.dynamicNavigationFont()  // ← _guide-navigation-design.mdで定義
.toolbarBackground(NavigationBarTokens.backgroundColor, for: .navigationBar)  // ← _guide-navigation-design.mdで定義
.navigationBackButton {  // ← 本ドキュメントで定義
    selectedTab = .audioPlayback  // Audio画面に戻る
}
```

---

## トラブルシューティング

### Q: スワイプジェスチャーが効かない

スワイプによる画面遷移は `ContentView.swift` の `sideMenuDragGesture()` で一元管理されています。
詳細は `_guide-navigation-design.md` の「スワイプナビゲーション」セクションを参照してください。

---

### Q: Backボタンが表示されない

**原因**: `.navigationBarBackButtonHidden(true)`が効いていない、またはツールバーの設定が上書きされている

**確認方法**:
```swift
// NavigationBackModifierの前に他の.toolbar設定がないか確認
.toolbar { ... }  // ← これが先だと上書きされる可能性
.navigationBackButton { ... }
```

**解決方法**:
```swift
// .navigationBackButton を先に適用
.navigationBackButton { selectedTab = .audioPlayback }
.toolbar {
    // 他のツールバーアイテム
}
```

---

## ベストプラクティス

### ✅ 推奨

1. **直前のタブに戻る**: `Tab.previous` に相当するタブに戻る（Audio→Clock、AudioSettings→Audio）
2. **シンプルな戻り先**: 各画面の戻り先は固定する

```swift
// AudioSettingsView
.navigationBackButton {
    selectedTab = .audioPlayback  // 直前のAudio画面に戻る
}
```

---

### ❌ 避けるべきパターン

1. **複雑な戻り先ロジック**: Backボタンで複数の画面に戻る分岐は避ける
2. **非同期処理の混在**: `onBack`内で非同期処理を行わない（状態が不安定になる）
3. **標準ボタンとの併用**: `.navigationBarBackButtonHidden(false)`との併用は混乱の元

---

## 参考資料

- [NavigationBackModifier.swift](../../DesignSystem/Navigation/NavigationBackModifier.swift) - カスタムBackボタン実装
- [_guide-navigation-design.md](_guide-navigation-design.md) - ナビゲーションバー外観設計、スワイプナビゲーション
- [Apple HIG - Navigation](https://developer.apple.com/design/human-interface-guidelines/navigation) - Apple公式ガイドライン

---

## 更新履歴

- **2025-12-10**: スワイプナビゲーションをContentViewに一元化、戻り先を直前のタブに変更
- **2025-11-22**: 初版作成（NavigationBackModifier実装を受けて）
