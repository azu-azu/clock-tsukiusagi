# Navigation Design - タブバー統合とナビゲーションバー設計

## 概要

Audio と AudioSettingsView のナビゲーション設計について記録。
Clock画面のフルスクリーン体験を維持しつつ、他の画面では統一されたナビゲーションUIを提供する。

## アーキテクチャ

### タブ管理

**Tab enum の定義（ContentView.swift）**
```swift
public enum Tab: CaseIterable {
    case clock
    case audioPlayback
    case settings
    case appSettings

    /// 次のタブ（左スワイプ時）
    var next: Tab? {
        let all = Tab.allCases
        guard let index = all.firstIndex(of: self),
              index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// 前のタブ（右スワイプ時）
    var previous: Tab? {
        let all = Tab.allCases
        guard let index = all.firstIndex(of: self),
              index > 0 else { return nil }
        return all[index - 1]
    }
}
```

- `public` で定義し、全画面からアクセス可能
- `CaseIterable` でタブ順序を管理（スワイプナビゲーション用）
- `next` / `previous` プロパティでタブ間遷移をサポート
- ContentView で `@State private var selectedTab: Tab` を管理
- 子ビューには `@Binding var selectedTab: Tab` で渡す

### タブの順序

```
Clock → Audio → AudioSettings → AppSettings
```

| インデックス | タブ | 左スワイプ | 右スワイプ |
|-------------|------|-----------|-----------|
| 0 | Clock | → Audio | SideMenu（左端からのみ） |
| 1 | Audio | → AudioSettings | → Clock |
| 2 | AudioSettings | → AppSettings | → Audio |
| 3 | AppSettings | (なし) | → AudioSettings |

### ナビゲーション方式の使い分け

#### Clock画面
- **カスタムタブバー表示**: あり（上部2つのアイコン）
- **NavigationView**: なし
- **表示アイコン**: Settings、Audio（現在のClockアイコンは非表示）
- **目的**: フルスクリーンの時計表示を維持

```swift
// ContentView.swift
if selectedTab == .clock {
    HStack(spacing: 0) {
        TabButton(icon: "slider.horizontal.3", label: "Settings", ...)
        TabButton(icon: "music.quarternote.3", label: "Audio", ...)
    }
}
```

#### Audio / Settings画面
- **カスタムタブバー表示**: なし
- **NavigationView**: あり
- **ナビバーツールバー**: 左端と右端に1つずつアイコン配置
- **表示アイコン**: 現在のページ以外の2つ
- **目的**: ナビバー統合による統一感とクリーンなUI

```swift
// AudioSettingsView
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        Button { selectedTab = .clock } label: { ... }  // Clock
    }
    ToolbarItem(placement: .navigationBarTrailing) {
        Button { selectedTab = .audioPlayback } label: { ... }  // Audio
    }
    // Settings アイコンは非表示（現在のページ）
}
```

## ナビゲーションバーの外観設計

### 基本方針

1. **透明性とブラー効果の使い分け**
   - スクロール前: 完全透明（背景グラデーションと一体化）
   - スクロール時: ブラー効果（コンテンツを美しくぼかす）

2. **カスタムフォント**
   - Large Title: 28pt、太字、丸ゴシック体（`.rounded`）
   - Inline Title: 17pt、セミボールド、丸ゴシック体（`.rounded`）

### 実装パターン

```swift
private func configureNavigationBarAppearance() {
    // スクロール時の appearance（ブラーあり）
    let scrolledAppearance = UINavigationBarAppearance()
    scrolledAppearance.configureWithDefaultBackground()
    scrolledAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    scrolledAppearance.backgroundColor = .clear
    scrolledAppearance.shadowColor = .clear

    // フォント設定（丸ゴシック体）
    let largeTitleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
    let largeTitleDescriptor = largeTitleFont.fontDescriptor.withDesign(.rounded) ?? largeTitleFont.fontDescriptor
    scrolledAppearance.largeTitleTextAttributes = [
        .font: UIFont(descriptor: largeTitleDescriptor, size: 28),
        .foregroundColor: UIColor.white
    ]

    let inlineTitleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    let inlineTitleDescriptor = inlineTitleFont.fontDescriptor.withDesign(.rounded) ?? inlineTitleFont.fontDescriptor
    scrolledAppearance.titleTextAttributes = [
        .font: UIFont(descriptor: inlineTitleDescriptor, size: 17),
        .foregroundColor: UIColor.white
    ]

    // スクロールしていない時の appearance（完全透明）
    let transparentAppearance = UINavigationBarAppearance()
    transparentAppearance.configureWithTransparentBackground()
    transparentAppearance.backgroundEffect = nil
    transparentAppearance.backgroundColor = .clear
    transparentAppearance.shadowColor = .clear
    transparentAppearance.largeTitleTextAttributes = scrolledAppearance.largeTitleTextAttributes
    transparentAppearance.titleTextAttributes = scrolledAppearance.titleTextAttributes

    UINavigationBar.appearance().standardAppearance = scrolledAppearance
    UINavigationBar.appearance().scrollEdgeAppearance = transparentAppearance
}
```

### 重要な設定項目

| 項目 | スクロール前 | スクロール時 | 理由 |
|------|------------|------------|------|
| `backgroundEffect` | `nil` | `UIBlurEffect(.systemUltraThinMaterialDark)` | スクロール時のみブラー |
| `backgroundColor` | `.clear` | `.clear` | 常に透明 |
| `shadowColor` | `.clear` | `.clear` | 境界線を表示しない |
| 適用先 | `scrollEdgeAppearance` | `standardAppearance` | スクロール状態で切り替え |

## アイコン設計

### 使用アイコン

| 画面 | アイコン | SF Symbol | サイズ |
|------|---------|-----------|--------|
| Clock | 時計 | `clock.fill` | 20pt（ナビバー）、22pt（タブバー） |
| Audio | 音符 | `music.quarternote.3` | 20pt（ナビバー）、22pt（タブバー） |
| Settings | スライダー | `slider.horizontal.3` | 20pt（ナビバー）、22pt（タブバー） |

### アイコン配置ルール

1. **現在のページのアイコンは非表示**
   - Clock画面: Settings + Audio のみ表示
   - Audio画面: Clock + Settings のみ表示
   - Settings画面: Clock + Audio のみ表示

2. **ナビバーでの配置**
   - 左端（`.navigationBarLeading`）: 1つ
   - 右端（`.navigationBarTrailing`）: 1つ
   - バランスの取れた配置

3. **カラー**
   - `.foregroundColor(.white.opacity(0.8))`
   - 背景に溶け込みつつ視認性を確保

## 実装時の注意点

### ✅ DO（推奨）

1. **Tab enum は public に保つ**
   ```swift
   public enum Tab { ... }
   ```
   - 全ビューからアクセスできるようにする

2. **@Binding で selectedTab を渡す**
   ```swift
   public init(selectedTab: Binding<Tab>) {
       _selectedTab = selectedTab
       configureNavigationBarAppearance()
   }
   ```
   - 双方向バインディングでタブ切り替えを実現

3. **2つの Appearance を使い分ける**
   - `scrollEdgeAppearance`: スクロール前（透明）
   - `standardAppearance`: スクロール時（ブラー）

4. **フォント設定は両方の Appearance に適用**
   ```swift
   transparentAppearance.largeTitleTextAttributes = scrolledAppearance.largeTitleTextAttributes
   transparentAppearance.titleTextAttributes = scrolledAppearance.titleTextAttributes
   ```

5. **UIFont.fontDescriptor.withDesign(.rounded) を使う**
   ```swift
   let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
   let roundedFont = UIFont(descriptor: descriptor, size: size)
   ```
   - `UIFont.systemFont(ofSize:weight:design:)` は存在しない

### ❌ DON'T（禁止）

1. **UINavigationBar.appearance() をグローバルに設定しない**
   - 各ビューの `init()` 内で設定すること
   - 他のビューへの影響を避ける

2. **完全透明とブラーを混同しない**
   ```swift
   // ❌ 間違い
   appearance.configureWithTransparentBackground()
   appearance.backgroundEffect = UIBlurEffect(...)  // 効果なし

   // ✅ 正しい
   appearance.configureWithDefaultBackground()
   appearance.backgroundEffect = UIBlurEffect(...)
   ```

3. **shadowColor を設定し忘れない**
   ```swift
   appearance.shadowColor = .clear  // 境界線を消す
   ```

4. **HStack で複数のツールバーアイテムを配置しない**
   ```swift
   // ❌ 間違い（右端に2つ並ぶ）
   ToolbarItem(placement: .navigationBarTrailing) {
       HStack {
           Button { ... }
           Button { ... }
       }
   }

   // ✅ 正しい（左右に分散）
   ToolbarItem(placement: .navigationBarLeading) {
       Button { ... }
   }
   ToolbarItem(placement: .navigationBarTrailing) {
       Button { ... }
   }
   ```

5. **TabButton のアイコン名を直接変更しない**
   - アイコン変更時は全箇所を検索して統一すること
   - 現在使用: `music.quarternote.3`（Audio）、`slider.horizontal.3`（Settings）

## デザイントークンとの統合

ナビゲーションバーのスタイリングは、可能な限り DesignTokens を参照すること。

```swift
// 将来的な改善案
DesignTokens.NavigationBarColors.background
DesignTokens.NavigationBarTypography.largeTitle
DesignTokens.NavigationBarSpacing.iconSize
```

現状は UIKit の制約により直接設定しているが、将来的にはトークン化を検討。

## トラブルシューティング

### 問題: ナビバーに枠や境界線が表示される

**原因**: `shadowColor` が設定されていない、または `backgroundColor` が透明でない

**解決策**:
```swift
appearance.shadowColor = .clear
appearance.backgroundColor = .clear
```

### 問題: ブラー効果が表示されない

**原因**: `configureWithTransparentBackground()` を使っている

**解決策**:
```swift
// ブラーを使う場合
appearance.configureWithDefaultBackground()
appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
```

### 問題: フォントが丸ゴシックにならない

**原因**: `UIFont.systemFont(ofSize:weight:design:)` を使っている（存在しないAPI）

**解決策**:
```swift
let font = UIFont.systemFont(ofSize: 28, weight: .bold)
let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
let roundedFont = UIFont(descriptor: descriptor, size: 28)
```

### 問題: タブ切り替えができない

**原因**: `@Binding` の設定が正しくない、または Tab enum が private

**解決策**:
1. Tab enum を `public` にする
2. `@Binding var selectedTab: Tab` を追加
3. `init(selectedTab: Binding<Tab>)` で受け取る
4. `_selectedTab = selectedTab` で初期化

## スワイプナビゲーション

### 実装（ContentView.swift）

```swift
/// スワイプジェスチャー（全画面）
/// - 左スワイプ: 次のタブへ遷移
/// - 右スワイプ: 前のタブへ遷移（Clock画面では左端からのみSideMenu開く）
private func sideMenuDragGesture() -> some Gesture {
    DragGesture()
        .onEnded { value in
            let horizontalAmount = value.translation.width
            let verticalAmount = abs(value.translation.height)
            let swipeThreshold: CGFloat = 50

            // 水平方向のスワイプのみ処理（垂直スクロールとの競合を避ける）
            guard abs(horizontalAmount) > verticalAmount else { return }

            // 右スワイプ（前のタブへ）
            if horizontalAmount > swipeThreshold && !isMenuPresented {
                if selectedTab == .clock {
                    // Clock画面：左端20px以内からのスワイプ → メニューを開く
                    if value.startLocation.x <= 20 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuPresented = true
                        }
                    }
                } else if let prev = selectedTab.previous {
                    // その他の画面：前のタブへ
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = prev
                    }
                }
            }
            // 左スワイプ（次のタブへ）
            else if horizontalAmount < -swipeThreshold {
                if isMenuPresented {
                    // メニューが開いている → 閉じる
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMenuPresented = false
                    }
                } else if let next = selectedTab.next {
                    // 次のタブへ
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = next
                    }
                }
            }
        }
}
```

### 重要なポイント

1. **ContentView全体に適用**: `.gesture(sideMenuDragGesture())` でルートに適用
2. **Tab.next / Tab.previous**: タブ順序はenumの定義順に従う
3. **Clock画面の特殊処理**: 右スワイプは左端からのみSideMenuを開く
4. **垂直スクロールとの競合回避**: `abs(horizontalAmount) > verticalAmount` でチェック

## 関連ファイル

- `TsukiSound/App/ContentView.swift` - タブ管理、スワイプナビゲーション、カスタムタブバー
- `TsukiSound/Features/Settings/Views/AudioSettingsView.swift` - ナビバー実装例
- `TsukiSound/Features/Audio/Views/AudioPlaybackView.swift` - ナビバー実装例
- `TsukiSound/DesignSystem/DesignTokens.swift` - デザイントークン定義
- `TsukiSound/DesignSystem/Navigation/NavigationBackModifier.swift` - カスタムBackボタン

## 変更履歴

- 2025-12-10: スワイプナビゲーション追加（全画面対応、Tab.next/previous）
- 2025-11-16: 初版作成 - タブバー統合とナビバー透明化の設計を記録
