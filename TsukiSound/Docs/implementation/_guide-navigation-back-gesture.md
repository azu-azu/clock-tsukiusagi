# Navigation Back Button - カスタム戻るボタン実装ガイド

**作成日**: 2025-11-22
**最終更新**: 2025-12-10

## 概要

SwiftUIでタブベースのナビゲーション（`selectedTab`による画面切り替え）を採用する場合、標準のNavigationViewの戻るボタンでは正しく機能しない。本ガイドでは、カスタムBackボタンの実装パターンを解説する。

**注意**: スワイプによる画面遷移は別途ルートビューで一元管理することを推奨。詳細は `_guide-navigation-design.md` を参照。

---

## 1. なぜカスタム実装が必要か

### 標準NavigationViewの問題

SwiftUIの標準NavigationViewは、`NavigationLink`によるpush/pop方式を前提としている。

```swift
// 標準的なNavigationView（push/pop方式）
NavigationView {
    NavigationLink("Details", destination: DetailView())
}
```

しかし、タブベースのナビゲーションでは以下の方式を採用：

```swift
// タブベースのナビゲーション（selectedTab方式）
@State private var selectedTab: Tab = .home

switch selectedTab {
case .home: HomeView(selectedTab: $selectedTab)
case .settings: SettingsView(selectedTab: $selectedTab)
}
```

このため、標準の戻るボタンは動作せず、**selectedTabを変更するカスタム実装**が必要。

---

## 2. NavigationBackModifier

### 基本実装

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

// View Extension
extension View {
    func navigationBackButton(onBack: @escaping () -> Void) -> some View {
        self.modifier(NavigationBackModifier(onBack: onBack))
    }
}
```

### 使用方法

```swift
struct SettingsView: View {
    @Binding var selectedTab: Tab

    var body: some View {
        NavigationView {
            ScrollView {
                // コンテンツ
            }
            .navigationTitle("Settings")
            .navigationBackButton {
                selectedTab = .home  // 前の画面に戻る
            }
        }
    }
}
```

---

## 3. 戻り先の設計パターン

### パターン1: 直前のタブに戻る

```swift
// Tab enumに previous プロパティがある場合
.navigationBackButton {
    if let prev = selectedTab.previous {
        selectedTab = prev
    }
}
```

### パターン2: 固定の画面に戻る

```swift
// 常にホーム画面に戻る
.navigationBackButton {
    selectedTab = .home
}
```

### パターン3: 階層構造に従う

```swift
// Settings → Audio → Home のような階層
// SettingsView
.navigationBackButton { selectedTab = .audio }

// AudioView
.navigationBackButton { selectedTab = .home }
```

---

## 4. カスタマイズ

### ボタンのスタイル変更

```swift
// アイコンのみ
Button {
    onBack()
} label: {
    Image(systemName: "chevron.left")
        .font(.system(size: 20, weight: .medium))
}

// テキストのみ
Button("戻る") {
    onBack()
}

// カスタムアイコン
Button {
    onBack()
} label: {
    Image(systemName: "xmark")
        .font(.system(size: 17, weight: .medium))
}
```

### アニメーション付き

```swift
.navigationBackButton {
    withAnimation(.easeInOut(duration: 0.3)) {
        selectedTab = .home
    }
}
```

---

## 5. トラブルシューティング

### Backボタンが表示されない

**原因**: `.toolbar`の設定が上書きされている

```swift
// ❌ 順序の問題
.toolbar { ... }  // 先に設定
.navigationBackButton { ... }  // 上書きされる可能性

// ✅ 正しい順序
.navigationBackButton { ... }  // 先に設定
.toolbar { ... }  // 追加のアイテム
```

### 標準ボタンと重複する

```swift
// navigationBarBackButtonHidden が適用されていない
.navigationBarBackButtonHidden(true)  // 必ず設定
```

### タップしても反応しない

**原因**: `@Binding`が正しく渡されていない

```swift
// 子ビューの初期化
public init(selectedTab: Binding<Tab>) {
    _selectedTab = selectedTab  // アンダースコアに注意
}
```

---

## 6. ベストプラクティス

### ✅ 推奨

1. **戻り先は明確に**: 各画面の戻り先を固定する
2. **シンプルに保つ**: 複雑な条件分岐は避ける
3. **スワイプは別管理**: スワイプジェスチャーはルートビューで一元管理

```swift
// シンプルで明確
.navigationBackButton {
    selectedTab = .audio
}
```

### ❌ 避けるべきパターン

1. **複雑な戻り先ロジック**

```swift
// ❌ 避ける
.navigationBackButton {
    if someCondition {
        selectedTab = .home
    } else if otherCondition {
        selectedTab = .audio
    } else {
        selectedTab = .settings
    }
}
```

2. **非同期処理の混在**

```swift
// ❌ 避ける
.navigationBackButton {
    Task {
        await saveData()
        selectedTab = .home
    }
}
```

3. **標準ボタンとの併用**

```swift
// ❌ 避ける（混乱の元）
.navigationBarBackButtonHidden(false)
.navigationBackButton { ... }
```

---

## 7. 関連ドキュメント

- `_guide-navigation-design.md` - ナビゲーション全体の設計、スワイプナビゲーション
- Apple HIG - [Navigation](https://developer.apple.com/design/human-interface-guidelines/navigation)

---

## TsukiSound固有の実装

### 戻り先の設計

| 画面 | Backボタンの戻り先 |
|------|-------------------|
| Audio | Clock |
| AudioSettings | Audio |
| AppSettings | AudioSettings |

### 実装ファイル

- `TsukiSound/DesignSystem/Navigation/NavigationBackModifier.swift`

---

## 変更履歴

- **2025-12-10**: 汎用的なドキュメントに改訂、スワイプナビゲーションを分離
- **2025-11-22**: 初版作成
