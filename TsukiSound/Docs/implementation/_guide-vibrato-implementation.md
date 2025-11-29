# ビブラート実装ガイド

## 概要

オルガンやシンセサイザーにビブラート（音の揺らぎ）を追加する際の正しい実装方法。

---

## 重要：周波数変調（FM）vs 位相変調（PM）

### ❌ 間違った方法：周波数変調（FM）

```swift
// これは「うねうね」した不自然な音になる
let vibrato = 1.0 + sin(2.0 * Float.pi * vibratoRate * t) * vibratoDepth
let modulatedFreq = freq * vibrato
let phase = 2.0 * Float.pi * modulatedFreq * t  // 問題！
signal = sin(phase)
```

**問題点**：
- `freq * t` の計算で、周波数が時間に対して急激に変化
- 位相が不連続になり、蛇のようなうねりが発生
- 音程が安定せず、不快な揺らぎになる

### ✅ 正しい方法：位相変調（PM）

```swift
// 位相に直接揺らぎを加える（自然なビブラート）
let vibratoPhaseOffset = sin(2.0 * Float.pi * vibratoRate * t) * vibratoDepth
let phase = 2.0 * Float.pi * freq * t + vibratoPhaseOffset * freq
signal = sin(phase)
```

**利点**：
- 位相が連続的に変化
- 安定した、自然な揺らぎ
- オルガンのトレモラントのような温かみのある音

---

## 推奨パラメータ

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| vibratoRate | 3.0 - 5.0 Hz | 揺れの速さ（4Hzがオルガン的） |
| vibratoDepth | 0.001 - 0.002 | 揺れの幅（控えめが自然） |

### 深さの目安

- **0.001**: 非常に控えめ、温かみを加える程度（推奨）
- **0.002**: 軽いビブラート、存在感がある
- **0.003**: 明確なビブラート、やや強め
- **0.005以上**: 強すぎ、うねうね感が出やすい

---

## 実装例

```swift
// MARK: - Tremulant (Vibrato)

/// Vibrato rate: speed of pitch oscillation
let vibratoRate: Float = 4.0      // 4Hz

/// Vibrato depth: amount of pitch variation
/// Very subtle for stable, gentle warmth
let vibratoDepth: Float = 0.001

/// Generate a single voice with vibrato
private func generateSingleVoice(freq: Float, t: Float) -> Float {
    // Vibrato via phase modulation (more natural than FM)
    let vibratoPhaseOffset = sin(2.0 * Float.pi * vibratoRate * t) * vibratoDepth

    var signal: Float = 0.0
    for i in 0..<harmonics.count {
        let hFreq = freq * harmonics[i]
        // Base phase + vibrato offset (scaled by harmonic frequency)
        let phase = 2.0 * Float.pi * hFreq * t + vibratoPhaseOffset * hFreq
        signal += sin(phase) * harmonicAmps[i]
    }
    signal /= Float(harmonics.count)
    return signal
}
```

---

## 倍音へのビブラート適用

ビブラートを倍音（harmonics）に適用する場合、位相オフセットを倍音の周波数でスケーリングする：

```swift
let phase = 2.0 * Float.pi * hFreq * t + vibratoPhaseOffset * hFreq
```

これにより、高い倍音ほど揺らぎが大きくなり、自然な響きになる。

---

## トラブルシューティング

### 症状：蛇のようなうねうね音
**原因**: 周波数変調（FM）を使用している
**解決**: 位相変調（PM）に変更

### 症状：ビブラートが強すぎる
**原因**: vibratoDepth が大きすぎる
**解決**: 0.001 程度に下げる

### 症状：ビブラートが聞こえない
**原因**: vibratoDepth が小さすぎる、または vibratoRate が遅すぎる
**解決**: depth を 0.002 に、rate を 4Hz に調整

---

## 参考：JupiterMelodySignal での適用

- ファイル: `TsukiSound/Core/Audio/Synthesis/PureTone/JupiterMelodySignal.swift`
- vibratoRate: 4.0 Hz
- vibratoDepth: 0.001
- 効果: 大聖堂オルガンのトレモラント（Tremulant）を再現
