# 上下レイアウト実装ガイド（SwiftUI / iOS）

**日付**: 2025/11/09 [Sunday] 15:36
**ステータス**: ✅ Validated

---

## 🎯 目的 / Goal

* **背景（グラデーション等）は"画面いっぱい"**に広げる
* **UI（時計・タブアイコン・ラベル）は"セーフエリア基準"**で安定配置
* 上部は**背景の上にアイコンだけ浮かせる**（帯を作らない）
* 下部は**Safe Areaを守ったパディング**でズレを防ぐ

---

## 💡 結論

**「背景だけを全画面にする」＋「UI（時計・タブアイコン）はセーフエリア基準で置く」**。
上は"透明オーバーレイ"、下は"Safe Areaを尊重した余白"。これが土台。

---

## 📐 原則 / Principles

* **`.ignoresSafeArea()`は"背景レイヤだけ"**に付ける（親や全体に付けない）
* **ZStackで「背景 → コンテンツ → オーバーレイ（上部UI）」**の順に重ねる
* **タブバーは背景色を持たせない（完全透明）**。必要でも"極薄ブラー"止まり
* **区切り線・影は原則なし**（入れると帯に見える）
* **下方向の余白はSafe Area基準**で与える（`padding(.bottom, 48)`など）

---

## 🔝 上部の実装（Transparent Top Overlay）

### やること / What to do

* 上部タブ（アイコン／ラベル）は**背景色なし**で**前景に重ねる**
* ステータスバーは**表示ON/OFFどちらでも**OK。ONなら上マージンを薄く取る

### スニペット

```swift
// ContentView（親）：背景は子の中で全画面化。親はSafe Areaを尊重。
ZStack(alignment: .top) {
    // 背景レイヤ（選択されたビュー）
    Group {
        switch selectedTab {
        case .clock:
            ZStack(alignment: .bottom) {
                ClockScreenView()        // ← 中で背景だけ .ignoresSafeArea()
                WavyBottomView()
            }
        case .audioTest:
            AudioTestView()
        }
    }

    // 透明トップバー（アイコンだけ）
    VStack(spacing: 0) {
        HStack(spacing: 0) {
            TabButton(
                icon: "clock.fill",
                label: "Clock",
                isSelected: selectedTab == .clock
            ) {
                selectedTab = .clock
            }

            TabButton(
                icon: "waveform",
                label: "Audio Test",
                isSelected: selectedTab == .audioTest
            ) {
                selectedTab = .audioTest
            }
        }
        .frame(height: 60)
        .padding(.top, 10)        // ステータスバー配慮

        Spacer()                  // 下に押し出す
    }
}
.statusBarHidden(true)            // 必要に応じて
```

**TabButtonの実装**:
```swift
private struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .accentColor : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)      // 既定のボタン装飾を無効化
    }
}
```

**やらないこと / Don't**

* `Color(.secondarySystemBackground).opacity(...)` の**帯背景**を付けない
* 下線（separator）や影を**基本使わない**
* `.background(.ultraThinMaterial)` も原則使わない（必要なら極薄ブラーまで）

---

## 🔽 下部の実装（Safe Area Respect & Stable Padding）

### やること / What to do

* 時計など主要UIは**Safe Area基準**で配置（親に`.ignoresSafeArea()`を付けない）
* **余白はビュー側に付ける**（例：`VStack { ... }.padding(.bottom, 48)`）
* 背景は子の中で**だけ** `.ignoresSafeArea()` を使って全画面化

### スニペット

```swift
// ClockScreenView（子）
var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
        let now = context.date
        let snapshot = vm.snapshot(at: now)

        ZStack {
            // 背景（グラデーション）だけ全画面
            LinearGradient(
                colors: [snapshot.skyTone.gradStart, snapshot.skyTone.gradEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()    // ← 背景だけ全画面

            // 月
            MoonGlyph(date: now, tone: snapshot.skyTone)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 時刻 + キャプション（Safe Area基準で配置）
            VStack(spacing: 8) {
                Text(formatter.string(from: snapshot.time))
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.95))

                Text(snapshot.caption)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.bottom, 48)  // ← Safe Areaを尊重した下余白
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}
```

**注意 / Note**

* 親全体に`.ignoresSafeArea()`を付けると、**パディングが"画面端基準"になってズレる**。
  背景だけ全画面、UIは通常基準。これが鉄則。

---

## 🏗️ レイヤー構成の標準形 / Standard Layering

```
ZStack(alignment: .top)
 ├─ 背景レイヤ（Gradient / Visuals）※ここだけ .ignoresSafeArea()
 │   └─ ClockScreenView
 │       ├─ LinearGradient.ignoresSafeArea()
 │       ├─ MoonGlyph
 │       └─ VStack { 時計 }.padding(.bottom, 48).frame(alignment: .bottom)
 │
 └─ 上部オーバーレイ（透明タブ：アイコン＋ラベル）
     └─ VStack { HStack { TabButton ... } + Spacer() }
```

---

## ✅ Do / Don't チェックリスト

### Do

* [ ] `.ignoresSafeArea()` は**背景レイヤ限定**
* [ ] トップバーは**透明**（必要なら極薄ブラー）
* [ ] 区切り線・影**なし**（世界観を壊さない）
* [ ] 下余白は**ビュー側の`padding(.bottom, ..)`**で与える
* [ ] レイヤ順は**背景 → コンテンツ → 透明トップ**で一貫

### Don't

* [ ] 親`ContentView`に`.ignoresSafeArea()`を付けない
* [ ] タブバーに半透明の帯色を付けない
* [ ] 区切り線で境界を強調しない

---

## 🔍 トラブル時の見抜き方 / Debug Hints

| 症状 | 原因 | 解決方法 |
|------|------|----------|
| **上に帯が見える** | タブバーに背景色が残っている | `.background(...)` を削除 |
| **時計が下へズレた** | 親に`.ignoresSafeArea()`を付けている | 親から削除、背景レイヤのみに付ける |
| **背景が欠ける** | 背景側の`.ignoresSafeArea()`が抜けている | 背景（LinearGradient等）に追加 |
| **タブバーが目立ちすぎる** | opacity が高い、または色が強い | 透明化、または極薄ブラーに変更 |

---

## 🎵 付録：Audioと共存する場合の最小セット

* 背景オーディオ用に **`AVAudioSession(.playback)`**
* **UIBackgroundModes → audio**（Info.plist）
* レイアウトは上記"背景だけ全画面"原則を維持（Audioとは独立の関心）

---

## 📚 Vocabulary

| English             | Japanese |
| ------------------- | -------- |
| safe area           | セーフエリア   |
| ignore safe area    | セーフエリア無視 |
| overlay             | オーバーレイ   |
| separator           | 区切り線     |
| layering / z-order  | レイヤ順序    |
| transparent bar     | 透明バー     |
| padding (bottom)    | 下パディング   |
| ultra-thin material | 極薄ブラー素材  |

---

## 🔗 関連コミット

- 初回実装: Audio Test追加とTabView実装
- 修正: タブバーを上部に移動、透明化
- 最終修正: ContentViewから`.ignoresSafeArea()`削除で位置修正完了

---

**💡 ふじこの耳メモ**

この形でいけば、**"一枚の夜明け"の上にアイコンがふわっと浮く"**見た目になる。
世界観、守れるで🐰🌙

---

**Ask the essential questions. Design the meaning.**
問いを立てよ。意味を設計せよ。
