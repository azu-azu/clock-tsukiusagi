# Audio Preset Concepts

**Version**: 1.0
**Last Updated**: 2025-11-25

This document describes the artistic concept, design philosophy, and implementation notes for each audio preset in clock-tsukiusagi.

---

## Table of Contents

- [Pure Tone Presets](#pure-tone-presets)
  - [Moonlight Flow (月の流れ)](#moonlight-flow-月の流れ)
  - [Pentatonic Chime (チャイム)](#pentatonic-chime-チャイム)
  - [Cathedral Stillness (大聖堂の静寂)](#cathedral-stillness-大聖堂の静寂)
  - [Toy Piano Dream (トイピアノ)](#toy-piano-dream-トイピアノ)
  - [Gentle Flute Melody (やさしいフルート)](#gentle-flute-melody-やさしいフルート)
- [Natural Sound Presets](#natural-sound-presets)
  - [Dark Shape Underwater (黒いサメの影)](#dark-shape-underwater-黒いサメの影)
  - [Midnight Train (夜汽車)](#midnight-train-夜汽車)
  - [Distant Thunder (遠雷)](#distant-thunder-遠雷)
- [Design Philosophy](#design-philosophy)

---

## Pure Tone Presets

### Moonlight Flow (月の流れ)

**Added**: 2025-11-25
**File**: `MoonlightFlowSignal.swift`

#### Concept

印象派音楽の「月の光」からインスピレーションを得た、完全オリジナルのメロディプリセット。著作権の問題を避けるため、印象派の**特徴（透明感、浮遊感）だけを抽出**し、新たに作曲した単音メロディ。

月明かりの下で静かに流れる時間、揺らぐ光の粒、夜の静寂の中に漂う音の余韻をイメージ。

#### Musical Characteristics

**Key Signature**: D♭ Major
- ドビュッシーの「月の光」と同じ調性を採用
- 透明感と浮遊感のある響き

**Melody Structure** (v2 - with low notes & random variations):
```
Db3 → F4 → Ab4 → Ab3 → Eb4 → Gb4 → Db5 → C5
→ F4 → Ab3 → Db5 → Ab4 → Gb4 → Db3 → Db4
 ^             ^             ^      ^
低音         低音          低音    低音
```

- **15音のフレーズ**、サイクル時間 ~9.8秒
- **可変音長**: 0.6秒と0.8秒の組み合わせで自然なフレージング
- **低音追加**: Db3 (138Hz), Ab3 (207Hz) を4箇所に配置 — 空間の深みを演出
- **ランダム変化**: サイクルごとに微妙に異なるメロディ（月の雲の揺らぎ）
- **オクターブ範囲**: Db3 (138Hz) ～ Db5 (554Hz) — 低音はイヤホン推奨

#### Sound Design

**Harmonic Structure**:
```
Fundamental:    1.0  (100%)
2nd harmonic:   0.30 (30%)  ← Toy Piano (35%) より控えめ
3rd harmonic:   0.12 (12%)  ← Toy Piano (15%) より控えめ
```
→ ソフトで透明感のある音色（印象派の "ぼかし" に相当）

**Envelope**:
- **Attack**: 30ms — 滑らかな sin² カーブで立ち上がり、クリック音なし
- **Decay**: 2.0秒 — 非常に長い減衰で月明かりのシマー感を表現

**Reverb** (Cathedral風の大空間):
- roomSize: 2.0 (広い空間)
- damping: 0.40 (明るめのトーン、透明感)
- decay: 0.90 (非常に長いテール、余韻)
- mix: 0.55 (リバーブ成分多め、浮遊感)
- predelay: 0.030 (30ms) — バランスの取れた霧感

**Volume**: 0.30
→ アンビエント、瞑想的な音量レベル

#### Implementation Notes

**Architecture**: Signal-based (pure time function)

**Variable Duration Support**:
```swift
struct Note {
    let freq: Float
    let duration: Float
}

// 累積時間配列で効率的にノート検索
lazy var cumulativeTimes: [Float] = {
    var times: [Float] = [0.0]
    for note in melody {
        times.append(times.last! + note.duration)
    }
    return times
}()
```

**Random Variation System** (v2 - Clouds Moving Across Moon):
```swift
// サイクルごとに異なるシード値で再現可能なランダム性
let cycleIndex = Int(t / cycleDuration)
var rng = SeededRandomNumberGenerator(seed: UInt64(cycleIndex + 1000))

// 3種類の微妙な変化
1. Octave Shift (20%): 音を1オクターブ上/下に移動
2. Note Omission (10%): 雲が月を隠す（無音）
3. Duration Adjustment (30%): ±0.1秒の微調整
```

**Note Lookup Algorithm**:
- 現在時刻を累積時間配列と比較してノートインデックスを検索
- ノート開始時刻からの相対時間でエンベロープ計算
- 各ノートは独立したアタック/ディケイを持つ

#### Design Philosophy

> "印象派の絵画が「光の粒子」を描くように、音もまた「響きの粒子」として表現する。
> メロディは流れ、リバーブは空間を、長いディケイは時間の経過そのものを描く。"
>
> **(v2)** "そして雲が月を覆い、また去っていく——ランダムな揺らぎが、自然の息吹を吹き込む。"

**Inspirations**:
- 印象派音楽の透明感と浮遊感（ドビュッシー、ラヴェル）
- 月明かりの下で揺らぐ水面の反射
- 静寂の中に漂う余韻
- **(v2)** 雲が月を覆い隠す瞬間、風に揺れる光の粒子

**NOT Inspirations** (著作権回避):
- 特定の楽曲のメロディやコード進行
- 既存曲の編曲や引用

#### Use Cases

- **瞑想**: 穏やかなメロディと長い余韻が心を落ち着ける
- **睡眠導入**: アンビエントな音量と透明感のある音色
- **作業用BGM**: 主張しすぎない、背景に溶け込む音楽
- **時間感覚の演出**: 時計アプリとして「時の流れ」を音で表現

---

### Pentatonic Chime (チャイム)

**File**: `PentatonicChimeSignal.swift`

#### Concept

ペンタトニック（五音音階）の鐘の音。シンプルで普遍的な響き。

（※ 今後追記予定）

---

### Cathedral Stillness (大聖堂の静寂)

**File**: `CathedralStillnessSignal.swift`

#### Concept

大聖堂の静寂と荘厳さを表現したオルガンドローン。

（※ 今後追記予定）

---

### Toy Piano Dream (トイピアノ)

**File**: `PianoSignal.swift`, `SubPianoSignal.swift`

#### Concept

トイピアノの和音進行。夢のような、懐かしい音色。

（※ 今後追記予定）

---

### Gentle Flute Melody (やさしいフルート)

**File**: `FluteSignal.swift`

#### Concept

やさしく響くフルートのメロディ。

（※ 今後追記予定）

---

## Natural Sound Presets

### Dark Shape Underwater (黒いサメの影)

**File**: `DarkShark.swift`

#### Concept

深海を漂う黒いサメの影。不気味さと神秘性。

（※ 今後追記予定）

---

### Midnight Train (夜汽車)

**File**: `MidnightTrain.swift`

#### Concept

夜の闇を走る汽車の音。

（※ 今後追記予定）

---

### Distant Thunder (遠雷)

**File**: `DistantThunder.swift`

#### Concept

遠くで鳴る雷鳴。不穏さと自然の力。

（※ 今後追記予定）

---

## Design Philosophy

### Calm Technology

clock-tsukiusagi は「穏やかな技術 (Calm Technology)」を目指します。

- **主張しすぎない**: 音は背景に溶け込み、時間を「測る」のではなく「感じる」
- **自然との調和**: 自然音や楽器音を合成し、人工的すぎない響き
- **瞑想的**: 心を落ち着ける、リラックスできる音響設計

### Sound Design Principles

1. **Pure Tone vs Natural Sound**
   - Pure Tone: 数学的に生成されるサイン波ベースの音（精密、透明）
   - Natural Sound: ノイズや複雑な波形を含む音（温かみ、自然）

2. **Reverb as Space**
   - リバーブは「空間の表現」— 大聖堂、コンサートホール、深海
   - decay, mix, roomSize で空間の広がりと余韻を制御

3. **Long Decay = Time Itself**
   - 長い減衰時間は「時間の経過」そのものを表現
   - 音が消えていく過程で、時の流れを感じる

4. **Transparency over Complexity**
   - 複雑さではなく、透明感と純度を重視
   - 倍音構成をシンプルに保ち、音が濁らないように

### Technical Constraints

**iPhone Speaker Limitations**:
- 再生可能な周波数範囲: ~200Hz ～ 20kHz
- 100Hz以下はほぼ無音（物理的限界）
- 低音を表現する場合は 200Hz以上の可聴域で「低音らしさ」を演出

**Headphone Optimization**:
- イヤホン/ヘッドホンでは 80Hz程度まで再生可能
- デバイス別に周波数を最適化（AudioRouteMonitor使用）

### Copyright & Legal

**Original Compositions Only**:
- 既存曲のメロディ、コード進行、リズムパターンは使用しない
- 「インスピレーション」と「複製」の境界を厳守
- 音楽理論的な特徴（調性、音階、和声）は著作権の対象外

**Safe to Use**:
- 音階（ペンタトニック、メジャー、マイナー）
- 和音の種類（メジャー7th、マイナー7thなど）
- 音楽様式の特徴（印象派の透明感、ミニマリズムの反復など）

**NOT Safe**:
- 特定楽曲のメロディライン
- 特定楽曲のコード進行パターン
- 既存曲の編曲や引用

---

## Version History

- **v1.0** (2025-11-25): Initial version with Moonlight Flow concept documentation

---

🌙 *Each sound is a moment in time, gently flowing like moonlight.*
