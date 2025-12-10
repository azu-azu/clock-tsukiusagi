# Navigation Design - タブベースナビゲーションとスワイプジェスチャー

## 概要

SwiftUIでタブベースのナビゲーションを実装する際の設計パターン。
標準のTabViewを使わず、`selectedTab`による画面切り替えとスワイプジェスチャーを組み合わせる手法。

---

## 1. タブ管理の基本パターン

### Tab enumの設計

```swift
public enum Tab: CaseIterable {
    case home
    case list
    case settings
    // ... 必要なタブを追加

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

**ポイント**:
- `public` で定義し、全画面からアクセス可能にする
- `CaseIterable` でタブ順序を自動管理
- `next` / `previous` でスワイプナビゲーションをサポート
- enumの定義順がそのままタブの順序になる

### 状態管理

```swift
// ContentView.swift（ルート）
@State private var selectedTab: Tab = .home

// 子ビューへは@Bindingで渡す
ChildView(selectedTab: $selectedTab)

// 子ビュー側
@Binding var selectedTab: Tab
```

---

## 2. スワイプナビゲーション

### 実装パターン

```swift
private func swipeNavigationGesture() -> some Gesture {
    DragGesture()
        .onEnded { value in
            let horizontalAmount = value.translation.width
            let verticalAmount = abs(value.translation.height)
            let swipeThreshold: CGFloat = 50

            // 水平方向のスワイプのみ処理（垂直スクロールとの競合を避ける）
            guard abs(horizontalAmount) > verticalAmount else { return }

            // 右スワイプ（前のタブへ）
            if horizontalAmount > swipeThreshold {
                if let prev = selectedTab.previous {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = prev
                    }
                }
            }
            // 左スワイプ（次のタブへ）
            else if horizontalAmount < -swipeThreshold {
                if let next = selectedTab.next {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = next
                    }
                }
            }
        }
}
```

### 適用方法

```swift
var body: some View {
    ZStack {
        // 画面切り替え
        switch selectedTab {
        case .home: HomeView(selectedTab: $selectedTab)
        case .list: ListView(selectedTab: $selectedTab)
        case .settings: SettingsView(selectedTab: $selectedTab)
        }
    }
    .gesture(swipeNavigationGesture())  // ルートに適用
}
```

### 特定画面での特殊処理

```swift
// 例：最初の画面で右スワイプ時にサイドメニューを開く
if horizontalAmount > swipeThreshold {
    if selectedTab == .home {
        // 左端からのスワイプのみメニューを開く
        if value.startLocation.x <= 20 {
            withAnimation { isMenuPresented = true }
        }
    } else if let prev = selectedTab.previous {
        withAnimation { selectedTab = prev }
    }
}
```

### 垂直スクロールとの競合回避

| 条件 | 意味 |
|------|------|
| `abs(horizontalAmount) > verticalAmount` | 水平移動が垂直移動より大きい |
| `swipeThreshold: 50` | 誤操作を防ぐ最小移動量 |

---

## 3. ナビゲーションバーの外観設計

### UINavigationBarAppearance の設定

```swift
private func configureNavigationBarAppearance() {
    // スクロール時の appearance（ブラーあり）
    let scrolledAppearance = UINavigationBarAppearance()
    scrolledAppearance.configureWithDefaultBackground()
    scrolledAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    scrolledAppearance.backgroundColor = .clear
    scrolledAppearance.shadowColor = .clear  // 境界線を消す

    // フォント設定（丸ゴシック体の例）
    let largeTitleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
    let descriptor = largeTitleFont.fontDescriptor.withDesign(.rounded) ?? largeTitleFont.fontDescriptor
    scrolledAppearance.largeTitleTextAttributes = [
        .font: UIFont(descriptor: descriptor, size: 28),
        .foregroundColor: UIColor.white
    ]

    // スクロール前の appearance（完全透明）
    let transparentAppearance = UINavigationBarAppearance()
    transparentAppearance.configureWithTransparentBackground()
    transparentAppearance.shadowColor = .clear
    transparentAppearance.largeTitleTextAttributes = scrolledAppearance.largeTitleTextAttributes

    UINavigationBar.appearance().standardAppearance = scrolledAppearance
    UINavigationBar.appearance().scrollEdgeAppearance = transparentAppearance
}
```

### 設定項目の対応表

| 項目 | スクロール前 | スクロール時 |
|------|------------|------------|
| 適用先 | `scrollEdgeAppearance` | `standardAppearance` |
| `backgroundEffect` | `nil` | `UIBlurEffect(...)` |
| `backgroundColor` | `.clear` | `.clear` |
| `shadowColor` | `.clear` | `.clear` |

---

## 4. ツールバーアイコンの配置

### 基本ルール

1. **現在のページのアイコンは非表示**にする
2. **左右に1つずつ配置**してバランスを取る

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        Button { selectedTab = .home } label: {
            Image(systemName: "house.fill")
        }
    }
    ToolbarItem(placement: .navigationBarTrailing) {
        Button { selectedTab = .settings } label: {
            Image(systemName: "gearshape.fill")
        }
    }
}
```

### ❌ 避けるべきパターン

```swift
// HStackで複数配置すると右端に固まる
ToolbarItem(placement: .navigationBarTrailing) {
    HStack {
        Button { ... }
        Button { ... }
    }
}
```

---

## 5. よくある問題と解決策

### ナビバーに境界線が表示される

```swift
appearance.shadowColor = .clear  // 必須
```

### ブラー効果が表示されない

```swift
// ❌ 間違い
appearance.configureWithTransparentBackground()
appearance.backgroundEffect = UIBlurEffect(...)  // 効果なし

// ✅ 正しい
appearance.configureWithDefaultBackground()
appearance.backgroundEffect = UIBlurEffect(...)
```

### フォントが丸ゴシックにならない

```swift
// ❌ 存在しないAPI
UIFont.systemFont(ofSize: 28, weight: .bold, design: .rounded)

// ✅ 正しい方法
let font = UIFont.systemFont(ofSize: 28, weight: .bold)
let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
let roundedFont = UIFont(descriptor: descriptor, size: 28)
```

### タブ切り替えができない

1. Tab enumが`public`でない
2. `@Binding`の設定が正しくない

```swift
// 子ビューのinit
public init(selectedTab: Binding<Tab>) {
    _selectedTab = selectedTab
}
```

---

## 6. 実装チェックリスト

### ✅ 推奨

- [ ] Tab enumを`public`で定義
- [ ] `CaseIterable`を採用してタブ順序を自動管理
- [ ] `next`/`previous`プロパティでスワイプナビゲーション対応
- [ ] スワイプジェスチャーはルートビューで一元管理
- [ ] `scrollEdgeAppearance`と`standardAppearance`を両方設定
- [ ] `shadowColor = .clear`で境界線を消す
- [ ] ツールバーアイコンは左右に分散配置

### ❌ 禁止

- [ ] 各画面で個別にスワイプジェスチャーを設定しない
- [ ] `UINavigationBar.appearance()`をグローバルに設定しない
- [ ] HStackで複数のツールバーアイコンを配置しない
- [ ] `UIFont.systemFont(ofSize:weight:design:)`を使用しない

---

## TsukiSound固有の実装

### タブ構成

```
Clock → Audio → AudioSettings → AppSettings
```

| タブ | 左スワイプ | 右スワイプ |
|------|-----------|-----------|
| Clock | → Audio | SideMenu（左端からのみ） |
| Audio | → AudioSettings | → Clock |
| AudioSettings | → AppSettings | → Audio |
| AppSettings | (なし) | → AudioSettings |

### 関連ファイル

- `TsukiSound/App/ContentView.swift` - タブ管理、スワイプナビゲーション
- `TsukiSound/DesignSystem/Navigation/NavigationBackModifier.swift` - カスタムBackボタン
- `TsukiSound/DesignSystem/NavigationBarTokens.swift` - ナビバースタイル

---

## 変更履歴

- 2025-12-10: 汎用的なドキュメントに改訂、スワイプナビゲーション追加
- 2025-11-16: 初版作成
