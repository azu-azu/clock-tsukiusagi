# Audio Preset Concepts

**Version**: 3.0
**Last Updated**: 2025-12-11

This document describes the artistic concept, design philosophy, and implementation notes for each audio preset in TsukiSound.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Current Presets](#current-presets)
  - [Jupiter (ジュピターの響き)](#jupiter-ジュピターの響き)
  - [Moonlit Gymnopédie (月明かりのジムノペディ)](#moonlit-gymnopédie-月明かりのジムノペディ)
  - [Acoustic Gymnopédie (アコースティック・ジムノペディ)](#acoustic-gymnopédie-アコースティック・ジムノペディ)
- [Design Philosophy](#design-philosophy)

---

## Architecture Overview

TsukiSound uses **offline audio generation** with professional-quality effects:

```
Python (NumPy) → Pedalboard Effects → WAV → CAF → iOS Playback
```

**Key Components**:
- **Generation**: Python scripts with NumPy for waveform synthesis
- **Effects**: Spotify's Pedalboard (Compressor + Reverb + Limiter)
- **Format**: CAF files (Float32, 48kHz, mono)
- **Playback**: AVAudioEngine with TrackPlayer (file-based playback)

**Why Offline Generation?**
- Professional VST-quality effects without runtime CPU load
- iOS only handles simple file playback (lightweight)
- Consistent audio quality across all devices

---

## Current Presets

### Jupiter (ジュピターの響き)

**Script**: `scripts/generate_jupiter.py`
**Audio**: `jupiter.caf` (~70 seconds)

#### Concept

Holst の "Jupiter" (『惑星』より) の旋律を取り入れた荘厳なサウンド。オルガンドローン、メロディ、ツリーチャイムの3層構造。

**3層構造**:
1. **Organ Drone** — C3 + G3 の完全5度、超低速 LFO で呼吸する土台
2. **Jupiter Melody** — 荘厳なメロディ、宇宙と祈りの象徴
3. **Tree Chime** — 金属的なシマー、装飾音

#### Musical Characteristics

**Key**: C Major
**Time Signature**: 3/4
**Tempo**: Variable (section-based tempo changes)

**Jupiter Melody Source**: Gustav Holst — "Thaxted" chorale (1918, **public domain**)
- Composer died 1934 → Copyright expired 2004 (Japan: 70 years after death)

#### Effects Chain (Pedalboard)

```python
Pedalboard([
    Compressor(threshold_db=-20, ratio=2.5, attack_ms=30, release_ms=250),
    Reverb(room_size=0.7, damping=0.4, wet_level=0.45, dry_level=0.55),
    Limiter(threshold_db=-1.0)
])
```

---

### Moonlit Gymnopédie (月明かりのジムノペディ)

**Script**: `scripts/generate_moonlit_gymnopedie.py`
**Audio**: `moonlit_gymnopedie.caf` (~84 seconds)

#### Concept

Satie の「ジムノペディ第1番」(1888, **public domain**) をオルゴール音色で表現。月明かりの下で静かに響く、儚く優しい音。

**3層構造**:
1. **Bass** — 1拍目に低音を配置、和声の土台
2. **Chord** — 2-3拍目に和音、空間を埋める
3. **Melody** — 右手メロディ、オルゴールの透明な音色

#### Musical Characteristics

**Key**: D Major (F#, C#)
**Time Signature**: 3/4
**Tempo**: 88 BPM

**Sound Design**: Music box timbre
- Bell-like metallic tones with quick decay
- Harmonic structure optimized for music box sound

#### Effects Chain (Pedalboard)

```python
Pedalboard([
    Compressor(threshold_db=-18, ratio=2.5, attack_ms=20, release_ms=200),
    Reverb(room_size=0.4, damping=0.6, wet_level=0.25, dry_level=0.75),
    Limiter(threshold_db=-1.0)
])
```

#### Copyright Safety

- Erik Satie died 1925 → Copyright expired 1995 (Japan: 70 years after death)
- Melody synthesized from score transcription

---

### Acoustic Gymnopédie (アコースティック・ジムノペディ)

**Script**: `scripts/generate_acoustic_gymnopedie.py`
**Audio**: `acoustic_gymnopedie.caf`

#### Concept

ジムノペディをアコースティックギター風の音色で表現。温かみのある、親しみやすいサウンド。

（※ 詳細は generate_acoustic_gymnopedie.py を参照）

---

## Design Philosophy

### Calm Technology

TsukiSound は「穏やかな技術 (Calm Technology)」を目指します。

- **主張しすぎない**: 音は背景に溶け込み、時間を「測る」のではなく「感じる」
- **自然との調和**: 自然音や楽器音を合成し、人工的すぎない響き
- **瞑想的**: 心を落ち着ける、リラックスできる音響設計

### Sound Design Principles

1. **Offline Generation**
   - 重い DSP 処理はすべてビルド前に完了
   - iOS は軽量な再生のみ担当

2. **Professional Effects via Pedalboard**
   - Compressor: ダイナミクスの均一化
   - Reverb: 空間表現
   - Limiter: クリッピング防止

3. **Long Decay = Time Itself**
   - 長い減衰時間は「時間の経過」そのものを表現
   - 音が消えていく過程で、時の流れを感じる

4. **Seamless Looping**
   - Fade-in/fade-out で自然なループ
   - silence padding でループ境界を滑らかに

### Copyright & Legal

**Public Domain Works Used**:
- Gustav Holst — "Jupiter" (1918) — died 1934, copyright expired 2004
- Erik Satie — "Gymnopédie No.1" (1888) — died 1925, copyright expired 1995

**Safe to Use**:
- パブリックドメインの楽曲メロディ
- 独自に合成した音色（既存録音の使用なし）

---

## Version History

- **v3.0** (2025-12-11): Rewritten for offline generation architecture with Pedalboard
- **v2.0** (2025-11-27): Updated for current presets
- **v1.0** (2025-11-25): Initial version

---

🌙 *Each sound is a moment in time, gently flowing like moonlight.*
