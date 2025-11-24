# CircularWaveformView 実装ガイド

**作成日**: 2025-11-24
**最終更新**: 2025-11-24

## 📋 概要

`CircularWaveformView` は、オーディオ再生中に円形のアニメーション波形を表示するSwiftUIコンポーネントです。AudioTestView内で使用され、再生状態を視覚的にフィードバックします。

### 主な特徴

- **円形レイアウト**: 30本のバーが円形に配置され、中心から放射状に伸縮
- **独立したアニメーション**: 各バーが独自の位相とタイミングで動作
- **動的振幅変調**: 時間経過とともに各バーの振幅が変化（呼吸するような動き）
- **スムーズなフェード**: 再生開始・停止時に1.5秒かけてフェードイン・アウト
- **ゆっくりした回転**: 反時計回りに50秒で1周（-0.02 cycles/second）
- **グロー効果**: 3層のシャドウによるキラキラした輝き

---

## 🏗️ アーキテクチャ

### ファイル構造

```
clock-tsukiusagi/Core/Audio/Components/
└── CircularWaveformView.swift
```

### コンポーネント構成

```swift
CircularWaveformView (View)
├── TimelineView (.animation)
│   └── GeometryReader
│       └── ZStack
│           └── ForEach(30 bars)
│               └── Capsule + Shadow + Rotation
├── Animation State (@State)
│   ├── animationStartTime: Date?
│   └── animationStopTime: Date?
└── Configuration (Constants)
    ├── Visual Parameters
    └── Animation Parameters
```

### 依存関係

- **AudioService**: `@EnvironmentObject` で注入、`isPlaying` 状態を監視
- **DesignTokens**: 色定義を全て DesignTokens から取得

---

## 🎨 視覚仕様

### レイアウトパラメータ

| パラメータ | 値 | 説明 |
|---------|---|------|
| `segmentCount` | 30 | バーの数（12°間隔） |
| `barWidth` | 2pt | バーの太さ |
| `baseBarLength` | 5.0pt | バーの基本長（円の半径） |
| `maxAmplitude` | 6.0pt | 最大振れ幅 |

### アニメーションパラメータ

| パラメータ | 値 | 説明 |
|---------|---|------|
| `animationSpeed` | 1.0 cycles/sec | バーの伸縮速度 |
| `rotationSpeed` | -0.02 cycles/sec | 回転速度（負＝反時計回り、50秒/周） |
| `amplitudeModulationSpeed` | 0.1 cycles/sec | 振幅変調速度（10秒周期） |
| `fadeInDuration` | 1.5 sec | フェードイン時間 |
| `fadeOutDuration` | 1.5 sec | フェードアウト時間 |

### 色定義（DesignTokens使用）

| 要素 | デザイントークン | 実効値 |
|-----|---------------|-------|
| バー本体 | `CommonTextColors.quinary` | white 0.5 |
| 内側シャドウ | `CommonTextColors.primary.opacity(0.9)` | white ~0.855 |
| 中間シャドウ | `CommonTextColors.tertiary.opacity(0.86)` | white ~0.6 |
| 外側シャドウ | `CommonTextColors.quaternary.opacity(0.5)` | white 0.3 |

---

## 🔧 実装の核心技術

### 1. Position-based Circular Layout（位置ベース円形レイアウト）

**問題**: `.offset()` + `.rotationEffect()` の組み合わせでは、12時方向で「カクッ」となる歪みが発生

**解決策**: cos/sin で直接円周上に配置

```swift
let x = centerX + cos(angleRad) * centerRadius
let y = centerY + sin(angleRad) * centerRadius

Capsule()
    .frame(width: length, height: barWidth)  // 横向きに描画
    .rotationEffect(.radians(angleRad))
    .position(x: x, y: y)
```

### 2. Independent Phase Offsets（独立位相オフセット）

**問題**: 全バーが同じ波を共有すると、「C字型の隙間」や「板を丸めたような」同期した動きになる

**解決策**: 各バーに独立したランダム位相を付与

```swift
private let phaseOffsets: [Double] = {
    (0..<30).map { _ in Double.random(in: 0...1000) }
}()

let wave = sin((t * animationSpeed + phaseOffset) * .pi * 2)
```

### 3. Dynamic Amplitude Modulation（動的振幅変調）

**問題**: 固定振幅だと単調で「毛虫のような」動きになる

**解決策**: 各バーの振幅を時間とともにゆっくり変化させる

```swift
// 10秒周期で振幅を変調
let amplitudePhase = t * 0.1 + phaseOffset * 0.01
let amplitudeModulation = sin(amplitudePhase * .pi * 2)
let dynamicMultiplier = 0.05 + (amplitudeModulation + 1.0) / 2.0 * 0.95
```

### 4. Power-weighted Amplitude Distribution（べき乗重み振幅分布）

**問題**: 一様ランダムだと全体が動きすぎる

**解決策**: べき乗関数で小さい値に重み付け

```swift
private let amplitudeMultipliers: [Double] = {
    (0..<30).map { _ in
        let random = Double.random(in: 0...1)
        return pow(random, 2.0) * 0.95 + 0.05  // 70%が0.3以下
    }
}()
```

### 5. Smooth Fade In/Out（スムーズフェード）

**問題**: 再生開始・停止時に「ヒュッと」いきなり動き出す

**解決策**: Ease-in-out カーブで振幅をフェード

```swift
private func calculateFadeFactor(currentTime: Date) -> Double {
    if audioService.isPlaying {
        let elapsed = currentTime.timeIntervalSince(animationStartTime)
        let progress = min(elapsed / fadeInDuration, 1.0)
        return easeInOut(progress)
    } else {
        // Fade out logic...
    }
}
```

---

## 🚨 重要な技術的注意事項

### 1. Capsule Orientation（カプセルの向き）

❌ **間違い**: 縦向きに描画してから回転

```swift
Capsule()
    .frame(width: barWidth, height: length)  // ❌ 縦向き
    .rotationEffect(...)
```

**問題**: 平行四辺形に歪んで見える

✅ **正解**: 横向きに描画してから回転

```swift
Capsule()
    .frame(width: length, height: barWidth)  // ✅ 横向き
    .rotationEffect(...)
```

### 2. Negative Frame Dimension（負のフレームサイズ）

**問題**: `maxAmplitude > baseBarLength` の時、`wave = -1.0` で負の長さになる

```swift
// baseBarLength=5.0, maxAmplitude=6.0, wave=-1.0
length = 5.0 + 6.0 * (-1.0) = -1.0  // ❌ Invalid frame dimension
```

**解決策**: 最小値を保証

```swift
let length = baseBarLength + amplitude * CGFloat(wave)
let minLength: CGFloat = 1.0
return max(length, minLength)
```

### 3. Shadow Performance（シャドウパフォーマンス）

3層のシャドウは描画負荷が高いため、`.drawingGroup()` で Metal アクセラレーションを有効化：

```swift
.drawingGroup()  // Metal acceleration for better performance
```

---

## 📊 アニメーション数式

### バーの長さ計算

```
length(i, t) = baseLength + amplitude(i, t) × wave(i, t) × fade(t)

where:
  wave(i, t) = sin(2π × (animationSpeed × t + phaseOffset[i]))

  amplitude(i, t) = maxAmplitude × baseMultiplier[i] × dynamicMultiplier(i, t)

  dynamicMultiplier(i, t) = 0.05 + 0.95 × (1 + sin(2π × (0.1t + 0.01 × phaseOffset[i]))) / 2

  fade(t) = easeInOut(min(elapsed / fadeDuration, 1.0))
```

### 回転角度計算

```
angle(i, t) = 2π × i / segmentCount + rotationAngle(t)

where:
  rotationAngle(t) = -0.02 × 2π × t  (反時計回り、50秒/周)
```

---

## 🎯 使用方法

### AudioTestView への統合

```swift
private var waveformSection: some View {
    HStack {
        Spacer()
        CircularWaveformView()
            .frame(width: 100, height: 100)
        Spacer()
    }
    .padding(.vertical, 8)
}
```

### 必要な環境

- `@EnvironmentObject var audioService: AudioService` が注入されていること
- DesignTokens が利用可能であること

---

## 🔍 デザイントークン遵守

**重要**: 全ての色は DesignTokens から取得し、ハードコードを避ける

### 正しい実装

```swift
// ✅ Correct
private var barColor: Color {
    DesignTokens.CommonTextColors.quinary
}

private var shadowColorInner: Color {
    DesignTokens.CommonTextColors.primary.opacity(0.9)
}
```

### 間違った実装

```swift
// ❌ Wrong - violates design token rules
private var barColor: Color {
    Color.white.opacity(0.5)
}

.shadow(color: Color.white.opacity(0.9), ...)
```

**参照**: `CLAUDE.md` - Design System Guidelines

---

## 🧪 テスト・検証

### Xcode Preview

3つのプレビューが用意されています：

1. **Playing State**: 再生中の動作確認（黒背景）
2. **Stopped State**: 停止中の表示確認（グラデーション背景）
3. **With Glow Effect**: グロー効果の視覚確認（追加シャドウ付き）

### ビルド確認

```bash
xcodebuild -project clock-tsukiusagi.xcodeproj \
           -scheme clock-tsukiusagi \
           -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### 実機テスト推奨事項

- アニメーションの滑らかさ（60fps維持）
- Metal アクセラレーションの効果
- バッテリー消費への影響
- 長時間再生時のメモリリーク確認

---

## 📝 開発履歴

### 実装プロセス（主要な課題と解決策）

1. **基本実装** → SimpleWaveformView の円形版を作成
2. **外円歪み問題** → centerRadius アンカーへ変更
3. **12時方向の壁効果** → position-based レイアウトへ再構築
4. **平行四辺形歪み** → Capsule を横向きに描画
5. **C字型の隙間** → 独立位相オフセット導入
6. **毛虫のような動き** → べき乗重み振幅分布
7. **単調な動き** → 動的振幅変調追加
8. **急激なスタート・ストップ** → フェードイン・アウト実装
9. **回転方向** → 反時計回りに修正（-0.05 → -0.02）
10. **色の調整** → opacity 調整、グロー強化
11. **デザイントークン違反** → 全ての色を DesignTokens 化

### パラメータ調整履歴

| パラメータ | 初期値 | 最終値 | 理由 |
|---------|-------|-------|------|
| segmentCount | 120 → 90 → 45 | 30 | 視認性向上、余白確保 |
| rotationSpeed | 0.1 | -0.02 | 反時計回り、よりゆっくり |
| maxAmplitude | 2.5 → 4.0 | 6.0 | より大きな動きの強調 |
| animationSpeed | 1.5 | 1.0 | よりゆっくりとした呼吸 |
| baseBarLength | 8.5 | 5.0 | 動きの幅を強調 |
| barColor opacity | 0.95 → 0.7 | 0.5 | より繊細な印象 |

---

## 🔗 関連コミット

主要なコミット（feature/circular-waveform-view ブランチ）：

- `62d3756` - "refactor: use DesignTokens for bar color in CircularWaveformView"
- `787f065` - "refactor: use DesignTokens for all shadow colors in CircularWaveformView"
- `61e323f` - "fix: prevent negative frame dimensions in CircularWaveformView"
- `bc487a2` - "feat: add smooth fade in/out transitions to CircularWaveformView"
- `263d6c0` - "feat: add dynamic amplitude modulation to CircularWaveformView"
- `0e77dff` - "feat: slow down CircularWaveformView rotation speed"
- `84e0d48` - "feat: reverse rotation direction and reduce bar count in CircularWaveformView"

**ブランチ**: `feature/circular-waveform-view`
**ベース**: `main`

---

## 🎓 学んだ教訓

### 1. SwiftUI のジオメトリ操作

- `.offset()` + `.rotationEffect()` は直感的だが、円形配置では歪みが発生しやすい
- `cos/sin` による直接配置の方が制御しやすく、歪みが少ない

### 2. アニメーションの自然さ

- 同期した動きは「人工的」に見える → 独立位相が重要
- 一様分布より、べき乗分布の方が「静かな中に動きがある」自然な印象
- 時間による変調（ゆっくりとした変化）が有機的な印象を生む

### 3. デザイントークンの重要性

- ハードコードされた色は保守性を下げる
- プロジェクト全体の一貫性のため、必ず DesignTokens を使用
- レビュー時に必ず色のハードコードをチェック

### 4. パフォーマンスとの両立

- 30バー × 3層シャドウ = 90個の描画オブジェクト
- `.drawingGroup()` による Metal アクセラレーションが必須
- TimelineView の更新間隔（0.05s = 20fps）も重要

---

## 📚 参考資料

### プロジェクト内ドキュメント

- `CLAUDE.md` - Design System Guidelines
- `Docs/implementation/design-tokens-guide.md` - デザイントークン使用ガイド
- `Docs/architecture/audio-system-spec.md` - AudioService 仕様

### SwiftUI リファレンス

- [TimelineView - Apple Developer](https://developer.apple.com/documentation/swiftui/timelineview)
- [GeometryReader - Apple Developer](https://developer.apple.com/documentation/swiftui/geometryreader)
- [shadow(color:radius:x:y:) - Apple Developer](https://developer.apple.com/documentation/swiftui/view/shadow(color:radius:x:y:))

---

**作成者**: Claude Code
**レビュー状況**: Pending
**関連Issue**: N/A
