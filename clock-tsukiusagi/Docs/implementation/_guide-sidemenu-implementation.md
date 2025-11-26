# SwiftUI サイドメニュー実装ガイド

左からスライドインするサイドメニュー（ハンバーガーメニュー）を SwiftUI で実装する完全ガイドです。`.statusBarHidden(true)` 環境でも正しく動作する、画面全体を覆うメニューを実装します。

## 目次

1. [基本構造](#1-基本構造)
2. [レイアウトの重要ポイント](#2-レイアウトの重要ポイント)
3. [Safe Area の扱い](#3-safe-area-の扱い)
4. [実装例](#4-実装例)
5. [トラブルシューティング](#5-トラブルシューティング)

---

## 1. 基本構造

### 1.1 必要なコンポーネント

サイドメニューには以下の要素が必要です：

1. **メニュー本体** - ScrollView + VStack（コンテンツ）
2. **オーバーレイ** - GeometryReader（画面全体のサイズ取得）
3. **状態管理** - `@Binding var isPresented: Bool`
4. **アニメーション** - `.offset()` + `.transition()`

### 1.2 基本的な View 構造

```swift
struct SideMenu: View {
    @Binding var isPresented: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    // メニュー本体
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // ヘッダー、メニューアイテム、フッター
                        }
                    }
                    .frame(width: menuWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(menuBackgroundColor)
                    .offset(x: isPresented ? 0 : -menuWidth)

                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .edgesIgnoringSafeArea(.all)
            .animation(.easeInOut(duration: 0.3), value: isPresented)
        }
    }
}
```

---

## 2. レイアウトの重要ポイント

### 2.1 階層構造と役割

```
GeometryReader                    // 画面サイズ取得
└─ ZStack                         // メニュー全体のコンテナ
   └─ HStack                      // 左寄せレイアウト
      ├─ ScrollView               // スクロール可能なメニュー本体
      │  └─ VStack                // メニューアイテム配置
      └─ Spacer()                 // 右側の空白
```

### 2.2 `.frame()` の適用順序

**重要**: modifier の順序が間違っていると、レイアウトが崩れます。

```swift
.frame(width: menuWidth)                              // 1. 幅を固定
.frame(maxHeight: .infinity, alignment: .top)         // 2. 高さを画面いっぱいに
.padding(.leading, horizontalOffset)                  // 3. 左パディング
.background(backgroundColor)                          // 4. 背景色
.cornerRadius(cornerRadius)                           // 5. 角丸
.shadow(...)                                          // 6. 影
.offset(x: isPresented ? 0 : -menuWidth)              // 7. スライドアニメーション
```

❌ **間違い**: `.frame(width: menuWidth, maxHeight: .infinity)` の後に `.padding()` を呼ぶと、ビルドエラーになる場合があります。

✅ **正解**: `.frame()` を2回に分けて、間に `.padding()` を挟む。

### 2.3 HStack と ZStack の `.frame(maxHeight: .infinity)`

メニューを画面全体の高さにするには、**両方に** `.frame(maxHeight: .infinity)` が必要です：

```swift
HStack(spacing: 0) {
    // メニュー本体
}
.frame(maxHeight: .infinity)  // ← HStack を画面いっぱいに

// ...

ZStack(alignment: .topLeading) {
    // ...
}
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)  // ← ZStack も画面いっぱいに
```

---

## 3. Safe Area の扱い

### 3.1 `.statusBarHidden(true)` 環境での注意点

⚠️ **重要**: `.statusBarHidden(true)` でステータスバーを非表示にしても、`geo.safeAreaInsets.top` は **0 にならない**（iOS の仕様）。

```swift
// ❌ 間違い: safe.top を足してしまう
.padding(.top, safe.top + 60)  // safe.top = 59.0 なので、合計 119pt になる

// ✅ 正解: 固定値のみ使う
.padding(.top, 60)
```

### 3.2 画面全体を覆う設定

メニューを画面の上端・下端まで広げるには、**ZStack に `.edgesIgnoringSafeArea(.all)` を適用**します：

```swift
ZStack(alignment: .topLeading) {
    // メニュー本体
}
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
.edgesIgnoringSafeArea(.all)  // ← safe area を無視して画面端まで広げる
```

❌ **間違い**: ScrollView に `.edgesIgnoringSafeArea(.all)` を適用しても、上下に隙間が残る。

✅ **正解**: **ZStack 全体**に適用する。

### 3.3 Safe Area のデバッグ方法

実際の値を確認するには、以下のログを追加します：

```swift
GeometryReader { geo in
    let safe = geo.safeAreaInsets
    let _ = print("🐛 safe.top: \(safe.top), safe.bottom: \(safe.bottom)")

    // ...
}
```

---

## 4. 実装例

### 4.1 完全な実装コード

```swift
import SwiftUI

struct SideMenu: View {
    @Binding var isPresented: Bool

    // メニューアイテムのコールバック
    var onMenuItem1: () -> Void
    var onMenuItem2: () -> Void

    var body: some View {
        GeometryReader { geo in
            let safe = geo.safeAreaInsets
            let size = geo.size

            // レスポンシブ幅計算
            let menuWidth: CGFloat = min(size.width * 0.75, 320)
            let leadingOffset: CGFloat = max(safe.leading, 0)

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {

                            // ヘッダー
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Menu")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 60)  // ← safe.top を足さない
                            .padding(.bottom, 16)
                            .background(Color.blue.gradient)

                            Divider()
                                .background(Color.white.opacity(0.3))

                            // メニューアイテム
                            VStack(alignment: .leading, spacing: 12) {
                                menuItem(icon: "house", title: "Home", action: {
                                    onMenuItem1()
                                    close()
                                })

                                menuItem(icon: "gear", title: "Settings", action: {
                                    onMenuItem2()
                                    close()
                                })
                            }
                            .padding(.top, 24)
                            .padding(.horizontal, 16)

                            Spacer(minLength: safe.bottom + 30)
                        }
                    }
                    .frame(width: menuWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.leading, leadingOffset)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(0)
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 4, y: 0)
                    .offset(x: isPresented ? 0 : -(menuWidth + leadingOffset + 20))
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .edgesIgnoringSafeArea(.all)
            .animation(.easeInOut(duration: 0.3), value: isPresented)
        }
    }

    private func menuItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}
```

### 4.2 使い方

```swift
struct ContentView: View {
    @State private var isMenuOpen = false

    var body: some View {
        ZStack {
            // メイン画面
            VStack {
                Button("Open Menu") {
                    withAnimation {
                        isMenuOpen = true
                    }
                }
            }

            // サイドメニュー
            if isMenuOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isMenuOpen = false
                        }
                    }

                SideMenu(
                    isPresented: $isMenuOpen,
                    onMenuItem1: { print("Home tapped") },
                    onMenuItem2: { print("Settings tapped") }
                )
            }
        }
    }
}
```

### 4.3 スワイプジェスチャーの追加

左端からスワイプでメニューを開く：

```swift
.gesture(
    DragGesture()
        .onEnded { value in
            if value.translation.width > 50 && value.startLocation.x < 50 {
                withAnimation {
                    isMenuOpen = true
                }
            }
        }
)
```

右方向へスワイプで閉じる：

```swift
// SideMenu 内の ScrollView に追加
.gesture(
    DragGesture()
        .onEnded { value in
            if value.translation.width < -50 {
                close()
            }
        }
)
```

---

### 4.4 高度なスワイプジェスチャー実装

実際の製品レベルの実装では、以下の点を考慮する必要があります。

#### 左端検出の厳格化（iOS Timer同等）

**推奨値**: 左端**20px以内**からのスワイプのみ検知

iOSのTimerアプリと同様、誤操作を防ぐために左端の検出範囲を厳格にします。

```swift
private func sideMenuDragGesture() -> some Gesture {
    DragGesture()
        .onEnded { value in
            let horizontalAmount = value.translation.width
            let verticalAmount = abs(value.translation.height)
            let openThreshold: CGFloat = 50
            let closeThreshold = -openThreshold

            // 水平移動が垂直移動より大きい場合のみ処理
            if abs(horizontalAmount) > verticalAmount {
                // 右スワイプ & 左端20px以内からのスワイプのみメニューを開く
                if horizontalAmount > openThreshold && !isMenuPresented {
                    if value.startLocation.x <= 20 {  // ← 厳格な左端検出
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuPresented = true
                        }
                    }
                }
                // 左スワイプでメニューを閉じる
                else if horizontalAmount < closeThreshold && isMenuPresented {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMenuPresented = false
                    }
                }
            }
        }
}
```

**ポイント**:
- `value.startLocation.x <= 20`: 左端20px以内からのスワイプのみ
- `abs(horizontalAmount) > verticalAmount`: 垂直スクロールとの競合を回避

---

#### 垂直スクロールとの競合回避

**問題**: メニュー内にScrollViewがある場合、スワイプジェスチャーが垂直スクロールと競合します。

**解決策**: 水平移動量が垂直移動量より大きい場合のみ処理

```swift
let horizontalAmount = value.translation.width
let verticalAmount = abs(value.translation.height)

if abs(horizontalAmount) > verticalAmount {
    // スワイプジェスチャー処理
}
```

**動作例**:

| 水平移動 | 垂直移動 | 判定 | 結果 |
|---------|---------|------|------|
| 60pt → | 10pt ↓ | ✅ スワイプ | メニュー開閉 |
| 60pt → | 50pt ↓ | ✅ スワイプ | メニュー開閉 |
| 30pt → | 80pt ↓ | ❌ スクロール | 無視 |
| 80pt → | 90pt ↓ | ❌ スクロール | 無視 |

---

#### 開く・閉じるを統合したジェスチャー

別々のジェスチャーとして実装するのではなく、1つのハンドラーで統合的に処理します。

```swift
private func sideMenuDragGesture() -> some Gesture {
    DragGesture()
        .onEnded { value in
            let horizontalAmount = value.translation.width
            let verticalAmount = abs(value.translation.height)
            let openThreshold: CGFloat = 50
            let closeThreshold = -openThreshold

            // 水平方向のスワイプのみ処理（垂直スクロールとの競合を避ける）
            if abs(horizontalAmount) > verticalAmount {
                // 右スワイプでメニューを開く
                if horizontalAmount > openThreshold && !isMenuPresented {
                    if value.startLocation.x <= 20 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuPresented = true
                        }
                    }
                }
                // 左スワイプでメニューを閉じる
                else if horizontalAmount < closeThreshold && isMenuPresented {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMenuPresented = false
                    }
                }
            }
        }
}
```

---

### 4.5 DesignTokensの使用

ハードコード値の代わりにDesignTokensを使用することで、デザインの統一性を保ちます。

#### ❌ 非推奨（ハードコード）

```swift
let menuWidth: CGFloat = 320
.background(Color.white.opacity(0.1))
.shadow(color: Color.black.opacity(0.3), radius: 8)
```

#### ✅ 推奨（DesignTokens）

```swift
let menuWidth = min(
    size.width * DesignTokens.SideMenuLayout.menuWidthRatio,
    DesignTokens.SideMenuLayout.menuMaxWidth
)
.background(DesignTokens.SideMenuColors.background)
.shadow(color: Color.black.opacity(0.4), radius: 8, x: -4, y: 0)
```

#### 利用可能なDesignTokens

**SideMenuLayout**:
- `menuWidthRatio`: メニュー幅の画面比率（0.8）
- `menuMaxWidth`: メニューの最大幅（300pt）
- `menuHorizontalPadding`: 水平パディング（16pt）
- `cornerRadius`: 角丸半径（10pt）
- `itemVerticalPadding`: アイテムの垂直パディング（14pt）
- `itemSpacing`: アイテム間のスペーシング（20pt）

**SideMenuColors**:
- `background`: メニュー背景色（宇宙空間の濃紺）
- `overlay`: オーバーレイ背景色（黒の半透明）
- `divider`: 区切り線色
- `iconColor`: アイコン色
- `textMuted`: 控えめなテキスト・シェブロン色

詳細は [design-tokens-guide.md](../clock-tsukiusagi/Docs/implementation/design-tokens-guide.md) を参照してください。

---

## 5. トラブルシューティング

### 5.1 上下に隙間ができる

**症状**: メニューの上下に背景（ContentView）が見える

**原因と解決策**:

1. **ZStack に `.edgesIgnoringSafeArea(.all)` がない**
   ```swift
   // ✅ 追加する
   ZStack { ... }
       .edgesIgnoringSafeArea(.all)
   ```

2. **HStack/ZStack に `.frame(maxHeight: .infinity)` がない**
   ```swift
   // ✅ 両方に追加する
   HStack { ... }
       .frame(maxHeight: .infinity)

   ZStack { ... }
       .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
   ```

3. **`safe.top` を二重にカウントしている**
   ```swift
   // ❌ 間違い
   .padding(.top, safe.top + 60)

   // ✅ 正解（.statusBarHidden(true) の場合）
   .padding(.top, 60)
   ```

### 5.2 ビルドエラー: "Extra argument 'width' in call"

**症状**: `.frame(width:maxHeight:alignment:)` でコンパイルエラー

**原因**: SwiftUI の `.frame()` modifier の引数が混在している

**解決策**: `.frame()` を2回に分ける

```swift
// ❌ エラーになる場合がある
.frame(width: menuWidth, maxHeight: .infinity, alignment: .top)
.padding(.leading, offset)

// ✅ 正解
.frame(width: menuWidth)
.frame(maxHeight: .infinity, alignment: .top)
.padding(.leading, offset)
```

### 5.3 メニューが画面からはみ出る

**症状**: メニューの右端が画面外に消える

**原因**: `menuWidth` の計算が画面幅より大きい

**解決策**: レスポンシブ幅計算を使う

```swift
let menuWidth: CGFloat = min(
    size.width * 0.75,  // 画面幅の75%
    320                  // 最大幅320pt
)
```

### 5.4 アニメーションがカクつく

**症状**: メニューの開閉がスムーズに動かない

**原因**: `.animation()` の位置が間違っている

**解決策**: **ZStack の最後**に `.animation()` を配置する

```swift
ZStack {
    // ...
}
.edgesIgnoringSafeArea(.all)
.animation(.easeInOut(duration: 0.3), value: isPresented)  // ← ここ
```

### 5.5 背景のタップで閉じない

**症状**: メニュー外をタップしても閉じない

**解決策**: 半透明の背景を追加する

```swift
ZStack {
    // メイン画面

    if isMenuOpen {
        // 背景オーバーレイ
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation {
                    isMenuOpen = false
                }
            }

        // サイドメニュー
        SideMenu(isPresented: $isMenuOpen, ...)
    }
}
```

---

## まとめ

### チェックリスト

サイドメニューを実装する際は、以下を確認してください：

- [ ] ZStack に `.edgesIgnoringSafeArea(.all)` を適用
- [ ] ZStack と HStack に `.frame(maxHeight: .infinity)` を適用
- [ ] `.statusBarHidden(true)` の場合、`safe.top` を使わない
- [ ] `.frame()` は2回に分けて、幅と高さを別々に設定
- [ ] `.animation()` は ZStack の最後に配置
- [ ] レスポンシブ幅計算で画面サイズに対応
- [ ] 背景タップで閉じる機能を追加

### 参考リンク

- [Apple Human Interface Guidelines - Navigation](https://developer.apple.com/design/human-interface-guidelines/navigation)
- [SwiftUI `.frame()` modifier documentation](https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:))
- [SwiftUI Safe Area](https://developer.apple.com/documentation/swiftui/view/edgesignoringsafearea(_:))

---

**更新履歴**:
- 2025-11-22: セクション4.4, 4.5追加（高度なスワイプ実装、DesignTokens使用）
- 2025-11-21: 初版作成（clock-tsukiusagi の SideMenu 実装経験をもとに）
