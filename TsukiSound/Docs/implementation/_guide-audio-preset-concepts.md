# Audio Preset Concepts

**Version**: 1.0
**Last Updated**: 2025-11-25

This document describes the artistic concept, design philosophy, and implementation notes for each audio preset in TsukiSound.

---

## Table of Contents

- [Pure Tone Presets](#pure-tone-presets)
  - [Moonlight Flow (月の流れ)](#moonlight-flow-月の流れ)
  - [Moonlight Flow — Midnight (深夜の月影)](#moonlight-flow--midnight-深夜の月影)
  - [Moonlit Slumber Chimes (月のまどろみ)](#moonlit-slumber-chimes-月のまどろみ)
  - [Cathedral Stillness (大聖堂の静寂)](#cathedral-stillness-大聖堂の静寂)
  - [Fading Star Piano (消えゆく星)](#fading-star-piano-消えゆく星)
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

- **15音のフレーズ**、サイクル時間 ~**19.6秒** (2倍ゆっくり)
- **可変音長**: 1.2秒と1.6秒の組み合わせで荘厳なフレージング
- **低音追加**: Db3 (138Hz), Ab3 (207Hz) を4箇所に配置 — 空間の深みを演出
- **ランダム変化**: サイクルごとに微妙に異なるメロディ（月の雲の揺らぎ）
- **オクターブ範囲**: Db3 (138Hz) ～ Db5 (554Hz) — 低音はイヤホン推奨

#### Sound Design

**Harmonic Structure** (v3 - 豊かで重みのある音):
```
Fundamental:    1.0  (100%)
2nd harmonic:   0.55 (55%)  ← より強く、深く
3rd harmonic:   0.35 (35%)  ← より豊かに
4th harmonic:   0.20 (20%)  ← 追加（重みと荘厳さ）
```
→ 豊かで深く、重みのある音色（軽くない、存在感がある）

**Envelope**:
- **Attack**: 70ms — ゆっくりとした荘厳な立ち上がり
- **Decay**: 4.0秒 — 大聖堂のような長い余韻

**Reverb** (深く荘厳な大空間):
- roomSize: 2.4 (より広大な空間)
- damping: 0.35 (より豊かな響き)
- decay: 0.92 (より長いテール、重み)
- mix: 0.60 (より深いリバーブ)
- predelay: 0.035 (35ms) — 空間の深さ

**Volume**: 0.38
→ より存在感のある音量レベル

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

### Moonlight Flow — Midnight (深夜の月影)

**Added**: 2025-11-25
**File**: `MoonlightFlowMidnightSignal.swift`

#### Concept

"月明かり"ではなく"月の影"を描く — Moonlight shadow, not moonlight.

深夜2時の静寂と孤独を音にした、Moonlight Flow の深夜版。通常版が「優しい月明かり」なら、Midnight は「静かな路地裏の月影」。

#### Musical Characteristics

**Key Signature**: B♭ Minor (darker than D♭ Major)
- Moonlight Flow (D♭ Major) の平行短調
- 暗さと孤独を追加しながらも、調性的に親和性を保つ

**Melody Structure**:
```
Bb3 → Db4 → F3 → Ab3 → C4 → F4 → Eb4 → Bb3
→ Db4 → C4 → Ab3 → Bb2
                     ^
                  深い終わり
```

- **12音のフレーズ** (通常版15音 → より間が多い)
- **サイクル時間**: ~**21.6秒** (2倍ゆっくり)
- **可変音長**: 1.2秒、1.6秒、2.0秒の組み合わせで深い静寂
- **オクターブ範囲**: Bb2 (116Hz) ～ F4 (349Hz) — より低く、重心が下
- **下降傾向**: 沈静化していく動きで深夜の感覚を演出

#### Sound Design

**Harmonic Structure** (v3 - 豊かだが暗い):
```
Fundamental:    1.0  (100%)
2nd harmonic:   0.50 (50%)  ← 豊かで深い
3rd harmonic:   0.30 (30%)  ← 豊かだが暗め
4th harmonic:   0.15 (15%)  ← 追加（重みと深さ）
```
→ 豊かで深く、暗く、重みのある音色

**Envelope** (longer, more majestic):
- **Attack**: 80ms — ゆっくりとした深夜の荘厳な立ち上がり
- **Decay**: 4.5秒 — 通常版 (4.0秒) より長い、深い残響

**Reverb** (deep, close, foggy):
- roomSize: 2.4 (より広大な空間)
- damping: 0.32 (より豊かで暗い響き)
- decay: 0.93 (非常に長いテール、重い)
- mix: 0.62 (より深いリバーブ)
- predelay: 0.012 (12ms) — **濃い霧、親密で重い音**

**Volume**: 0.36
→ より存在感のある深夜の音量

#### Random Variation System

**Omission Rate**: 15% (通常版 10% → より多くの無音)
→ 深夜の孤独、時折訪れる沈黙

**Octave Shift**: Down only (10%)
→ 上には飛ばず、下に沈む動きのみ（深夜の重力）

**Duration Wobble**: ±0.16秒 (2倍テンポに合わせてスケール)
→ 微妙な揺らぎ、より長い音符に対応

#### Implementation Notes

**Architecture**: Signal-based (same as normal version)

**Key Differences from Normal Version**:

| Aspect | Normal (Flow) | Midnight |
|--------|---------------|----------|
| Key | D♭ Major | B♭ Minor |
| Notes | 15 | 12 |
| Cycle Time | **19.6s** | **21.6s** |
| Range | Db3~Db5 | Bb2~F4 |
| Omission | 10% | 15% |
| Octave Shift | Bidirectional | Down only |
| Predelay | 35ms | 12ms |
| Attack | 70ms | 80ms |
| Decay | 4.0s | 4.5s |
| Harmonics | [1.0, 0.55, 0.35, 0.20] | [1.0, 0.50, 0.30, 0.15] |
| Volume | 0.38 | 0.36 |
| Reverb Mix | 0.60 | 0.62 |
| Feeling | Rich, majestic moonlight | Deep, rich moon shadow |

#### Design Philosophy

> "月明かりの下でひとり歩いてる感じ。
> 夜が優しくて少し寂しい。
> 時間がゆっくり止まってる感覚。
> さっきまでの Moonlight Flow が夕方だとしたら、今はもう深夜の静寂。"

**Listening Experience**:
- 静かで、深い、少し孤独、少しミステリアス
- "月明かり"ではなく "月の影" を描く
- ノイズなし・硬い音なし
- **深夜2時の心の空白をそのまま音にした感じ**

**Inspirations**:
- 深夜2時の静寂と孤独
- 路地裏の月影
- 時間が止まったような感覚
- 濃い霧の中の近い音

#### Use Cases

- **深夜の瞑想**: より深く、孤独で、内省的な時間
- **深夜作業**: 2AM の集中、世界が止まったような感覚
- **睡眠前**: 通常版より暗く、静かで、眠りに落ちやすい
- **孤独を感じたい時**: ひとりの時間を大切にする音楽

---

### Moonlit Slumber Chimes (月のまどろみ)

**File**: `PentatonicChimeSignal.swift`

#### Concept

ペンタトニック（五音音階）の鐘の音。シンプルで普遍的な響き。月明かりの下で眠りに落ちる瞬間を表現した、穏やかなチャイム音。

（※ 今後追記予定）

---

### Cathedral Stillness (大聖堂の静寂)

**Added**: 2025-11-25 (Updated with Jupiter melody)
**Files**:
- `CathedralStillnessSignal.swift` (Organ drone)
- `MidnightDropletsSignal.swift` (Harp arpeggios)
- `JupiterMelodySignal.swift` (Jupiter melody)

#### Concept

大聖堂の静寂と荘厳さを表現した多層オルガンサウンド。Holst の "Jupiter" (『惑星』より) の旋律を取り入れ、宇宙聖堂のような響きを実現。

**3層構造**:
1. **Organ Drone** — C3 + G3 の完全5度、超低速 LFO で呼吸する土台
2. **Harp Arpeggios** — 稀に鳴る上昇アルペジオ、夜の雫のような装飾
3. **Jupiter Melody** — 荘厳なメロディ、宇宙と祈りの象徴

#### Musical Characteristics

**Layer 1: Organ Drone (Foundation)**

**Chord**: C3 (130.81 Hz) + G3 (196.00 Hz) — Perfect fifth harmony
- 和音による厚みのある響き
- 4倍音までの加算合成で透明な音色

**LFO Breathing**: 0.02 Hz (50秒で1周期)
- 音量が 0.4 ～ 0.8 の範囲でゆっくり変化
- ほぼ静止したドローンとして機能

**Volume**: 0.12 (控えめ、ベースとして機能)

---

**Layer 2: Harp Arpeggios (Sparse Decoration)**

See: [Midnight Droplets](#midnight-droplets-深夜の雫) for detailed specification.

**Integration**: Pentatonic arpeggios (C4, D4, E4, G4, A4)
- 6～15秒のランダム間隔で稀に鳴る
- 2～4音の上昇アルペジオパターン
- 5秒の長い減衰で空間に溶け込む

**Volume**: 0.22 (adjusted to 0.6 gain in mixer)

---

**Layer 3: Jupiter Chorale (Majestic Centerpiece)**

**Source**: Gustav Holst — "Thaxted" chorale from Jupiter (1918, **public domain**)
- Also known as: "I Vow to Thee, My Country" hymn tune
- The famous "big tune" from Jupiter movement
- Composer died 1934 → Copyright expired 2004 (Japan: 70 years after death)
- Using the melody is completely legal

**Key**: C Major (Holst's own C-major setting)
- Harmonizes perfectly with C/G drone foundation
- No transposition needed

**Reference**: Same melody as Ayaka Hirahara's "Jupiter" (everyday I listen to my heart~)

**Melody Structure** (3/4 time, 3 measures — complete phrase):
```
Measure 1: e8( g) a4. c8  b8. g16  c8( d) c4  b4  a8 b  a4  g4
Measure 2: c8 d e4 d8 c b a g
Measure 3: e8 g a4 c8 d8 c b a g (with extended final G)

Notes:
Measure 1 (Introduction):  E4  G4  A4   C5   B4  G4   C5  D5  C5  B4  A4 B4  A4  G4
Measure 2 (First response): C5  D5  E5   D5   C5  B4   A4  G4
Measure 3 (Climax):        E4  G4  A4   C5   D5   C5   B4  A4  G4
```

- **31音のフレーズ**（3小節の完全な音楽的アーク）、サイクル時間 ~**52-54秒**（2倍ゆっくり）
- **可変音長**: 0.4秒～2.4秒（3/4拍子のリズムを2倍にスローダウン）
- **オクターブ範囲**: E4 (329.63Hz) ～ E5 (659.25Hz)
- **感情的構造**: 導入（上昇）→ 応答（下降）→ クライマックス（再上昇）
- **ループ感軽減**: 3小節フレーズで完全な音楽的終止、最後の G4 を 1.8秒に延長
- **荘厳さ強化**: Attack 80ms（ゆっくりした立ち上がり）、Decay 4.0s（長い余韻）

#### Sound Design

**Layer 1 (Organ Drone)**:
- Harmonics: [1.0, 2.0, 3.0, 4.0]
- Amps: [0.9, 0.4, 0.25, 0.15] (柔らかめのオルガン)

**Layer 2 (Harp Arpeggios)**:
- Harmonics: [1.0, 2.0, 3.0, 4.0]
- Amps: [1.0, 0.5, 0.3, 0.15] (豊かなハープ倍音)

**Layer 3 (Jupiter Melody)**:
- Harmonics: [1.0, 2.0, 3.0, 4.0]
- Amps: [1.0, 0.45, 0.30, 0.18] (荘厳なオルガン倍音)

**Envelope (Jupiter Chorale)**:
- **Attack**: 80ms — 荘厳でゆっくりとした立ち上がり
- **Decay**: 4.0秒 — 大聖堂の壮大な余韻

**Reverb** (Cathedral atmosphere — shared by all layers):
- roomSize: 2.2 (広大な空間)
- damping: 0.35 (明るめのトーン)
- decay: 0.88 (非常に長いテール、3秒級)
- mix: 0.55 (リバーブ成分多め、荘厳さ)
- predelay: 0.04 (40ms、空間の奥行き)

**Gain Balance**:
- Organ drone: 1.0 (foundation)
- Harp: 0.6 (subdued, supports melody)
- Jupiter melody: 0.7 (prominent, centerpiece)

#### Implementation Notes

**Architecture**: 3-layer Signal-based composition

**Mixer Configuration**:
```swift
mixer.add(organSignal, gain: 1.0)     // Foundation
mixer.add(harpSignal, gain: 0.6)      // Decoration
mixer.add(jupiterSignal, gain: 0.7)   // Melody
```

All layers share the same large Cathedral reverb for cohesive atmosphere.

**Jupiter Chorale Technical**:
- Variable duration notes (0.4s to 2.4s, 2x slower tempo)
- Cumulative time array for efficient note lookup
- Per-note independent envelope (attack/decay)
- 31-note cycle, ~52-54 second loop (3 measures, complete phrase)
- Loop hiding: Extended final note (1.8s) + long reverb tail (4s)
- Volume: 0.30 (softer, meditative)
- Complete emotional arc: Introduction → Response → Climax

#### Design Philosophy

> "宇宙の静寂の中に、祈りのような旋律が響く。
> オルガンの土台、ハープの装飾、そして Jupiter の荘厳なメロディが織りなす、
> 宇宙聖堂の響き。"

**Inspirations**:
- Holst's "Jupiter" — Majesty and cosmic grandeur
- Cathedral organ music — Solemn, meditative atmosphere
- Quiet Cosmos philosophy — Stillness with occasional beauty

**Design Intent**:
- **Drone**: Timeless foundation, breathing gently
- **Harp**: Sparse decoration, like droplets in the night
- **Melody**: Majestic centerpiece, cosmic hymn

**Copyright Safety**:
- Holst's work is public domain (>70 years after death)
- Melody synthesized from scratch (no existing recordings)
- Legal to use for original composition

#### Use Cases

- **瞑想 / Meditation**: 荘厳な響きが心を静める
- **睡眠導入 / Sleep Aid**: 長い余韻と柔らかなドローン
- **作業用BGM / Background Music**: 主張しすぎない、空間に溶け込む音楽
- **時間感覚の演出 / Time Perception**: 時計アプリとして「永遠の時の流れ」を音で表現

---

### Fading Star Piano (消えゆく星)

**File**: `PianoSignal.swift`, `SubPianoSignal.swift`

#### Concept

トイピアノの和音進行。夢のような、懐かしい音色。夜空に消えゆく星のように、儚く優しい音が響く。

（※ 今後追記予定）

---

## Design Philosophy

### Calm Technology

TsukiSound は「穏やかな技術 (Calm Technology)」を目指します。

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
