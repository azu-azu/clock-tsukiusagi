# CircularWaveformView 実装ガイド

**作成日**: 2025-11-24
**最終更新**: 2025-11-24 (有機的アニメーション実装完了)

## 📋 概要

`CircularWaveformView` は、オーディオ再生中に円形のアニメーション波形を表示するSwiftUIコンポーネントです。AudioTestView内で使用され、再生状態を視覚的にフィードバックします。

### 主な特徴

- **円形レイアウト**: 30本のバーが円形に配置され、中心から放射状に伸縮
- **独立したアニメーション**: 各バーが独自の位相とタイミングで動作
- **動的振幅変調**: 時間経過とともに各バーの振幅が変化（呼吸するような動き）
- **円の呼吸（Radius Breathing）**: 円の半径自体が±1.2ptでゆっくり変化（12.5秒周期）
- **同期モーメント**: 20秒に1回、バーが一瞬揃って動く瞬間を作る
- **動的グロー**: バーが伸びた時にシャドウが1.0〜1.5倍に膨張（ふわっと膨らむ）
- **スムーズなフェード**: 再生開始・停止時に1.5秒かけてフェードイン・アウト
- **ゆっくりした回転**: 反時計回りに50秒で1周（-0.02 cycles/second）

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

| パラメータ | 役割 | 調整の指針 |
|---------|------|----------|
| `segmentCount` | バーの本数 | 30前後。多すぎると密集、少なすぎると粗い印象 |
| `barWidth` | バーの太さ | 2pt程度。サイズに応じて調整 |
| `baseBarLength` | バーの基本長 | 円の中心半径を決定。5pt前後 |
| `maxAmplitude` | 最大振れ幅 | baseBarLengthより少し大きめで動きを強調 |

### アニメーションパラメータ

| パラメータ | 役割 | 調整の指針 |
|---------|------|----------|
| `animationSpeed` | バーの伸縮速度 | 1.0 cycles/sec前後。速いと落ち着きがない |
| `rotationSpeed` | 回転速度 | 負値=反時計回り。絶対値0.01-0.02程度でゆっくり |
| `amplitudeModulationSpeed` | 振幅変調速度 | 0.1前後。バーごとの動き変化の周期 |
| `radiusBreathingSpeed` | 半径呼吸速度 | 0.08前後。「じわーっと」感じる程度 |
| `radiusBreathingAmount` | 半径変化量 | 1-2pt程度。大きすぎると不安定に見える |
| `syncFrequency` | 同期周波数 | 0.05前後。20秒に1回程度の頻度 |
| `syncStrength` | 同期強度 | 0.3-0.4。高すぎると人工的 |
| `fadeInDuration` | フェードイン時間 | 1-2秒。急すぎず緩やかに |
| `fadeOutDuration` | フェードアウト時間 | 1-2秒。停止時の余韻 |

**注意**: 上記の値は目安です。実装時は `CircularWaveformView.swift` 内の定数定義を参照してください。

### 色定義（DesignTokens使用）

| 要素 | デザイントークン | 実効値 |
|-----|---------------|-------|
| バー本体 | `CommonTextColors.quinary` | white 0.5 |
| 内側シャドウ | `CommonTextColors.primary.opacity(0.9)` | white ~0.855 |
| 中間シャドウ | `CommonTextColors.tertiary.opacity(0.86)` | white ~0.6 |
| 外側シャドウ | `CommonTextColors.quaternary.opacity(0.5)` | white 0.3 |

---

## 🔧 実装の核心技術

### 1. Radius Breathing（円の呼吸）

**重要**: バーの長さ変化だけでなく、円の半径自体を変化させることで「有機的な丸」を実現

**解決策**: 円の中心半径をsin波で変調

```swift
// 円の半径自体が呼吸する
let radiusModulation = sin(t * radiusBreathingSpeed * π * 2) * radiusBreathingAmount
let centerRadius = baseCenterRadius + radiusModulation
```

**効果**:
- ゆっくりとした周期で「じわーっと」膨らんで縮む
- バーの長さ変化と組み合わさり、複合的な有機的動きを生む
- サンプル動画のコア技術：「線の長さ」+「円の半径揺れ」

**パラメータの目安**: `radiusBreathingSpeed` は 0.05-0.1 cycles/sec、`radiusBreathingAmount` は 1-2pt 程度

### 2. Synchronization Moments（一瞬の同期）

**問題**: 完全にランダムだと単調。全て同期すると人工的

**解決策**: 周期的に短時間だけバーが揃う瞬間を作る

```swift
// 同期波と個別波をブレンド
let individualWave = sin((t * animationSpeed + phaseOffset) * π * 2)
let syncWave = sin(t * animationSpeed * π * 2)
let wave = individualWave * (1.0 - syncFactor) + syncWave * syncFactor

// 同期係数（二次関数で柔らかいピーク）
let sharpSync = pow(max(rawSync, 0.0), 2.0)  // 柔らかいピーク
let syncFactor = sharpSync * syncStrength
```

**効果**:
- 「一瞬揃って、すぐバラバラに散る」美しい瞬間
- 二次関数（`pow 2.0`）で「壁効果」を防ぐ
- 予測不可能性と秩序のバランス

**パラメータの目安**: `syncFrequency` は 0.03-0.07 cycles/sec（15-30秒に1回）、`syncStrength` は 0.3-0.5（30-50%）

### 3. Dynamic Glow（光の膨張）

**問題**: 静的なシャドウでは動きが平板

**解決策**: バーの伸び具合に応じてグローを拡大

```swift
// バーの伸び率を計算
let extensionRatio = (length - baseBarLength) / maxAmplitude
let glowMultiplier = 1.0 + extensionRatio * glowExpansionFactor

// シャドウ半径を動的に変化
.shadow(radius: shadowRadiusInner * glowMultiplier)
.shadow(radius: shadowRadiusMiddle * glowMultiplier)
.shadow(radius: shadowRadiusOuter * glowMultiplier)
```

**効果**:
- バーが伸びた時に「ふわっと膨らむ」
- 視覚的なドラマ性を強化
- エネルギーの波動感を演出

**パラメータの目安**: `glowExpansionFactor` は 0.3-0.7（グロー拡大率30-70%）、シャドウ半径は内側から外側へ段階的に（例: 3, 6, 10）

### 4. Position-based Circular Layout（位置ベース円形レイアウト）

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

### 5. Independent Phase Offsets（独立位相オフセット）

**問題**: 全バーが同じ波を共有すると、「C字型の隙間」や「板を丸めたような」同期した動きになる

**解決策**: 各バーに独立したランダム位相を付与

```swift
private let phaseOffsets: [Double] = {
    (0..<30).map { _ in Double.random(in: 0...1000) }
}()

let wave = sin((t * animationSpeed + phaseOffset) * .pi * 2)
```

### 6. Dynamic Amplitude Modulation（動的振幅変調）

**問題**: 固定振幅だと単調で「毛虫のような」動きになる

**解決策**: 各バーの振幅を時間とともにゆっくり変化させる

```swift
// 10秒周期で振幅を変調
let amplitudePhase = t * 0.1 + phaseOffset * 0.01
let amplitudeModulation = sin(amplitudePhase * .pi * 2)
let dynamicMultiplier = 0.05 + (amplitudeModulation + 1.0) / 2.0 * 0.95
```

### 7. Power-weighted Amplitude Distribution（べき乗重み振幅分布）

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

### 8. Smooth Fade In/Out（スムーズフェード）

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
12. **有機的な動き追加** → 同期モーメント、動的グロー実装
13. **回転速度の揺らぎ削除** → 不自然だったため除去
14. **円の呼吸実装** → 半径自体を±1.2ptで変調（超重要）
15. **同期ピーク調整** → 立方関数から二次関数へ（柔らかく）
16. **呼吸速度調整** → 0.3 → 0.08 cycles/sec（じわーっと）

### パラメータ調整履歴

**調整の方向性と理由を記録。具体的な数値は実装コードを参照してください。**

| パラメータ | 調整の変遷 | 理由・学び |
|---------|---------|---------|
| segmentCount | 120 → 90 → 45 → 30程度 | 段階的に削減。視認性向上、余白確保 |
| rotationSpeed | 0.1 → -0.02程度 | 反時計回りへ変更、大幅に減速 |
| maxAmplitude | 2.5 → 4.0 → 6.0程度 | 段階的に増加。より大きな動きを強調 |
| animationSpeed | 1.5 → 1.0程度 | 減速。よりゆっくりとした呼吸感 |
| baseBarLength | 8.5 → 5.0程度 | 短縮。動きの幅（振れ幅）を強調 |
| barColor opacity | 0.95 → 0.7 → 0.5程度 | 段階的に透明化。より繊細な印象 |
| syncStrength | - → 0.4程度 | 新規追加。40%同期で自然なバランス |
| syncPower | 3.0 → 2.0 | 立方から二次へ。柔らかいピーク、壁効果防止 |
| radiusBreathingSpeed | - → 0.3 → 0.08程度 | 新規追加後、大幅減速。じわーっとした呼吸感 |
| glowMultiplier | 1.0（固定） → 1.0-1.5（動的） | 動的変化を追加。バー伸長時の光の膨張 |

**重要な学び:**
- 体感的な「ちょうど良さ」は、最初の想定値の1/3〜1/4程度になることが多い
- 速度パラメータは特に大幅な調整が必要（0.3 → 0.08など）
- 段階的な調整により、最適値を見つける

---

## 🔗 関連コミット

主要なコミット（feature/circular-waveform-view ブランチ）：

**基本実装・レイアウト修正:**
- `84e0d48` - "feat: reverse rotation direction and reduce bar count in CircularWaveformView"
- `0e77dff` - "feat: slow down CircularWaveformView rotation speed"
- `61e323f` - "fix: prevent negative frame dimensions in CircularWaveformView"

**アニメーション強化:**
- `263d6c0` - "feat: add dynamic amplitude modulation to CircularWaveformView"
- `bc487a2` - "feat: add smooth fade in/out transitions to CircularWaveformView"

**視覚調整:**
- `a6dd200` - "feat: adjust CircularWaveformView color and animation parameters"
- `7e3157d` - "feat: add subtle opacity and glow effect to CircularWaveformView"
- `905bdd3` - "feat: strengthen glow effect on CircularWaveformView bars"

**デザイントークン準拠:**
- `62d3756` - "refactor: use DesignTokens for bar color in CircularWaveformView"
- `787f065` - "refactor: use DesignTokens for all shadow colors in CircularWaveformView"

**有機的アニメーション実装:**
- `22f04ee` - "feat: add organic animation features to CircularWaveformView"
- `4c5545c` - "refactor: remove dynamic rotation speed variation"
- `fb6e15f` - "feat: add radius breathing and soften sync peaks"
- `b319fdd` - "feat: slow down radius breathing for subtle organic motion"

**ドキュメント:**
- `0955670` - "docs: add CircularWaveformView implementation guide"

**ブランチ**: `feature/circular-waveform-view`
**ベース**: `main`

---

## 🎓 学んだ教訓

### 1. 有機的アニメーションの設計原則

**「線の長さ」+「円の半径揺れ」の複合が鍵**:
- バーの長さ変化だけでは平板
- 円の半径自体を呼吸させることで「生きてる感じ」を実現
- ふじこの提案: 「サンプル動画のコアは複合的な動き」→ 的確

**同期のバランス**:
- 完全ランダム = 単調
- 完全同期 = 人工的
- **解決策**: 20秒に1回、短時間だけ揃う瞬間を作る
- べき乗関数の選択が重要: 立方（`pow 3.0`）は鋭すぎ、二次（`pow 2.0`）が自然

**速度感の微調整**:
- 最初の想定より大幅に遅くする必要がある（例: 0.3 → 0.08）
- 「じわーっと」感じる程度まで減速することが重要
- 体感的な「ちょうど良さ」は数値の1/3〜1/4程度になることが多い

### 2. SwiftUI のジオメトリ操作

- `.offset()` + `.rotationEffect()` は直感的だが、円形配置では歪みが発生しやすい
- `cos/sin` による直接配置の方が制御しやすく、歪みが少ない

### 3. アニメーションの自然さ

- 同期した動きは「人工的」に見える → 独立位相が重要
- 一様分布より、べき乗分布の方が「静かな中に動きがある」自然な印象
- 時間による変調（ゆっくりとした変化）が有機的な印象を生む
- **動的グロー**: バー伸長時の光の膨張が視覚的ドラマを強化

### 4. デザイントークンの重要性

- ハードコードされた色は保守性を下げる
- プロジェクト全体の一貫性のため、必ず DesignTokens を使用
- レビュー時に必ず色のハードコードをチェック

### 5. パフォーマンスとの両立

- 30バー × 3層シャドウ = 90個の描画オブジェクト
- `.drawingGroup()` による Metal アクセラレーションが必須
- TimelineView の更新間隔（0.05s = 20fps）も重要
- 動的グロー（glowMultiplier）はパフォーマンスへの影響が小さい

### 6. 試行錯誤の価値

- **失敗例**: 回転速度の揺らぎ → 不自然で削除
- **成功例**: 円の呼吸 → 「超重要」な有機的動きの核心
- ユーザーフィードバック（ふじこの提案）が決定的に重要

---

## 📚 参考資料

### プロジェクト内ドキュメント

- `CLAUDE.md` - Design System Guidelines
- `Docs/implementation/_guide-design-tokens.md` - デザイントークン使用ガイド
- `Docs/architecture/audio-system-spec.md` - AudioService 仕様

### SwiftUI リファレンス

- [TimelineView - Apple Developer](https://developer.apple.com/documentation/swiftui/timelineview)
- [GeometryReader - Apple Developer](https://developer.apple.com/documentation/swiftui/geometryreader)
- [shadow(color:radius:x:y:) - Apple Developer](https://developer.apple.com/documentation/swiftui/view/shadow(color:radius:x:y:))

---

**作成者**: Claude Code
**レビュー状況**: Pending
**関連Issue**: N/A
