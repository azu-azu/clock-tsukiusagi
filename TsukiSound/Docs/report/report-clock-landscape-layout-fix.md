# Clock横向きレイアウト修正レポート

**作成日**: 2025-12-06
**対象**: ClockScreenView, ContentView
**分類**: UI/レイアウト修正

---

## 1. 概要

Clock画面の横向き（Landscape）表示における複数の問題を修正した。

### 修正した問題

1. **アナログ時計が小さく、位置が下すぎる**
2. **デジタル時計で月と時計が重なる**
3. **SevenSeg時計でキャプション位置がずれる**
4. **アナログモード時のナビゲーションアイコン色が不適切**

---

## 2. 問題の詳細と原因

### 2.1 アナログ時計のサイズと位置

**問題**: 横向き時にBunny/Number時計が非常に小さく表示され、位置が下すぎた。

**原因**:
- 固定の `.padding(.top, 140)` が縦向き用に設計されていた
- `.alignment: .top` により横向き時に不適切な配置になった

### 2.2 デジタル時計と月の重なり

**問題**: 横向き時にMoonGlyphとデジタル時計が重なって表示された。

**原因**: 縦向きと同じZStack配置が横向きでも使用されていた。

### 2.3 SevenSeg時計のキャプション位置ずれ

**問題**: SevenSeg時計モードでキャプションが他のモードより上に表示された。

**原因**:
- SevenSegの高さ（44pt）が他の時計（56pt）より12pt小さい
- VStack内でSevenSegが小さいため、VStack全体の高さが小さくなり、bottom alignmentでキャプションが上にずれた

### 2.4 アナログモード時のアイコン色

**問題**: Bunny/Numberモード時にMenu/Audioボタンの色が背景と馴染まなかった。

**原因**: `displayMode` がClockScreenView内でのみ管理されており、ContentViewから参照できなかった。

---

## 3. 解決策

### 3.1 アナログ時計のレイアウト改善

```swift
private func analogClockView(in geometry: GeometryProxy) -> some View {
    let isLandscape = geometry.size.width > geometry.size.height
    let clockSize = isLandscape
        ? min(geometry.size.height * 0.85, geometry.size.width * 0.5)
        : min(geometry.size.width * 0.85, geometry.size.height * 0.5)

    // ...時計View...
    .frame(width: clockSize, height: clockSize)
    .frame(maxWidth: .infinity, maxHeight: .infinity,
           alignment: isLandscape ? .center : .top)
    .offset(y: isLandscape ? -20 : 0)
    .padding(.top, isLandscape ? 0 : 100)
}
```

**ポイント**:
- 横向き時は画面高さの85%をサイズに使用
- 中央配置（`.center`）に変更
- 波アニメーションとの重なりを避けるため20pt上にオフセット

### 3.2 横向きデジタルモードのHStack配置

```swift
if isLandscape && isDigitalMode {
    HStack(spacing: 0) {
        // 左側: 月
        MoonGlyph(date: now, tone: snapshot.skyTone)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        // 右側: 時計 + キャプション
        VStack(spacing: DesignTokens.ClockSpacing.timeCaptionSpacing) {
            digitalClockContent(snapshot: snapshot)
                .frame(height: Self.clockFontSize)
            Text(snapshot.caption)
                // ...
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

**ポイント**:
- 横向き＋デジタルモード時のみHStackで左右配置
- 左に月、右に時計＋キャプション

### 3.3 SevenSeg高さの統一

```swift
digitalClockContent(snapshot: snapshot)
    .frame(height: Self.clockFontSize)  // 56pt固定
    .accessibilityLabel("Current time")
```

**ポイント**:
- `digitalClockContent` 全体を56ptの固定高さフレームで包む
- SevenSeg（44pt）でも他と同じフレーム高さを占める
- キャプション位置が全モードで統一される

### 3.4 displayModeの共有とアイコン色変更

```swift
// ContentView
@State private var clockDisplayMode: ClockDisplayMode = .dotMatrix

private var isAnalogClockMode: Bool {
    clockDisplayMode == .bunny || clockDisplayMode == .number
}

// ClockScreenView
@Binding var displayMode: ClockDisplayMode

// TabButton
private var foregroundColor: Color {
    if isSelected {
        return .accentColor
    } else if useAnalogColor {
        return DesignTokens.ClockColors.captionBlue
    } else {
        return .white.opacity(0.6)
    }
}
```

**ポイント**:
- `displayMode` を `@Binding` に変更してContentViewから渡す
- アナログモード時はキャプションと同じ `captionBlue` 色を使用

---

## 4. 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `TsukiSound/App/ContentView.swift` | `clockDisplayMode` 状態追加、`TabButton` に `useAnalogColor` パラメータ追加 |
| `TsukiSound/Features/Clock/Views/ClockScreenView.swift` | `displayMode` を `@Binding` に変更、横向きレイアウト改善、SevenSeg高さ修正 |

---

## 5. テスト確認項目

- [ ] 縦向き: 全時計モードで時計・キャプション位置が正常
- [ ] 横向き: デジタルモードで月が左、時計が右に配置
- [ ] 横向き: アナログモードで時計が中央に大きく表示
- [ ] 横向き: SevenSegモードでキャプション位置が他と同じ
- [ ] アナログモード時: Menu/Audioアイコンが captionBlue 色

---

## 6. 関連コミット

- Commit: `cbe3d4c` - "fix: improve clock layout for landscape and analog modes"
- Commit: `cb684d3` - "fix: improve clock layout for landscape orientation"

---

## 7. 学んだこと

1. **高さの異なるコンテンツをVStackで揃える**: 固定高さフレームで包むことで、内容の高さに関係なくレイアウトを統一できる

2. **横向き/縦向きで異なるレイアウト**: `GeometryReader` で画面サイズを取得し、`isLandscape` フラグで条件分岐する

3. **状態の共有**: View間で状態を共有する場合は `@Binding` を使用し、親Viewで `@State` を管理する
