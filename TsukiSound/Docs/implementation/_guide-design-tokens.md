# Design Tokens Guide - デザイントークン統一ガイド

**作成日**: 2025-11-22
**最終更新**: 2025-11-22

## 概要

本ガイドでは、TsukiSoundアプリで使用するデザイントークンの体系と使用方法を説明します。特に、CommonTextColorsとCommonBackgroundColorsを中心とした色体系の統一について詳しく解説します。

---

## CommonTextColors 階層システム

### 概念

`DesignTokens.CommonTextColors`は、アプリ全体で統一された**5段階のテキスト色階層**を提供します。これにより、同じ名前で異なる値を持つ色定義（例: textSecondary が opacity 0.7 と 0.8 で混在）の問題を解決します。

### 階層定義

| 階層 | opacity値 | 用途 | 具体例 |
|------|-----------|------|--------|
| **primary** | 0.95 | 最も重要なテキスト | タイトル、時刻表示 |
| **secondary** | 0.8 | 重要なテキスト | 見出し、ラベル、アイコン |
| **tertiary** | 0.7 | 補助的なテキスト | 説明文、サブタイトル |
| **quaternary** | 0.6 | 控えめなテキスト | ヒント、プレースホルダー、シェブロン |
| **quinary** | 0.5 | 非アクティブ | 無効化されたテキスト |

**定義場所**: `DesignSystem/DesignTokens.swift:28-34`

```swift
enum CommonTextColors {
    static let primary = Color.white.opacity(0.95)
    static let secondary = Color.white.opacity(0.8)
    static let tertiary = Color.white.opacity(0.7)
    static let quaternary = Color.white.opacity(0.6)
    static let quinary = Color.white.opacity(0.5)
}
```

---

## CommonBackgroundColors 階層システム

### 概念

`DesignTokens.CommonBackgroundColors`は、アプリ全体で統一された**4段階の背景色階層**を提供します。これにより、hardcodedなopacity値の散在や、同じ値を異なる表記（0.1 vs 0.10）で定義する問題を解決します。

### 階層定義

| 階層 | opacity値 | 用途 | 具体例 |
|------|-----------|------|--------|
| **card** | 0.1 | 標準カード背景 | Settings画面のカード、SideMenuのカード |
| **cardHighlight** | 0.15 | ハイライト背景 | Audio画面の音源カード |
| **cardInteractive** | 0.25 | 選択・強調背景 | 音源選択時の強調表示 |
| **cardBorder** | 0.3 | カード枠線 | 全カードの枠線 |

**定義場所**: `DesignSystem/DesignTokens.swift:43-55`

```swift
enum CommonBackgroundColors {
    /// カード背景色（全画面共通）
    static let card = Color.white.opacity(0.1)

    /// ハイライトされたカード背景色（通常より明るい）
    static let cardHighlight = Color.white.opacity(0.15)

    /// インタラクティブなカード背景色（選択・強調用、最も明るい）
    static let cardInteractive = Color.white.opacity(0.25)

    /// カードの枠線色
    static let cardBorder = Color.white.opacity(0.3)
}
```

---

## 画面別Colors enumの役割

各画面専用のColors enum（ClockColors, SettingsColors, SideMenuColorsなど）は、**CommonTextColorsを参照する**形で定義されています。

### ClockColors

```swift
enum ClockColors {
    /// メインのテキスト色（時刻表示など）
    static let textPrimary = CommonTextColors.primary

    /// キャプション用の特殊色（濃い青色、背景色とは独立）
    static let captionBlue = Color(hex: "#3d5a80")

    // ...
}
```

**特殊ケース**: `captionBlue`は背景色（SkyTone）と被らないよう、独立したhex値を使用。

### SettingsColors

```swift
enum SettingsColors {
    /// プライマリテキスト色
    static let textPrimary = CommonTextColors.primary

    /// セカンダリテキスト色（説明文など）
    static let textSecondary = CommonTextColors.tertiary  // opacity 0.7

    /// Tertiary テキスト色（キャプションなど）
    static let textTertiary = CommonTextColors.quaternary  // opacity 0.6

    /// 薄いテキスト色（ヒントなど）
    static let textQuaternary = CommonTextColors.quinary  // opacity 0.5

    // ...
}
```

### SideMenuColors

```swift
enum SideMenuColors {
    /// アイコン色
    static let iconColor = CommonTextColors.secondary  // opacity 0.8

    /// シェブロン色・説明文色
    static let textMuted = CommonTextColors.quaternary  // opacity 0.6

    // ...
}
```

### CommonBackgroundColorsの参照例

```swift
enum CosmosColors {
    /// カード背景色（代替・subtle用）
    static let cardBackgroundAlt = CommonBackgroundColors.card
}

enum SettingsColors {
    /// カード背景色
    static let cardBackground = CommonBackgroundColors.card
}
```

---

## 使用ガイドライン

### ✅ 正しい使い方

#### パターンA: 画面専用Colors enumから参照（推奨）

```swift
// Settings画面での説明文
Text("This is a description")
    .foregroundColor(DesignTokens.SettingsColors.textSecondary)

// SideMenuでのシェブロン
Image(systemName: "chevron.right")
    .foregroundColor(DesignTokens.SideMenuColors.textMuted)

// カード背景
VStack {
    // Content
}
.background(DesignTokens.SettingsColors.cardBackground)
```

#### パターンB: CommonColorsを直接参照

```swift
// 新規コンポーネントで汎用的なテキスト色が必要な場合
Text("Generic text")
    .foregroundColor(DesignTokens.CommonTextColors.tertiary)

// 汎用的なカード背景
VStack {
    // Content
}
.background(DesignTokens.CommonBackgroundColors.card)
```

---

### ❌ 避けるべきパターン

#### アンチパターン1: ハードコード

```swift
// ❌ NG: 同じ値が複数箇所に散在
.foregroundColor(Color.white.opacity(0.7))
```

**なぜNG?**
値を変更したい場合、全箇所を探して修正する必要がある。

**修正方法**:
```swift
// ✅ OK: CommonTextColorsを参照
.foregroundColor(DesignTokens.CommonTextColors.tertiary)
```

---

#### アンチパターン2: 二重opacity適用

```swift
// ❌ NG: 0.7 × 0.6 = 0.42 になってしまう
DesignTokens.SettingsColors.textSecondary.opacity(0.6)
```

**なぜNG?**
意図しない色になり、デザインの統一性が崩れる。

**修正方法**:
```swift
// ✅ OK: より薄い階層を使う
DesignTokens.SettingsColors.textTertiary  // opacity 0.6
```

---

#### アンチパターン3: 同名異値の定義

```swift
// ❌ NG: 同じ名前で異なる値を定義
enum ClockColors {
    static let textSecondary = Color.white.opacity(0.8)
}

enum SettingsColors {
    static let textSecondary = Color.white.opacity(0.7)
}
```

**なぜNG?**
- どちらが正しいのか迷う
- 画面間で微妙に色が違うという違和感
- 将来的なリファクタリングが困難

**修正方法**:
```swift
// ✅ OK: CommonTextColorsを参照し、役割を明確にする
enum ClockColors {
    static let textPrimary = CommonTextColors.primary
}

enum SettingsColors {
    static let textSecondary = CommonTextColors.tertiary  // 説明文用
    static let textTertiary = CommonTextColors.quaternary  // キャプション用
}
```

---

## SkyToneとの使い分け

| 用途 | 使用するトークン | 例 |
|------|----------------|-----|
| **テキスト色** | `CommonTextColors` | ラベル、説明文、ボタンテキスト |
| **カード背景色** | `CommonBackgroundColors` | カード背景、カード枠線 |
| **背景グラデーション** | `SkyTone` (dusk/night/day) | 画面全体の背景、時間帯による変化 |
| **特殊なキャプション色** | `ClockColors.captionBlue` | 月相キャプション（背景と被らない独立色） |

### 注意点: 背景色との衝突

SkyToneを背景に使う場合、キャプションテキストがSkyToneの色を参照すると**背景と同化して見えなくなる**リスクがあります。

```swift
// ❌ NG: 背景がduskの時、同じ色で見えない
.foregroundStyle(SkyTone.dusk.gradStart)

// ✅ OK: 背景色とは独立したhex値を使用
.foregroundStyle(DesignTokens.ClockColors.captionBlue)  // #3d5a80
```

---

## リファクタリング履歴

### 2025-11-22: CommonBackgroundColors導入

#### 問題

背景色関連のopacity値が複数箇所で重複していた：

1. `cardBackground`: `opacity(0.1)` vs `opacity(0.10)` の表記ゆれ
2. `AudioPlaybackView.swift`（旧AudioTestView）: hardcoded `opacity(0.15)`, `opacity(0.3)` with ✂️ comment
3. `SettingsComponents.swift`: hardcoded `opacity(0.25)`, `opacity(0.3)`

#### 解決策

1. **CommonBackgroundColors導入**: 4段階の階層システムで背景色を定義
   - card (0.1): 標準カード背景
   - cardHighlight (0.15): ハイライト背景
   - cardInteractive (0.25): 選択・強調背景
   - cardBorder (0.3): カード枠線

2. **各Colors enumは参照のみ**: CosmosColors, SettingsColorsからCommonBackgroundColorsを参照

3. **hardcoded値を削除**: AudioPlaybackView, SettingsComponentsのhardcoded値をトークン参照に置き換え

#### 影響範囲

- 3ファイル変更（29行追加、6行削除）
- 色の実際の見た目は変更なし（参照先が変わっただけ）
- 将来の背景色変更が一箇所で完結

#### コミット

```
refactor: introduce CommonBackgroundColors for unified background system
commit: 6b36ece
```

---

### 2025-11-22: textSecondary統一化

#### 問題

`textSecondary`という同じ名前が、4箇所で異なる値で定義されていた：

1. `ClockColors.textSecondary` = opacity 0.8
2. `SettingsColors.textSecondary` = opacity 0.7
3. `StaticTokens.ClockColors.textSecondary` = opacity 0.8（重複）
4. `StaticTokens.SettingsColors.textSecondary` = opacity 0.7（重複）

加えて、SideMenuで`.opacity(0.6)`を追加適用している箇所があった（二重opacity）。

#### 解決策

1. **CommonTextColors導入**: 5段階の階層システムで基礎色を定義
2. **各Colors enumは参照のみ**: 画面固有のColors enumはCommonTextColorsを参照する形に変更
3. **StaticTokens.swift削除**: 222行のデッドコード（使用箇所0件）を削除
4. **役割の明確化**: `textSecondary`, `textTertiary`など、画面ごとの役割を明示

#### 影響範囲

- 5ファイル変更（44行追加、248行削除）
- 色の実際の見た目は変更なし（参照先が変わっただけ）
- 将来の拡張性・メンテナンス性が大幅に向上

#### コミット

```
refactor: unify text color system and remove dead code
commit: 56d2032
```

---

## 新しい色を追加する場合

### フローチャート（テキスト色）

```
新しいテキスト色が必要になった
    ↓
CommonTextColorsの5階層で対応可能？
    ↓ YES
    既存の階層を使用（primary～quinary）
    ↓ NO
    ↓
複数画面で共通利用する？
    ↓ YES
    CommonTextColorsに新しい階層を追加
    （要：チーム相談、影響範囲確認）
    ↓ NO
    ↓
画面固有のColors enumに定義
（例: ClockColors.captionBlue）
    ↓
背景色（SkyTone）と被らないか確認
    ↓ 被る場合
    独立したhex値を使用（例: #3d5a80）
```

### フローチャート（背景色）

```
新しい背景色が必要になった
    ↓
CommonBackgroundColorsの4階層で対応可能？
    ↓ YES
    既存の階層を使用（card/cardHighlight/cardInteractive/cardBorder）
    ↓ NO
    ↓
複数画面で共通利用する？
    ↓ YES
    CommonBackgroundColorsに新しい階層を追加
    （要：チーム相談、影響範囲確認）
    ↓ NO
    ↓
画面固有のColors enumに定義
（例: ClockColors.glowColor）
```

### 例: 新しい警告テキスト色を追加

```swift
// Settings画面専用の警告色が必要な場合
enum SettingsColors {
    // ... 既存の定義

    /// 警告テキスト色（注意を促す赤系）
    static let warning = Color(hex: "#FFC069")
}
```

### 例: 全画面共通の薄い色が必要

```swift
// CommonTextColorsに追加（要：影響範囲確認）
enum CommonTextColors {
    // ... 既存の定義

    /// 極薄テキスト色（ほぼ透明、装飾用）
    static let senary = Color.white.opacity(0.3)
}
```

---

## DynamicThemeとの関係

### 現在の役割分担

- **DesignTokens**: 色、スペーシング、レイアウトなどの固定値
- **DynamicTheme**: フォントサイズ・ウェイトなどの環境依存値

### 将来の拡張可能性

フォントスタイル切り替え（Technical/Rounded）と同様に、**ダークモード/ライトモード**や**カラーテーマ切り替え**を導入する場合、CommonTextColorsを動的に切り替える仕組みに発展させることが可能です。

```swift
// 将来的な実装例（現在は未実装）
enum DynamicTheme {
    enum TextColors {
        static var primary: Color {
            // ダークモード/ライトモードで色を切り替え
            colorScheme == .dark
                ? Color.white.opacity(0.95)
                : Color.black.opacity(0.95)
        }
    }
}
```

現状では、CommonTextColorsで十分な統一性が保たれているため、この拡張は必要になった時点で検討します。

---

## トラブルシューティング

### Q: ビルドエラー "Cannot find 'DesignTokens' in scope"

**原因**: DesignTokens.swiftがimportされていない、またはターゲットに含まれていない。

**解決方法**:
```swift
import SwiftUI  // DesignTokens.swiftはSwiftUIプロジェクト内にあるため、通常は不要

// 直接参照
DesignTokens.CommonTextColors.primary
```

---

### Q: 色が想定より薄く（濃く）見える

**原因**: 二重opacity適用、または間違った階層を使用している可能性。

**確認方法**:
```swift
// ❌ これをやっていないか確認
DesignTokens.SettingsColors.textSecondary.opacity(0.5)  // 0.7 × 0.5 = 0.35

// ✅ 正しくは
DesignTokens.SettingsColors.textQuaternary  // opacity 0.5
```

---

### Q: 背景色と同じになって見えない

**原因**: SkyToneの色をテキストにも使用している。

**解決方法**:
```swift
// ❌ SkyToneを直接使用
.foregroundStyle(SkyTone.dusk.gradStart)

// ✅ 独立したhex値を使用
.foregroundStyle(DesignTokens.ClockColors.captionBlue)  // #3d5a80
```

---

## 参考資料

- [DesignTokens.swift](../../DesignSystem/DesignTokens.swift) - 実装ファイル
- [color-system-architecture.md](../architecture/color-system-architecture.md) - 色体系の全体アーキテクチャ
- [CLAUDE.md](../../CLAUDE.md) - プロジェクト全体のガイドライン

---

## 更新履歴

- **2025-11-22**: 初版作成（textSecondary統一化リファクタリングを受けて）
