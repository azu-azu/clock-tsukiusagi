# Navigation Back Gesture - カスタム戻る操作実装ガイド

**作成日**: 2025-11-22
**最終更新**: 2025-11-22

## 概要

Settings/Audio画面でのカスタムBackボタンと、右スワイプジェスチャーによる戻る操作の実装ガイドです。

本アプリはタブベースのナビゲーション（`selectedTab`による画面切り替え）を採用しているため、標準のNavigationViewの戻る動作では正しく機能しません。`NavigationBackModifier`を使用することで、カスタムBackボタンと直感的なスワイプ操作を提供します。

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

`NavigationBackModifier`は以下の3つの機能を提供します：

1. **カスタムBackボタン** - 左上に "< Back" ボタンを表示
2. **右スワイプジェスチャー** - 50pt以上の右スワイプで戻る
3. **垂直スクロールとの競合回避** - ScrollView内でも正しく動作

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
```

### スワイプジェスチャーの仕組み

#### 判定条件

```swift
value.translation.width > 50 && abs(value.translation.height) < 100
```

| 条件 | 意味 | 理由 |
|------|------|------|
| `translation.width > 50` | 右方向に50pt以上移動 | 意図しない誤操作を防ぐ |
| `abs(translation.height) < 100` | 垂直移動が100pt未満 | ScrollViewとの競合を避ける |

#### 動作フロー

```
ユーザーがスワイプ開始
    ↓
DragGesture検知
    ↓
スワイプ終了（onEnded）
    ↓
水平移動量 > 50pt？
    ↓ YES
垂直移動量 < 100pt？
    ↓ YES
onBack()実行
    ↓
selectedTab = .clock
    ↓
Clock画面に戻る
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
                selectedTab = .clock  // ← カスタム戻る動作
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
                selectedTab = .clock  // ← カスタム戻る動作
            }
        }
    }
}
```

---

## 垂直スクロールとの競合回避

### 問題

Settings画面にはScrollViewがあります。ユーザーが上下スクロール中に横方向にも少し動かしてしまうと、意図せず戻る操作が発動してしまう可能性があります。

```
ユーザーの操作:
- 縦に100pt移動（スクロール）
- 横に60pt移動（ブレ）
→ 横移動が50pt以上なので戻ってしまう？
```

### 解決策

`abs(value.translation.height) < 100`という条件を追加することで、**垂直移動が大きい場合はスワイプと判定しない**ようにしています。

```swift
if value.translation.width > 50 && abs(value.translation.height) < 100 {
    onBack()
}
```

#### 動作例

| 水平移動 | 垂直移動 | 判定 | 結果 |
|---------|---------|------|------|
| 60pt → | 10pt ↓ | ✅ スワイプ | 戻る |
| 60pt → | 50pt ↓ | ✅ スワイプ | 戻る |
| 60pt → | 120pt ↓ | ❌ スクロール | 戻らない |
| 30pt → | 10pt ↓ | ❌ 距離不足 | 戻らない |

---

## navigation-design.mdとの関係

### 役割分担

| ドキュメント | 担当範囲 |
|-------------|---------|
| **navigation-design.md** | ナビゲーションバーの外観設計（フォント、ブラー、透明度） |
| **_guide-navigation-back-gesture.md**（本ドキュメント） | 戻る操作の実装（Backボタン、スワイプジェスチャー） |

### 統合された実装例

```swift
.navigationTitle("Audio Settings")
.navigationBarTitleDisplayMode(.large)
.dynamicNavigationFont()  // ← navigation-design.mdで定義
.toolbarBackground(NavigationBarTokens.backgroundColor, for: .navigationBar)  // ← navigation-design.mdで定義
.navigationBackButton {  // ← 本ドキュメントで定義
    selectedTab = .clock
}
```

---

## トラブルシューティング

### Q: スワイプジェスチャーが効かない

**原因1**: ScrollView内でのスワイプが垂直スクロールとして処理されている

**確認方法**:
- 画面の上端（スクロール範囲外）でスワイプしてみる
- スワイプ時の垂直移動量を確認（100pt未満か？）

**解決方法**:
- より水平方向を意識してスワイプする
- または、垂直移動の閾値を調整（`< 100` → `< 150`など）

---

**原因2**: DragGestureが他のジェスチャーと競合している

**確認方法**:
```swift
.gesture(
    DragGesture()
        .onChanged { value in
            print("🐛 translation: \(value.translation)")  // デバッグ出力
        }
        .onEnded { value in
            print("🐛 final: \(value.translation)")
        }
)
```

**解決方法**:
- 他のジェスチャーとの優先度を調整
- `.highPriorityGesture()` または `.simultaneousGesture()` の使用を検討

---

### Q: スクロール中に戻ってしまう

**原因**: 垂直移動の閾値が小さすぎる

**解決方法**:
```swift
// 閾値を増やす
if value.translation.width > 50 && abs(value.translation.height) < 150 {  // 100 → 150
    onBack()
}
```

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
.navigationBackButton { selectedTab = .clock }
.toolbar {
    // 他のツールバーアイテム
}
```

---

### Q: スワイプが敏感すぎる（誤動作が多い）

**原因**: 閾値が小さすぎる

**解決方法**:
```swift
// 閾値を増やす
if value.translation.width > 80 && abs(value.translation.height) < 100 {  // 50 → 80
    onBack()
}
```

---

## ベストプラクティス

### ✅ 推奨

1. **統一された戻り先**: 基本的にはClock画面（`.clock`）に戻る
2. **明示的なアニメーション**: `withAnimation`で滑らかな遷移を提供（必要に応じて）
3. **デバッグ時のログ出力**: スワイプ検知の動作確認には`print`を活用

```swift
.navigationBackButton {
    print("🔙 Navigating back to Clock")
    withAnimation(.easeInOut(duration: 0.3)) {
        selectedTab = .clock
    }
}
```

---

### ❌ 避けるべきパターン

1. **複雑な戻り先ロジック**: Backボタンで複数の画面に戻る分岐は避ける
2. **非同期処理の混在**: `onBack`内で非同期処理を行わない（状態が不安定になる）
3. **標準ボタンとの併用**: `.navigationBarBackButtonHidden(false)`との併用は混乱の元

---

## 将来の拡張可能性

### アニメーション付きスワイプ

現在は`onEnded`でスワイプ完了時のみ処理していますが、`onChanged`を使うことで、スワイプに追従してプレビューを表示する実装も可能です。

```swift
// 将来的な拡張例
@State private var swipeProgress: CGFloat = 0

.gesture(
    DragGesture()
        .onChanged { value in
            swipeProgress = max(0, value.translation.width / 300)  // 0.0 ~ 1.0
        }
        .onEnded { value in
            if value.translation.width > 50 && abs(value.translation.height) < 100 {
                onBack()
            } else {
                swipeProgress = 0
            }
        }
)
.offset(x: swipeProgress * 100)  // スワイプに追従
```

---

## 参考資料

- [NavigationBackModifier.swift](../../DesignSystem/Navigation/NavigationBackModifier.swift) - 実装ファイル
- [navigation-design.md](navigation-design.md) - ナビゲーションバー外観設計
- [Apple HIG - Navigation](https://developer.apple.com/design/human-interface-guidelines/navigation) - Apple公式ガイドライン

---

## 更新履歴

- **2025-11-22**: 初版作成（NavigationBackModifier実装を受けて）
