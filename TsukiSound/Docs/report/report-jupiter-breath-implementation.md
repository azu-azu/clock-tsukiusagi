# Jupiter Breath（息継ぎ）実装レポート

**作成日**: 2025-11-30
**最終更新**: 2025-11-30
**ステータス**: 完了（エンベロープ方式を採用）

## 概要

Jupiter メロディにフレーズの「息継ぎ（ブレス）」を実装する際、複数の方式を試行錯誤し、最終的に **エンベロープ方式（一貫性を保った実装）** を採用した。本レポートでは、試行した方式とその結果、失敗の原因分析、成功への道筋を記録する。

## 要件

- フレーズの切れ目（16箇所）に自然な息継ぎを作る
- 「プツッ」と切れる不自然なカットは避ける
- 「すっ…」と自然に減衰する余韻を残す
- 楽譜データの意味を保持する（durBeats は楽譜通りの値）

---

## 第1フェーズ: 失敗した方式たち

### 方式1: effectiveDur方式（失敗）

**アプローチ**:
Signal側で次のノートに `breathBefore: true` がある場合、現在のノートの `effectiveDur` を短縮してエンベロープに渡す。

```swift
let nextNoteHasBreath = (index + 1 < melody.count) && melody[index + 1].breathBefore
let effectiveDur = nextNoteHasBreath ? max(noteDur - breathShift, 0.1) : noteDur

// ❌ 問題: window は noteDur ベース、envelope は effectiveDur ベース
if local >= noteStart && local < noteStart + noteDur + releaseTime {
    let env = calculateASREnvelope(time: dt, duration: effectiveDur)
    ...
}
```

**結果**: ❌ 「ブツブツ」というノイズが発生

---

### 方式2: earlyDecay方式（失敗）

**アプローチ**:
`calculateASREnvelope` に `earlyDecay` パラメータを追加し、sustain フェーズを早めに終了させる。

```swift
private func calculateASREnvelope(time: Float, duration: Float, earlyDecay: Float = 0) -> Float {
    let effectiveSustainEnd = duration - earlyDecay
    if time < attackTime { /* attack */ }
    if time < effectiveSustainEnd { return 1.0 }  // sustain ends early
    // release
}
```

**結果**: ❌ 「ザザっ」という雑音、「プツプツ切れた感じ」

---

### 方式3: breathFade方式（失敗）

**アプローチ**:
ASRエンベロープは変更せず、別レイヤーとして `breathFade` 係数を追加。ノートの終端付近で cos² フェードアウトを適用。

```swift
var breathFade: Float = 1.0
if nextNoteHasBreath {
    let fadeStartTime = noteDur - breathShift
    if dt > fadeStartTime {
        let fadeProgress = (dt - fadeStartTime) / breathShift
        let c = cos(fadeProgress * Float.pi * 0.5)
        breathFade = c * c
    }
}
output += v * env * breathFade * gainReduction * masterGain
```

**結果**: △ 改善したが「まだブツブツとする」

---

### 方式4: durBeats直接調整方式（一時採用 → 後に改善）

**アプローチ**:
Signal側のロジックは一切変更せず、データ側で durBeats を直接短縮する。

```swift
// データ側で短縮
static func withBreath(...) -> JupiterMelodyNote {
    JupiterMelodyNote(
        ...
        durBeats: dur.rawValue * breathFactor  // 0.9倍に短縮
    )
}
```

**結果**: ✅ ノイズなし、安定動作

**問題点**（Fujikoの指摘）:
- ❌ 楽譜データの意味が壊れる（durBeats が楽譜と異なる）
- ❌ データ（音価）と表現（呼吸）が混在
- ❌ 将来の拡張（MIDI出力、重ね録音など）で破綻リスク

この方式は `v0.1.0-breath-durbeats-stable` タグで保存し、根本対応を試みることにした。

---

## 第2フェーズ: 失敗の原因分析

### 共通の問題点

方式1〜3に共通していた問題：

```
❌ active window と envelope で異なる duration を使用していた
```

具体的に見ると：

```swift
// 失敗パターン
if local >= noteStart && local < noteStart + noteDur + releaseTime {  // ← noteDur
    let env = calculateASREnvelope(time: dt, duration: effectiveDur)  // ← effectiveDur
}
```

### なぜノイズが出たか

例えば 4分音符（1.0秒）を 0.9秒に短縮した場合の時間軸：

```
時間: 0.0 -------- 0.9 -------- 1.0 -------- 1.18
      │           │            │            │
      attack      effectiveDur noteDur      noteDur+release
      開始        終了          (window内)   window終了

問題の区間: 0.9 〜 1.0 秒
- window は開いている（noteDur + release = 1.18 まで）
- でも envelope は effectiveDur(0.9) で計算されている
- dt が 0.9 を超えると release 計算に入るが、window はまだ開いている
- この「ズレ」が波形計算の不連続を生む → ノイズ
```

### Fujikoの指摘の正体

> 「ノート切り替えタイミングの境界条件をまだ詰めきれてなかっただけ」

これは正しかった。問題は「envelope が悪い」のではなく、**window と envelope の不整合**だった。

---

## 第3フェーズ: 成功した実装

### 方式5: 一貫性を保ったエンベロープ方式（採用）

**キーインサイト**: active window と envelope の両方で同じ `effectiveDur` を使用する

**データ構造**:
```swift
struct JupiterMelodyNote {
    let freq: Float
    let startBar: Int
    let startBeat: Float
    let durBeats: Float    // 楽譜通りの長さ（ブレス短縮前）
    let breathAfter: Bool  // このノートの後に息継ぎを入れる
}
```

**Signal側の実装**:
```swift
func sample(at t: Float) -> Float {
    ...
    for note in melody {
        let noteStart = Float(note.startBar - 1) * barDuration + note.startBeat * beat
        let noteDur = note.durBeats * beat

        // Calculate effective duration (shortened if breathAfter)
        // Key insight: both active window AND envelope must use the same effectiveDur
        let effectiveDur = note.breathAfter ? max(noteDur - breathDuration, attackTime) : noteDur

        // ✅ 両方とも effectiveDur を使用（一貫性を保証）
        if local >= noteStart && local < noteStart + effectiveDur + releaseTime {
            let env = calculateASREnvelope(time: dt, duration: effectiveDur)
            ...
        }
    }
}
```

**結果**: ✅ ノイズなし、安定動作、楽譜データの意味も保持

---

## 最終実装の詳細

### 定数

```swift
/// Breath duration: how much to shorten note when breathAfter is true
let breathDuration: Float = 0.10  // 100ms breath gap
```

### データ例

```swift
// 通常ノート（楽譜通り）
JupiterMelodyNote(.E4, bar: 1, beat: 2.0, dur: .eighth)

// ブレス付きノート（表現として息継ぎを入れる）
JupiterMelodyNote(.G4, bar: 1, beat: 2.5, dur: .eighth, breathAfter: true)  // 🫧→
```

### 設計の優位性

| 観点 | durBeats直接方式 | 一貫性エンベロープ方式 |
|------|------------------|------------------------|
| **楽譜データの保持** | ❌ 壊れる | ✅ 保持 |
| **データと表現の分離** | ❌ 混在 | ✅ 分離 |
| **将来の拡張性** | ❌ リスクあり | ✅ 安全 |
| **ブレス量の一括調整** | △ breathFactor変更 | ✅ breathDuration変更 |
| **動作安定性** | ✅ | ✅ |

---

## 教訓

### 1. 境界条件の一貫性が最重要

Signal処理で複数の計算（window判定、envelope計算）が同じ概念（note duration）に依存する場合、**必ず同じ値を参照**すること。

```swift
// ❌ 悪い例: 異なる変数を参照
if condition(noteDur) { calculate(effectiveDur) }

// ✅ 良い例: 同じ変数を参照
if condition(effectiveDur) { calculate(effectiveDur) }
```

### 2. 「安定してるから採用」は技術的負債

durBeats直接方式は動作したが、根本的な問題（データと表現の混在）を抱えていた。時間をかけて根本原因を分析したことで、より良い解決策に到達できた。

### 3. 失敗から学ぶ

3つの失敗方式は「実装ミス」ではなく「設計の見落とし」だった。失敗の共通点を分析することで、真の原因（一貫性の欠如）を特定できた。

### 4. タグで安全網を張る

根本対応に挑戦する前に `v0.1.0-breath-durbeats-stable` タグを作成した。これにより、失敗しても安定版に戻れる安心感があった。

---

## 関連ファイル

- `TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter/JupiterMelodyData.swift`
  - `breathAfter: Bool` フィールド
  - 16箇所のブレスマーク
- `TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter/JupiterSignal.swift`
  - `breathDuration` 定数
  - 一貫性を保った effectiveDur 計算

## 関連コミット

- Tag: `v0.1.0-breath-durbeats-stable` - durBeats直接方式（フォールバック用）
- Commit: `dd43b7c` - "feat(jupiter): add breath system with withBreath() factory method"
- Commit: `9c1fa3c` - "docs: add Jupiter breath implementation report"

## 参考

- Fujikoの設計レビュー（architect/todo.md）
  - 「データに"意味"を混ぜるんはアカン。意味は別で管理するんが品のええ設計や。」
  - 「ノート切り替えタイミングの境界条件をまだ詰めきれてなかっただけ」
