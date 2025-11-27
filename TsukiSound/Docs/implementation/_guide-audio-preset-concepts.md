# Audio Preset Concepts

**Version**: 2.0
**Last Updated**: 2025-11-27

This document describes the artistic concept, design philosophy, and implementation notes for each audio preset in TsukiSound.

---

## Table of Contents

- [Pure Tone Presets](#pure-tone-presets)
  - [Cathedral Stillness (大聖堂の静寂)](#cathedral-stillness-大聖堂の静寂)
  - [Fading Star Piano (消えゆく星)](#fading-star-piano-消えゆく星)
  - [Moonlit Gymnopédie (月明かりのジムノペディ)](#moonlit-gymnopédie-月明かりのジムノペディ)
  - [Midnight Gnossienne (真夜中のグノシエンヌ)](#midnight-gnossienne-真夜中のグノシエンヌ)
- [Design Philosophy](#design-philosophy)

---

## Pure Tone Presets

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

### Moonlit Gymnopédie (月明かりのジムノペディ)

**Added**: 2025-11-27
**File**: `GymnopedieMainMelodySignal.swift`

#### Concept

Satie の「ジムノペディ第1番」(1888, **public domain**) をアンビエント解釈した3層構造のピアノサウンド。月明かりの下で静かに響くピアノの音色。

**3層構造**:
1. **Bass** — 1拍目に低音を配置、和声の土台
2. **Chord** — 2-3拍目に和音、空間を埋める
3. **Melody** — 右手メロディ、透明感のある主旋律

#### Musical Characteristics

**Key Signature**: D Major (F#, C#)
- サティの原曲と同じ調性
- 穏やかで透明感のある響き

**Time Signature**: 3/4
- ワルツのリズムで、ゆったりとした流れ

**Tempo**: 80 BPM (原曲より少し速め)
- 1拍 = 0.75秒
- 全曲（41小節）約92秒でループ

**Melody Range**: E4 (329.63Hz) ～ A5 (880Hz)

#### Sound Design

**Envelope**:
- Melody: Attack 80ms, Decay 2.5s
- Bass: Attack 120ms, Decay 2.5s
- Chord: Attack 80ms, Decay 1.8s

**Volume Balance**:
- Melody: 0.28
- Bass: 0.12
- Chord: 0.08

**Reverb** (Spacious, moonlit):
- roomSize: 2.2
- damping: 0.40
- decay: 0.85
- mix: 0.45
- predelay: 0.030

#### Copyright Safety

- Erik Satie died 1925 → Copyright expired 1995 (Japan: 70 years after death)
- Melody synthesized from score transcription
- Legal to use for original composition

---

### Midnight Gnossienne (真夜中のグノシエンヌ)

**Added**: 2025-11-27
**File**: `GnossienneIntroSignal.swift`

#### Concept

Satie の「グノシエンヌ第1番」(1890, **public domain**) をアンビエント解釈したピアノサウンド。深夜の静寂の中、ミステリアスで内省的な音色が響く。

**特徴**:
- 東洋的なスケール（フリギア旋法）
- 拍子記号なし（自由なテンポ）
- 暗く神秘的な雰囲気

#### Musical Characteristics

**Mode**: F Phrygian-like scale
- 東洋的で神秘的な響き
- 短2度の特徴的な音程

**Tempo**: Variable (free tempo interpretation)
- サティの原曲同様、拍子記号なし
- アンビエント解釈で自由なテンポ

#### Sound Design

**Reverb** (Dark, mysterious):
- roomSize: 2.4
- damping: 0.35
- decay: 0.90
- mix: 0.50
- predelay: 0.035

#### Copyright Safety

- Erik Satie died 1925 → Copyright expired 1995 (Japan: 70 years after death)
- Melody synthesized from score transcription
- Legal to use for original composition

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

**Public Domain Works Used**:
- Gustav Holst — "Jupiter" (1918) — died 1934, copyright expired 2004
- Erik Satie — "Gymnopédie No.1" (1888) — died 1925, copyright expired 1995
- Erik Satie — "Gnossienne No.1" (1890) — died 1925, copyright expired 1995

**Safe to Use**:
- 音階（ペンタトニック、メジャー、マイナー）
- 和音の種類（メジャー7th、マイナー7thなど）
- 音楽様式の特徴（印象派の透明感、ミニマリズムの反復など）
- パブリックドメインの楽曲メロディ

**NOT Safe**:
- 著作権保護期間内の楽曲のメロディライン
- 既存曲の編曲や録音の使用

---

## Version History

- **v2.0** (2025-11-27): Updated for current presets (removed deleted presets, added Satie presets)
- **v1.0** (2025-11-25): Initial version with Moonlight Flow concept documentation

---

🌙 *Each sound is a moment in time, gently flowing like moonlight.*
