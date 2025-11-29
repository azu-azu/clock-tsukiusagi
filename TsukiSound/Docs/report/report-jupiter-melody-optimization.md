# Jupiter Melody パフォーマンス最適化ガイド

## 概要

JupiterMelodySignal の音質向上において、**レイヤー追加よりエンベロープ＋ビブラートが最適解**である理由と、その実装方法を解説する。

---

## 背景：レイヤー追加による問題

### 試みた改善

荘厳なオルガンサウンドを実現するため、パイプオルガンの「ストップ」を模した4レイヤー構成を試みた：

```swift
// 4レイヤー構成（問題あり）
private func generateTone(freq: Float, t: Float) -> Float {
    let mainTone = generateSingleVoice(freq: freq, t: t)           // 8' Principal
    let subOctaveTone = generateSingleVoice(freq: freq * 0.5, t: t) * 0.4   // 16' Sub
    let quintTone = generateSingleVoice(freq: freq * 1.5, t: t) * 0.15      // Quint 2-2/3'
    let octaveAboveTone = generateSingleVoice(freq: freq * 2.0, t: t) * 0.2 // 4' Octave
    return mainTone + subOctaveTone + quintTone + octaveAboveTone
}
```

### 発生した問題

**音飛び（ザザザという音）** が発生。原因は計算負荷：

```
1サンプルあたりの sin() 計算：
- harmonics 6本 × レイヤー 4つ = 24回
- legato overlap で前のノートも鳴らすと × 2 = 48回
- 44100Hz × 48 = 約210万回/秒

→ リアルタイム処理が追いつかない
```

---

## 解決策：エンベロープ＋ビブラート

### 負荷比較

| アプローチ | 効果 | 負荷増加 |
|-----------|------|----------|
| エンベロープ調整 | 滑らかさ、荘厳さ | ほぼゼロ |
| ビブラート追加 | 有機的な揺らぎ | sin() 1回/サンプル |
| レイヤー追加 | 豊かな倍音、深み | **4倍** |

### 最適な構成

```swift
// 1レイヤー構成（推奨）
private func generateTone(freq: Float, t: Float) -> Float {
    return generateSingleVoice(freq: freq, t: t)  // 8' Principal のみ
}
```

レイヤーは1つのまま、以下で荘厳さを実現：

1. **スローエンベロープ** - 音の立ち上がり・余韻を長く
2. **レガートオーバーラップ** - ノート間の滑らかな接続
3. **ビブラート（位相変調）** - 有機的な揺らぎ

---

## 実装詳細

### エンベロープパラメータ

```swift
// 滑らかで荘厳なエンベロープ
let attackTime: Float = 0.40   // 400ms: ゆっくり立ち上がる
let releaseTime: Float = 0.8   // 800ms: 長い余韻
let legatoOverlap: Float = 0.10 // 100ms: ノート間の重なり
```

**効果：**
- `attackTime 0.40s`: 音がふわっと出てくる（パイプオルガンの風圧上昇を模倣）
- `releaseTime 0.8s`: 音が大聖堂に響き渡るような余韻
- `legatoOverlap 0.10s`: 前の音と次の音が溶け合う

### ビブラートパラメータ

```swift
// Tremulant（オルガンのビブラート機構）
let vibratoRate: Float = 4.0    // 4Hz: 自然な揺れ速度
let vibratoDepth: Float = 0.001 // 控えめな深さ
```

**重要**: 周波数変調（FM）ではなく**位相変調（PM）**を使用：

```swift
// ✅ 正しい：位相変調
let vibrato = sin(2π * vibratoRate * t) * vibratoDepth
let phase = 2π * (wrappedPhase + vibrato)

// ❌ 間違い：周波数変調（蛇のようなうねりになる）
let modulatedFreq = freq * (1.0 + vibrato)
let phase = 2π * modulatedFreq * t
```

詳細は `_guide-vibrato-implementation.md` を参照。

---

## パラメータ比較

| 項目 | 安定版 (v1) | 最適化版 |
|------|------------|---------|
| レイヤー | 1 | 1 |
| harmonics | 5本 | 6本 |
| attackTime | 0.15秒 | **0.40秒** |
| releaseTime | 0.3秒 | **0.8秒** |
| legatoOverlap | なし | **0.10秒** |
| vibrato | なし | **あり** |
| テンポ | 54 BPM | **50 BPM** |

---

## 計算負荷の目安

| 構成 | sin() 計算/サンプル | 計算/秒 |
|------|-------------------|--------|
| 1レイヤー × 6倍音 | 6 | 26万回 |
| 1レイヤー × 6倍音 × legato | 12 | 53万回 |
| 4レイヤー × 6倍音 × legato | 48 | **210万回** ❌ |

**目安**: 50万回/秒 程度が安全圏

---

## 将来の拡張オプション

レイヤーを復活させたい場合の選択肢：

1. **レイヤーを2つに抑える** (Main + Sub-octave)
   - 計算量: 約100万回/秒（ギリギリ許容範囲）

2. **ルックアップテーブル最適化**
   - sin() を事前計算したテーブルで置き換え
   - 精度は落ちるが高速化

3. **高性能デバイス限定**
   - デバイス検出してレイヤー数を動的に変更
   - 古いデバイスは1レイヤー、新しいデバイスは4レイヤー

---

## 結論

**荘厳さの実現方法として、レイヤー追加よりエンベロープ＋ビブラートが最適。**

- レイヤー追加: 効果大だが負荷4倍 → 音飛びの原因
- エンベロープ調整: 負荷ゼロで滑らかさ向上
- ビブラート: 負荷最小で有機的な揺らぎ

1レイヤーでも十分な荘厳さは実現可能。

---

## 参考ファイル

- 実装: `TsukiSound/Core/Audio/Synthesis/PureTone/JupiterMelodySignal.swift`
- ビブラート詳細: `_guide-vibrato-implementation.md`
- 配列イテレーション: `_guide-zip-safe-iteration.md`
