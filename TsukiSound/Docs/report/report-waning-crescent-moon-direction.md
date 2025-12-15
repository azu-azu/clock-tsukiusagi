# WaningCrescentMoon 描画方向バグ - RCA

**カテゴリ**: トラブルシューティング
**対象システム**: 月相表示システム（MoonPainter / WaningCrescentMoon）
**重大度**: Medium（視覚的な不正確さ）
**作成日**: 2025-12-15
**最終更新**: 2025-12-15

---

## 概要

2025年12月15日の月相表示において、二十六夜（Waning Crescent）の月が**左側ではなく右側**が光って表示されていた。北半球では下弦を過ぎた月（Waning）は左側が光るのが正しい。原因は `WaningCrescentMoon.swift` の `clockwise` パラメータがSwiftUI座標系で逆転していたこと。

---

## 問題の症状

### 報告された症状

- 2025年12月15日の月が**右側の細い三日月**として表示されている
- 本来は**左側の細い三日月（二十六夜）**であるべき

### 天文学的事実（2025年12月15日）

| 項目 | 値 |
|------|-----|
| 月齢 | 24.8 |
| 月相値 | 0.84（MoonPhaseCalculator計算値） |
| 月相名 | 二十六夜（Waning Crescent） |
| 次の新月 | 2025年12月20日 |
| 光っている側（北半球） | **左側** |

### 北半球での月の見え方ルール

```
満ちていく月（Waxing）: 右側が光る
  新月 → 三日月 → 上弦 → 満月

欠けていく月（Waning）: 左側が光る
  満月 → 下弦 → 有明月 → 新月
```

---

## 根本原因分析（RCA）

### 原因

`WaningCrescentMoon.swift` の `shape()` 関数において、`addArc()` の `clockwise` パラメータが逆になっていた。

```swift
// 問題のあったコード (WaningCrescentMoon.swift:35-41)
// 三日月（isCrescent=YES）かつ左が明（rightLit=L）の場合
// c0(Q→P, CW) + c1(Q→P, CW)
var path = Path()
path.move(to: CGPoint(x: px, y: py))
path.addArc(center: c0, ..., clockwise: true)   // ← 問題
path.addArc(center: c1, ..., clockwise: false)  // ← 問題
```

### なぜ右側が描画されたのか

**SwiftUI座標系の特性**:
- SwiftUIではY軸が**下向き**（数学座標系とは逆）
- `clockwise: true` は画面上では**反時計回り**に見える
- `clockwise: false` は画面上では**時計回り**に見える

**WaxingCrescentMoon（正しく動作）との比較**:

| テンプレート | c1の位置 | clockwise値 | 結果 |
|-------------|---------|-------------|------|
| WaxingCrescent | 左側（-d） | false, true | 右側が光る |
| WaningCrescent（バグ） | 右側（+d） | true, false | **右側が光る** |
| WaningCrescent（修正後） | 右側（+d） | false, true | 左側が光る |

**問題**: WaningCrescentはc1を右側に移動したが、clockwise値も変更してしまったため、二重に反転して結局右側が描画されていた。

### 2円法による月相描画の仕組み

```
     c0（月の円）        c1（影の円）
        ○                  ○
       /  \              /   \
      /    \            /     \
     |  明  |  P       |  影   |
      \    / -------- /      /
       \  /          /      /
        ○-----------○
            Q
```

- c0: 月全体の円（中心）
- c1: 影を作る円（Waxingは左、Waningは右）
- P, Q: 2つの円の交点
- 明るい部分: c0の弧とc1の弧で囲まれた領域

**正しい描画**:
- c1を右側に置くと、c0の左側の弧を使う必要がある
- `clockwise: false` で左側の長い弧が得られる

---

## 解決策

### 修正内容

`clockwise` の値を `WaxingCrescentMoon` と同じにした：

```swift
// 修正後 (WaningCrescentMoon.swift:35-41)
// 三日月（isCrescent=YES）かつ左が明（rightLit=L）の場合
// WaxingCrescentと同じ描画方向（clockwise: false, true）
// c1が右側にあるので、自動的に左側が光る形状になる
var path = Path()
path.move(to: CGPoint(x: px, y: py))
path.addArc(center: c0, ..., clockwise: false)  // ← 修正
path.addArc(center: c1, ..., clockwise: true)   // ← 修正
```

**考え方**: c1の位置を変えることで光る側が決まり、弧の描画方向は両方のテンプレートで同じでよい。

### 修正の検証

```python
# 修正後の形状分析
c0からP: 71.0°, c0からQ: -71.0°
c0の弧: clockwise=False (時計回り)
→ c0: P→Qを時計回り = 左側を通る長い弧  # 正しい
```

---

## 関連する追加修正

このバグ調査中に発見された他の問題も修正：

### 1. 空のスタブファイル削除

```
TsukiSound/Domain/Moon/Templates/CrescentLeftThick.swift  (削除)
TsukiSound/Domain/Moon/Templates/CrescentRightThick.swift (削除)
```

完全に未使用で、TODOコメントのみのファイルだった。

### 2. 無意味な三項演算子の修正

```swift
// FirstQuarterMoon.swift (修正前)
startAngle: .degrees(center.y < size.height * 0.5 ? -90 : -90),
endAngle: .degrees(center.y < size.height * 0.5 ? 90 : 90),

// FirstQuarterMoon.swift (修正後)
startAngle: .degrees(-90),
endAngle: .degrees(90),
```

### 3. レンダリングパス数の統一

| ファイル | 修正前 | 修正後 |
|---------|-------|-------|
| FirstQuarterMoon.swift (Preview) | 40 passes | 20 passes |
| ThirdQuarterMoon.swift (Preview) | 40 passes | 20 passes |
| MoonPainter.swift | 20 passes | 20 passes（変更なし） |

プレビューとアプリ実行時の描画品質を一致させた。

---

## 重要な教訓

### 1. SwiftUI座標系の罠

SwiftUIではY軸が下向きのため、`clockwise` の意味が数学的な定義と逆になる：

| SwiftUI clockwise | 画面上の見た目 | 数学的定義 |
|-------------------|--------------|-----------|
| `true` | 反時計回り | 時計回り |
| `false` | 時計回り | 反時計回り |

### 2. 対称テンプレートの実装パターン

左右対称のテンプレート（Waxing/Waning）を作る場合：

```swift
// パターン: c1の位置だけ変える、clockwiseは同じ
// Waxing: c1 = center.x - d  (左)
// Waning: c1 = center.x + d  (右)
// 両方: clockwise: false, true
```

**間違い**: c1の位置とclockwiseの両方を変える（二重反転）

### 3. 実際の天文データで検証する

月相の描画が正しいかどうかは、実際の日付の天文データと照合して確認すべき：

```bash
# 検証に使えるリソース
- ウェザーニュース: https://weathernews.jp/
- 国立天文台: https://www.nao.ac.jp/
```

---

## 関連コミット

| コミット | 内容 |
|---------|------|
| `e96eecd` | fix: correct WaningCrescentMoon arc direction for proper left-lit display |
| `39aa585` | chore: clean up moon template code |

---

## 影響を受ける月相

| 月相 | phase範囲 | テンプレート | 影響 |
|------|----------|-------------|------|
| 二十六夜 | 0.78〜0.97 | WaningCrescentMoon | **修正済み** |
| 十三夜 | 0.53〜0.72 | WaningGibbousMoon | 要確認 |
| 下弦 | 0.72〜0.78 | ThirdQuarterMoon | 要確認 |

**注意**: WaningGibbousとThirdQuarterは異なる描画ロジックを使用しており、今回のバグとは別のパターン。問題が報告された場合は個別に調査が必要。

---

## 関連ドキュメント

- `TsukiSound/Domain/Moon/MoonPhaseCalculator.swift` - 月相計算
- `TsukiSound/Domain/Moon/MoonPainter.swift` - 月相描画の分岐
- `TsukiSound/Domain/Moon/Templates/` - 各月相テンプレート

---

## 更新履歴

| 日付 | 変更内容 | 更新者 |
|------|---------|--------|
| 2025-12-15 | 初版作成（RCA完了、修正実施済み） | Claude Code |

---

**作成者**: Claude Code
**レビュー**: 未実施
**ステータス**: 修正完了
