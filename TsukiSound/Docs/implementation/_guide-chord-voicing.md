# Chord Voicing Guide — 和音の美しい響かせ方

**Version**: 1.1
**Last Updated**: 2025-11-30
**Purpose**: pureSineでの和音・クライマックス実装における位相干渉回避と豊かさの両立

---

## What is Chord Voicing? — 和音のボイシングとは

> 和音の響きは「どの音を」「どのタイミングで」「どの音量で」鳴らすかで決まる。
> デジタルシンセシス（特にpureSine）では、同時発音が位相干渉を起こしやすい。
> 適切なボイシングで「濁りなく豊かな響き」を実現する。

---

## 音響心理学の基礎 — なぜ「物理」と「聴感」は違うのか

音響心理学 (Psychoacoustics) は、物理的な「音」の特性と、人間がそれを「どのように知覚し、感じるか」という心理的な側面を結びつける学問。「音がどうあるべきか」ではなく、**「人がどう聞こえるか」**を科学的に扱う。

### 物理量 vs. 感覚量

| 物理量 | 感覚量 | 概要 |
|--------|--------|------|
| **周波数 (Hz)** | **ピッチ** | 物理的な振動数が高くても、必ずしも高音に聞こえるわけではない |
| **音圧 (dB)** | **ラウドネス** | 同じ音圧でも周波数により感度が違う（等ラウドネス曲線）。2kHz〜5kHzが最も大きく聞こえる |
| **波形** | **音色 (Timbre)** | 倍音構成やエンベロープで楽器を区別する |

### TsukiSoundでの実践

#### マスキング効果の回避

「ある音が、別の音を聞こえにくくする現象」を避ける。

```swift
// 高音域ゲイン調整 — マスキング回避のロジック
if note.freq >= 600.0 {
    let reductionRatio = min(1.0, (note.freq - minFreq) / (maxFreq - minFreq))
    let highFreqReduction = 1.0 - reductionRatio * 0.35
    effectiveGain *= highFreqReduction
}
```

高周波の「刺さる音」が他の音の知覚を邪魔するのを防ぐ。

#### 位相干渉とデチューン

同じタイミングで波形が打ち消し合う（位相キャンセル）ことによる音痩せを避ける。

- **階段式レイヤー**: 時間差で位相干渉を回避
- **デチューン・レイヤー**: あえて位相をずらし続けて奥行きを作る

---

## 今回学んだ3つの教訓

### 1. 同時4音は濁る（位相干渉の罠）

**問題**: Bar 38-39で4音を同時に鳴らしたら「ガチャっ」とした汚い音になった

```swift
// ❌ 同時4音 → 位相干渉で濁る
MelodyNote(freq: D3, startBar: 39, startBeat: 0.00, durBeats: 6),
MelodyNote(freq: F_4, startBar: 39, startBeat: 0.00, durBeats: 5.8),
MelodyNote(freq: A4, startBar: 39, startBeat: 0.00, durBeats: 5.5),
MelodyNote(freq: D5, startBar: 39, startBeat: 0.00, durBeats: 5.2),
```

**原因**: pureSineは倍音がないため、同じタイミングで複数の正弦波が重なると位相干渉が顕著に発生する。

---

### 2. ゲイン調整だけでは解決しない

**試したこと**: 4音のゲインを下げて音量を抑える

```swift
// ❌ ゲインを下げても位相干渉は消えない
effectiveGain = melodyGain * 0.3  // 30%に減衰
```

**結果**: 音量が下がっただけで「濁り」は残った。位相干渉は振幅の問題ではなく、タイミングの問題。

---

### 3. タイミングをずらすと澄む（階段式レイヤー）

**解決策**: 各音を80ms〜200msずらして積み上げる

```swift
// ✅ 階段式レイヤー → 位相干渉を回避
MelodyNote(freq: D3, startBar: 39, startBeat: 0.00, ...),  // Bass
MelodyNote(freq: D4, startBar: 39, startBeat: 0.12, ...),  // Mid (+80ms)
MelodyNote(freq: A4, startBar: 39, startBeat: 0.21, ...),  // Color (+140ms)
MelodyNote(freq: D5, startBar: 39, startBeat: 0.30, ...),  // High (+200ms)
```

**効果**: 柔らかく積み上がるクレッシェンド効果。「静けさの中に光が立ちのぼる」感じ。

---

## 階段式レイヤーの設計原則

### タイミング間隔の目安

| 音域間 | 推奨間隔 | 理由 |
|--------|----------|------|
| Bass → Mid | 0.10-0.15 beat (70-100ms) | 基盤が安定してから中域を乗せる |
| Mid → Color | 0.08-0.10 beat (55-70ms) | 色づけは少し早めでも良い |
| Color → High | 0.08-0.10 beat (55-70ms) | 高音は最後に「抜ける」ように |

**重要**: 高音域同士（A4-D5など）は間隔を広めに取る。近いと濁りやすい。

### ゲインバランスの目安

```
Bass（低）: 0.14-0.16  ← 床として厚め
Mid（中）:  0.10       ← 影として控えめ
Color:      0.10-0.12  ← 色づけ
High（高）: 0.08       ← 光として控えめ
```

**原則**: 低音は強め、高音は控えめ。ピラミッド型のバランス。

---

## デチューン・レイヤー — 豊かさの追加

### 問題: pureSineは「薄い」

pureSineは倍音がないため、richSineに比べて音が「薄く」感じる。
しかしrichSineは高次倍音で「キーン」と刺さる問題がある。

### 解決策: デチューン・レイヤー

同じ音を±0.5Hzずらした3つのサイン波で重ねる。

```swift
let detuneHz: Float = 0.5  // 耳でほぼ聞き分けられないレベル

let v1 = SignalEnvelopeUtils.pureSine(frequency: note.freq, t: t)           // Center
let v2 = SignalEnvelopeUtils.pureSine(frequency: note.freq + detuneHz, t: t) // +Detune
let v3 = SignalEnvelopeUtils.pureSine(frequency: note.freq - detuneHz, t: t) // -Detune
let layeredV = (v1 + v2 + v3) / 3.0
```

### 効果

- コーラスのような揺れ（LFOなしで自然に揺れる）
- 倍音を生成せず「純度高いまま豊かさ」が出る
- ±0.5Hzなら「わざとらしさゼロ」

### 注意点

| デチューン幅 | 効果 |
|-------------|------|
| ±0.3Hz | ほぼ変化なし |
| ±0.5Hz | 自然な揺らぎ（推奨） |
| ±1.0Hz | 酔う揺れ、静けさが壊れる |
| ±2.0Hz以上 | 明確なコーラス効果（意図的な場合のみ） |

---

## パフォーマンスへの影響

### 3レイヤー追加は負荷にならない

**理由**:
1. pureSineは1サンプル1回のsin()計算のみ
2. 3回×44,100Hz = 132,300回/秒（現代iPhoneでは無風）
3. フィルタ・エフェクト・FFTなし = 最軽量カテゴリ
4. 同時発音数は最大6-7音（AudioKitは30レイヤーまで余裕）

**予測CPU使用率**: 2-4%（iPhone 12-15想定）

---

## クライマックスの余韻設計

### 減衰時間の延長

```swift
// クライマックスは余韻を長く
let effectiveDecay = isClimax ? melodyDecay * 2.0 : melodyDecay
// 4.5 * 2.0 = 9秒の余韻
```

**効果**:
- 高音が「洗われるように」消えていく
- ジムノペディの「永遠に続く余白」が出る
- サイン波の弱点（急に切れる）を回避

---

## 和音アタックの調整

### pureSineなら短くできる

```swift
let chordAttack: Float = 0.05  // 50ms（pureSine限定）
```

**効果**: 和音が「パッと開く」ような響き

**注意**: richSine（倍音あり）で0.05sはクリックノイズの原因になる。0.08-0.12sが安全。

---

## 実装チェックリスト

和音・クライマックスを実装するとき:

- [ ] 同時4音以上を避け、階段式レイヤーを検討した
- [ ] 高音域同士の間隔を広めに取った（80ms以上）
- [ ] ゲインは「低音強め、高音控えめ」のピラミッド型
- [ ] デチューン・レイヤー（±0.5Hz）で豊かさを追加した
- [ ] クライマックスの減衰を延長した（2.0倍など）
- [ ] pureSineの場合、和音アタックを短縮可能（0.05s）

---

## GymnopedieMainMelodySignalでの実装例

### 階段式クライマックス（Bar 39）

```swift
// Bar 39: D Major - 最終クライマックス（階段式レイヤー）
// Bass → Mid → Color → High の順で積み上げ
MelodyNote(freq: D3, startBar: 39, startBeat: 0.00, durBeats: 6.0, customGain: 0.16),  // Bass
MelodyNote(freq: D4, startBar: 39, startBeat: 0.12, durBeats: 5.8, customGain: 0.10),  // Mid
MelodyNote(freq: A4, startBar: 39, startBeat: 0.21, durBeats: 5.5, customGain: 0.12),  // Color
MelodyNote(freq: D5, startBar: 39, startBeat: 0.30, durBeats: 5.2, customGain: 0.08)   // High
```

### デチューン・レイヤー

```swift
let detuneHz: Float = 0.5

let v1 = SignalEnvelopeUtils.pureSine(frequency: note.freq, t: t)
let v2 = SignalEnvelopeUtils.pureSine(frequency: note.freq + detuneHz, t: t)
let v3 = SignalEnvelopeUtils.pureSine(frequency: note.freq - detuneHz, t: t)
let layeredV = (v1 + v2 + v3) / 3.0

output += layeredV * env * effectiveGain
```

---

## Related Documents

- `_guide-audio-smoothness.md` — 音の滑らかさガイド（高音域ゲイン調整）
- `_guide-signal-envelope-utils.md` — SignalEnvelopeUtils API詳細
- `_guide-transpose.md` — 移調の正しい実装方法

---

## Revision History

| Date | Version | Change |
|------|---------|--------|
| 2025-11-30 | 1.1 | 音響心理学セクション追加（物理量vs感覚量、マスキング効果、位相干渉） |
| 2025-11-30 | 1.0 | 初版作成（Gymnopédieクライマックス実装からの学び） |
