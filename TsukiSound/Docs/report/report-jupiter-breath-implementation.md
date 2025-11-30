# Jupiter Breath（息継ぎ）実装レポート

**作成日**: 2025-11-30
**ステータス**: 完了（durBeats直接方式を採用）

## 概要

Jupiter メロディにフレーズの「息継ぎ（ブレス）」を実装する際、複数の方式を試行し、最終的に **durBeats直接調整方式** を採用した。本レポートでは、試行した方式とその結果、採用理由を記録する。

## 要件

- フレーズの切れ目（16箇所）に自然な息継ぎを作る
- 「プツッ」と切れる不自然なカットは避ける
- 「すっ…」と自然に減衰する余韻を残す

## 試行した方式と結果

### 方式1: effectiveDur方式（失敗）

**アプローチ**:
Signal側で次のノートに `breathBefore: true` がある場合、現在のノートの `effectiveDur` を短縮してエンベロープに渡す。

```swift
let nextNoteHasBreath = (index + 1 < melody.count) && melody[index + 1].breathBefore
let effectiveDur = nextNoteHasBreath ? max(noteDur - breathShift, 0.1) : noteDur
let env = calculateASREnvelope(time: dt, duration: effectiveDur)
```

**結果**: ❌ 「ブツブツ」というノイズが発生

**推測される原因**:
- エンベロープの sustain→release 遷移タイミングが急激に変わることで、波形に不連続点が生じた可能性
- effectiveDur が短すぎる場合、attack が完了する前に release に入る可能性

---

### 方式2: earlyDecay方式（失敗）

**アプローチ**:
`calculateASREnvelope` に `earlyDecay` パラメータを追加し、sustain フェーズを早めに終了させる。

```swift
private func calculateASREnvelope(time: Float, duration: Float, earlyDecay: Float = 0) -> Float {
    let effectiveSustainEnd = duration - earlyDecay
    if time < attackTime { /* attack */ }
    if time < effectiveSustainEnd { return 1.0 }  // sustain
    // release starts early
}
```

**結果**: ❌ 「ザザっ」という雑音、「プツプツ切れた感じ」

**推測される原因**:
- エンベロープ計算内部での条件分岐が複雑化し、境界条件でのエッジケースが発生
- sustainEnd と releaseTime の組み合わせで予期しない値域が生じた可能性

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

**推測される原因**:
- ASRエンベロープの release phase と breathFade が重複して適用され、急激な減衰が発生
- fadeStartTime の計算が noteDur ベースのため、タイミングのずれが生じた可能性

---

### 方式4: durBeats直接調整方式（採用）

**アプローチ**:
Signal側のロジックは一切変更せず、データ側で durBeats を直接短縮する。

```swift
// Before
JupiterMelodyNote(.A4, bar: 2, beat: 0.0, dur: .quarter)  // 1.0拍

// After
.withBreath(.A4, bar: 2, beat: 0.0, dur: .quarter)  // 0.9拍 (breathFactor適用)
```

**結果**: ✅ ノイズなし、安定動作

**成功の理由**:
- Signal側のASRエンベロープは実績ある安定コード
- 短いノートは通常のASRエンベロープで自然に減衰
- 計算ロジックの複雑化がない

## 採用理由の比較

| 観点 | エンベロープ方式 | durBeats直接方式 |
|------|------------------|------------------|
| **動作安定性** | ❌ ノイズ発生 | ✅ 安定 |
| **Signal側の複雑さ** | 条件分岐追加 | 変更なし |
| **負荷** | わずかに高い | 最小限 |
| **メンテナンス性** | 高い（一括変更可能） | やや低い |
| **楽譜との対応** | durBeatsが楽譜と一致 | durBeatsが楽譜と異なる |

### 結論

> **「動作しないコードにメンテナンス性の価値はない」**

理論的にはエンベロープ方式が美しいが、**安定性を最優先**して durBeats直接方式を採用。

## 最終実装

### breathFactor による一括管理

メンテナンス性の低下を補うため、`breathFactor` 定数と `.withBreath()` ファクトリを導入：

```swift
// 定数（一括調整可能）
private let breathFactor: Float = 0.9  // 10%短縮

// ファクトリメソッド
static func withBreath(_ pitch: JupiterPitch, bar: Int, beat: Float, dur: JupiterDuration) -> JupiterMelodyNote {
    JupiterMelodyNote(
        freq: pitch.rawValue,
        startBar: bar,
        startBeat: beat,
        durBeats: dur.rawValue * breathFactor
    )
}
```

### 使用例

```swift
// 通常ノート
JupiterMelodyNote(.E4, bar: 1, beat: 2.0, dur: .eighth),     // ミ

// ブレス付きノート（次のノートの前に息継ぎ）
.withBreath(.G4, bar: 1, beat: 2.5, dur: .eighth),           // ソ 🫧→
```

### メリット

1. **breathFactor 変更で全ブレス箇所を一括調整可能**
2. **楽譜上の音価（dur: .quarter など）が明確**
3. **`.withBreath()` で意図が明確、`🫧→` で視覚的識別**

## 教訓

1. **Signal側のリアルタイム計算は複雑化を避ける**
   - 毎サンプル実行されるコードは可能な限りシンプルに
   - 境界条件でのエッジケースが音質に直結

2. **データ側での前処理が安全**
   - 初期化時に一度だけ計算される値はデータに埋め込む
   - Signal側の条件分岐を減らせる

3. **理論より実用を優先**
   - 「意味とデータの分離」は理想だが、動作しなければ無意味
   - TsukiSoundの「静けさ」を守るには安定性が最優先

## 関連ファイル

- `TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter/JupiterMelodyData.swift` - breathFactor, withBreath() 実装
- `TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter/JupiterSignal.swift` - ASRエンベロープ（変更なし）

## 関連コミット

- Commit: `dd43b7c` - "feat(jupiter): add breath system with withBreath() factory method"
