# SignalEnvelopeUtils 使用ガイド

## 概要

`SignalEnvelopeUtils` は、Signal 生成時のノイズ（クリックノイズ、ポップノイズ）を防止するための共通ユーティリティです。

全ての Signal 実装で再利用可能な以下の機能を提供します：

1. **推奨アタック時間** - 周波数帯域別のガイドライン
2. **滑らかなエンベロープ** - sin²/cos² カーブによるノイズ防止
3. **ソフトクリッピング** - 振幅オーバーフローの防止
4. **純粋サイン波生成** - ノイズ最小の基本波形

---

## ノイズの原因と対策

### クリックノイズの原因

音の開始/終了時に波形が急激に変化すると、高周波ノイズ（クリック音）が発生します。

```
❌ 急激な開始         ✅ 滑らかな開始
   _____                 ___
  |     |               /   \
__|     |__         ___/     \___
  ^クリック           滑らかなアタック
```

### 低周波ほど長いアタックが必要

低周波の波形は1周期が長いため、アタック時間も長くする必要があります：

| 周波数帯域 | 推奨アタック時間 | 理由 |
|-----------|------------------|------|
| 高音（500Hz以上）| 30ms | 1周期 ≈ 2ms、15周期分 |
| 中音（200-500Hz）| 60ms | 1周期 ≈ 3-5ms |
| 低音（200Hz以下）| 120ms | 1周期 ≈ 5ms以上、十分な周期数が必要 |

---

## API リファレンス

### AttackTime（推奨アタック時間）

```swift
SignalEnvelopeUtils.AttackTime.high  // 0.03秒（高音用）
SignalEnvelopeUtils.AttackTime.mid   // 0.06秒（中音用）
SignalEnvelopeUtils.AttackTime.low   // 0.12秒（低音用）

// 周波数から自動判定
SignalEnvelopeUtils.AttackTime.recommended(for: frequency)
```

### smoothEnvelope（滑らかなエンベロープ）

```swift
SignalEnvelopeUtils.smoothEnvelope(
    t: Float,           // 音の開始からの経過時間
    duration: Float,    // 音の全体の長さ
    attack: Float,      // アタック時間
    decay: Float,       // ディケイ時定数
    releaseTime: Float = 0.15  // リリース時間（省略可）
) -> Float  // 0.0〜1.0
```

エンベロープの形状：
- **アタック**: sin² カーブ（非常に滑らか）
- **サステイン**: 指数減衰
- **リリース**: cos² カーブ（終了時のクリック防止）

### simpleEnvelope（シンプルなエンベロープ）

```swift
SignalEnvelopeUtils.simpleEnvelope(
    t: Float,       // 経過時間
    attack: Float,  // アタック時間
    decay: Float    // ディケイ時定数
) -> Float
```

リリース処理が不要な場合に使用（連続音など）。

### softClip（ソフトクリッピング）

```swift
SignalEnvelopeUtils.softClip(
    _ x: Float,
    threshold: Float = 0.8,  // クリッピング開始閾値
    ratio: Float = 0.2       // 圧縮比率
) -> Float
```

複数の音が重なった時の振幅オーバーフローを防ぎます。

### pureSine（純粋サイン波）

```swift
SignalEnvelopeUtils.pureSine(frequency: Float, t: Float) -> Float
```

倍音なしの純粋なサイン波。最もクリーンな音色。

### harmonicSine（倍音付きサイン波）

```swift
SignalEnvelopeUtils.harmonicSine(
    frequency: Float,
    t: Float,
    harmonics: [(multiplier: Float, amplitude: Float)] = [(2, 0.05), (3, 0.02)]
) -> Float
```

音色を豊かにしたい場合に使用。倍音の音量は控えめに。

---

## 使用例

### 基本的な使い方

```swift
func sample(at t: Float) -> Float {
    let noteStart: Float = 0
    let noteDuration: Float = 2.0
    let frequency: Float = 440.0  // A4

    let dt = t - noteStart

    // 周波数に応じたアタック時間を取得
    let attack = SignalEnvelopeUtils.AttackTime.recommended(for: frequency)

    // 滑らかなエンベロープ
    let env = SignalEnvelopeUtils.smoothEnvelope(
        t: dt,
        duration: noteDuration,
        attack: attack,
        decay: 2.0
    )

    // 純粋サイン波
    let wave = SignalEnvelopeUtils.pureSine(frequency: frequency, t: t)

    // ソフトクリッピングで出力
    return SignalEnvelopeUtils.softClip(wave * env * 0.3)
}
```

### 複数音のミックス

```swift
func sample(at t: Float) -> Float {
    let melodyOut = sampleMelody(at: t)
    let bassOut = sampleBass(at: t)
    let chordOut = sampleChords(at: t)

    let mixed = melodyOut + bassOut + chordOut

    // 複数音のミックス時は必ずソフトクリッピング
    return SignalEnvelopeUtils.softClip(mixed)
}
```

### 低音のサンプリング

```swift
private func sampleBass(at t: Float) -> Float {
    let bassFreq: Float = 98.0  // G2（低音）

    let env = SignalEnvelopeUtils.smoothEnvelope(
        t: dt,
        duration: noteDur,
        attack: SignalEnvelopeUtils.AttackTime.low,  // 120ms（低音用）
        decay: 2.5
    )

    let v = SignalEnvelopeUtils.pureSine(frequency: bassFreq, t: t)
    return v * env * 0.10  // 低音は控えめに
}
```

---

## ベストプラクティス

### 1. 周波数に応じたアタック時間を使う

```swift
// ✅ 良い例
let attack = SignalEnvelopeUtils.AttackTime.recommended(for: frequency)

// ❌ 悪い例（低音に短いアタック）
let attack: Float = 0.02  // 低音でクリックノイズが発生
```

### 2. 複数音のミックス時は必ずソフトクリッピング

```swift
// ✅ 良い例
let mixed = melodyOut + bassOut + chordOut
return SignalEnvelopeUtils.softClip(mixed)

// ❌ 悪い例（クリッピングなし）
return melodyOut + bassOut + chordOut  // 振幅オーバーフローの可能性
```

### 3. 音色をクリーンに保つなら純粋サイン波

```swift
// ✅ クリーンな音色
let v = SignalEnvelopeUtils.pureSine(frequency: freq, t: t)

// 倍音を使う場合は音量を控えめに
let v = SignalEnvelopeUtils.harmonicSine(
    frequency: freq,
    t: t,
    harmonics: [(2, 0.05), (3, 0.02)]  // 倍音は5%以下
)
```

### 4. ゲインは控えめに設定

```swift
// 推奨ゲイン値
let melodyGain: Float = 0.25  // メロディ
let chordGain: Float = 0.07   // 和音（控えめ）
let bassGain: Float = 0.10    // ベース（低音は控えめに）
```

---

## トラブルシューティング

### 症状: 音の開始時にクリック音が聞こえる

**原因**: アタック時間が短すぎる

**対策**:
- `AttackTime.recommended(for: frequency)` を使用
- 低音（200Hz以下）は最低でも 120ms

### 症状: 音の終了時にプチッと鳴る

**原因**: リリースがない

**対策**:
- `smoothEnvelope` を使用（リリース内蔵）
- または `releaseTime` パラメータを調整

### 症状: 複数音が重なると歪む

**原因**: 振幅オーバーフロー

**対策**:
- `softClip` を最終出力に適用
- 各パートのゲインを下げる

---

## 関連ファイル

- `TsukiSound/Core/Audio/Synthesis/Utils/SignalEnvelopeUtils.swift` - 実装
- `TsukiSound/Core/Audio/Synthesis/PureTone/GymnopedieMainMelodySignal.swift` - 使用例
- `TsukiSound/Core/Audio/Synthesis/PureTone/GnossienneIntroSignal.swift` - 使用例
