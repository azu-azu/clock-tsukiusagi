# Organ Envelope Guide — オルガン音色のASRエンベロープ

**Version**: 1.0
**Last Updated**: 2025-11-30
**Purpose**: オルガン系音色（Jupiter等）で「持続する音」を実現するためのASRエンベロープ設計ガイド

---

## なぜこのガイドが必要か

TsukiSoundでは2種類のエンベロープ方式を使い分けています：

| 方式 | 用途 | 特徴 |
|-----|------|------|
| **AD（Attack-Decay）** | ピアノ、シンセパッド | すぐ減衰する |
| **ASR（Attack-Sustain-Release）** | オルガン、持続音 | 音符の間ボリューム維持 |

**誤った方式を選ぶと音色が完全に変わってしまいます。**

---

## ASR vs AD — 決定的な違い

### AD（Attack-Decay）— すぐ消えていく音

```
音量
1.0  /\
    /  \
   /    \
  /      \
0.0       \─────────

   Attack → すぐDecay開始
```

- **特徴**: 立ち上がった後、すぐに減衰が始まる
- **聴感**: ピアノやシンセパッドのように「すぐ消えていく音」
- **実装**: `SignalEnvelopeUtils.smoothEnvelope`

### ASR（Attack-Sustain-Release）— 伸び続ける音

```
音量
1.0  ┌─────── Sustain ───────┐
     │                        │
    ╱│                        │╲
   ╱ │                        │ ╲
0.0──┴────────────────────────┴──╲───

   Attack → Sustain維持 → Release
```

- **特徴**: 音符の間、フルボリュームを維持する
- **聴感**: オルガンのように「ぶわーんと残る音」
- **実装**: カスタム `calculateASREnvelope`

---

## 音色別の選択基準

| 音色タイプ | 推奨方式 | 理由 |
|-----------|---------|------|
| オルガン（Jupiter） | **ASR** | パイプオルガンは鍵盤を押している間ずっと鳴る |
| ピアノ（Gymnopédie） | AD | ハンマーで叩いた後、徐々に減衰する |
| シンセパッド | AD | ふわっと立ち上がり、ゆっくり消える |
| 持続系ドローン | **ASR** | 一定の音量を維持し続ける |
| パーカッション | AD | 短いアタック、すぐ減衰 |

---

## Jupiter での ASR 実装

### エンベロープ計算

```swift
private func calculateASREnvelope(
    time: Float,
    duration: Float,
    releaseTime: Float
) -> Float {
    // Attack phase: smooth cosine rise
    if time < attackTime {
        let progress = time / attackTime
        return (1.0 - cos(progress * Float.pi)) * 0.5
    }

    // Sustain phase: full volume until note ends
    if time < duration {
        return 1.0  // ← ここが重要！フルボリューム維持
    }

    // Release phase: smooth cosine fade
    let releaseProgress = (time - duration) / releaseTime
    if releaseProgress < 1.0 {
        return (1.0 + cos(releaseProgress * Float.pi)) * 0.5
    }

    return 0.0
}
```

### 推奨パラメータ（Jupiter）

```swift
let attackTime: Float = 0.15   // 150ms - 16分音符でも滑らか
let releaseTime: Float = 0.80  // 800ms - 自然な余韻
```

---

## Legato Crossfade — ノート間の滑らかな接続

### 問題: ノートが連続するときの音量スパイク

ASRエンベロープでは、ノートが連続する（back-to-back）とき、
前のノートのリリースと次のノートのアタックが重なり、音量が急増します。

```
問題のある遷移:
G4: [Sustain 1.0]────[Release 0.8s]────→
C5:                   [Attack]────[Sustain 1.0]
                      ↑ 音量スパイク（最大2.0）
```

### 解決策: Legato Crossfade

次のノートが始まる前にリリースを短縮し、滑らかに遷移させます：

```
滑らかな遷移:
G4: [Sustain 1.0]────[Release 0.1s]→
C5:              [Attack]────[Sustain 1.0]
                 ↑ 滑らかな接続
```

### 実装

```swift
let legatoCrossfade: Float = 0.10  // 100ms crossfade

private func calculateEffectiveRelease(
    noteIndex: Int,
    noteEnd: Float,
    local: Float
) -> Float {
    let nextIndex = noteIndex + 1
    if nextIndex < melody.count {
        let nextNote = melody[nextIndex]
        let nextStart = Float(nextNote.startBar - 1) * barDuration
                      + nextNote.startBeat * beat

        if nextStart < noteEnd + releaseTime {
            let timeUntilNext = nextStart - noteEnd
            if timeUntilNext <= 0 {
                // ノートが連続: 短いクロスフェード
                return legatoCrossfade
            } else {
                // 少し間がある: 間隔+クロスフェード
                return min(timeUntilNext + legatoCrossfade, releaseTime)
            }
        }
    }
    return releaseTime  // 次のノートなし: フルリリース
}
```

---

## よくある失敗と対策

### 失敗1: オルガンにADエンベロープを使う

**症状**: 音が「すぐ消えていく」、オルガンらしくない

**原因**: `SignalEnvelopeUtils.smoothEnvelope`（AD方式）を使用

**対策**: カスタムASRエンベロープに切り替える

### 失敗2: ノート間で音が急に大きくなる

**症状**: 特定のノート遷移で「パチッ」または音量スパイク

**原因**: 前のノートのリリースと次のノートのアタックが重なる

**対策**: Legato Crossfadeを実装

### 失敗3: 16分音符でクリック音

**症状**: 短い音符でクリックノイズが発生

**原因**: アタック時間が音符の長さより長い

**対策**: attackTimeを音符の最短値以下に設定（150ms程度）

---

## Quick Checklist

オルガン系音色の実装時：

- [ ] ASRエンベロープを使用（ADではない）
- [ ] Sustain phaseでフルボリューム（1.0）を維持
- [ ] attackTime ≤ 最短音符の長さ
- [ ] Legato Crossfadeを実装
- [ ] softClipで振幅オーバーフロー防止

---

## Related Documents

- `_guide-signal-envelope-utils.md` — AD方式のsmoothEnvelope API
- `_guide-audio-smoothness.md` — エンベロープの滑らかさ全般
- `_guide-chord-voicing.md` — 和音の重ね方
- `report/report-jupiter-melody-optimization.md` — Jupiterメロディ最適化レポート

---

## Revision History

| Date | Version | Change |
|------|---------|--------|
| 2025-11-30 | 1.0 | 初版作成 — ASR vs AD、Legato Crossfade |
