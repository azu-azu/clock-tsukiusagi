# Audio Smoothness Guide — 音の「滑らかさ」設計ガイド

**Version**: 1.0
**Last Updated**: 2025-11-30
**Purpose**: TsukiSoundにおける「滑らかさ」の設計ルールとベストプラクティス

---

## Overview

音の滑らかさは、**4つの層**で守られます：

1. **Wave Smoothness** — 波形レベルの滑らかさ
2. **Envelope Smoothness** — 立ち上がり・減衰の滑らかさ
3. **Parameter Smoothness** — パラメータ変化の滑らかさ
4. **Structural Smoothness** — 構造レベルでの滑らかさ

急激な変化は常にノイズ（クリック、ポップ、歪み）の原因になります。

---

## 1. Wave Smoothness（波形の滑らかさ）

### ゼロクロスで切り替える

- 開始・終了ポイントは必ず **同じ符号のゼロクロス** に揃える
- 音量ゼロの直前に急なブロックがあると → パチパチ音の原因

### フェードは適切な長さで

| 長さ | 結果 |
|------|------|
| 0ms | クリック音発生 |
| 3〜20ms | 適切 |
| 長すぎる | 不自然な「吸い込まれ感」 |

**TsukiSound推奨値**:
- フェードイン: 10〜70ms
- フェードアウト: 50〜200ms

---

## 2. Envelope Smoothness（立ち上がり・減衰）

### attack = 0 は禁止

**例外なくクリック音が発生します。**

SignalEnvelopeUtils で定義された推奨アタック時間：

| 周波数帯域 | 推奨アタック時間 | 定数 |
|-----------|------------------|------|
| 高音（500Hz以上） | 30ms (0.03s) | `AttackTime.high` |
| 中音（200-500Hz） | 60ms (0.06s) | `AttackTime.mid` |
| 低音（200Hz以下） | 120ms (0.12s) | `AttackTime.low` |

**なぜ低音ほど長いアタックが必要か**:
- 低周波の波形は1周期が長い
- 十分な周期数がないと、立ち上がりがクリックとして聞こえる
- 例: 100Hzは1周期10ms → アタック120msで12周期分確保

### sin²カーブでアタック

線形より指数/sin²カーブの方が自然に聴こえます：

```swift
// SignalEnvelopeUtils.smoothEnvelope の実装
if t < attack {
    let p = t / attack
    let s = sin(p * Float.pi * 0.5)
    return s * s  // sin²カーブ
}
```

### release は音楽的に決める

| 音源タイプ | 推奨リリース |
|-----------|-------------|
| メロディ系 | 0.1〜0.2秒 |
| Pads/Ambience | 0.3〜1.5秒 |
| パーカッション | 0.05〜0.1秒 |

### Envelope の急変は禁止

- アタック/リリースのパラメータを途中で変更しない
- 変更が必要な場合は、音の境界（小節の区切り等）で行う

---

## 3. Parameter Smoothness（パラメータ変化の滑らかさ）

### 値を "突然" 変えない

以下のパラメータは急激に変化させてはいけません：

- `volume` / `gain`
- `cutoff` / `resonance` (フィルター)
- `harmonicAmplitudes` (倍音構成)
- `pan` / `balance`

すべての変更は「線形または指数スムージング」で行います。

### LFO の周期は短すぎるとノイズ化する

| 周期 | 結果 |
|------|------|
| < 0.1秒 | 「震え」→「ノイズ」として聞こえる |
| 0.5〜4秒 | 心地よい「ゆらぎ」 |
| > 10秒 | ゆっくりとした「うねり」 |

**TsukiSound推奨**: 0.5秒〜4秒のゆらぎ

### Float の微細揺れ（drift）を吸収する

計算結果が ±1サンプル揺らいでも安全なように設計します：
- softClip で振幅オーバーフローを防止
- 閾値を設けて極端な値を丸める

---

## 4. Structural Smoothness（構造レベルでの滑らかさ）

### 「いきなり変わる」構造を設計段階で排除する

以下を**途中で切り替えると必ず破綻**します：

- Layer数
- Harmonics本数
- Filter状態（On/Off）

必要なら「次の小節で切り替える」など、音楽的な境界に合わせます。

### 音量ゼロになる直前の "ポツ音" を避ける構造

TsukiSoundでは以下で解決済み：
- `fadeEnabled` フラグで再生開始時にフェードを無効化
- `playbackSessionId` で古いタスクからのvolume=0設定を無視

### フィルタ Q 値は最危険領域

- Q を急に上げると一気に発振する
- 変化時は 100〜300ms の smoothing が必須
- 極端なQ値（10以上）は避ける

---

## 5. Common Failure Patterns（よくある滑らかさの破綻）

| 破綻例 | 原因 | 対策 |
|-------|------|------|
| パチパチ音（クリック） | attack=0 / release急変 / ゼロクロス無視 | attack/release固定・ゼロクロス合わせ |
| スーッと吸い込まれすぎる | フェードが長すぎ | 3〜20msに調整 |
| ボフッというノイズ | Filter の cutoff/Q のジャンプ | 緩やかな smoothing (100-300ms) |
| 揺れが粗い/ガタガタする | LFO周期が短すぎ | 0.5秒以上に |
| メロディの尾がブツ切れ | Envelopeが短すぎ | releaseを0.1〜0.2sに |
| 複数音重なると歪む | 振幅オーバーフロー | softClipを最終出力に適用 |

---

## 6. TsukiSound Implementation（内部実装）

### SignalEnvelopeUtils

```swift
// 周波数に応じたアタック時間を自動取得
let attack = SignalEnvelopeUtils.AttackTime.recommended(for: frequency)

// 滑らかなエンベロープ（sin²アタック + 指数ディケイ + cos²リリース）
let env = SignalEnvelopeUtils.smoothEnvelope(
    t: dt,
    duration: noteDuration,
    attack: attack,
    decay: 2.0,
    releaseTime: 0.15
)

// ソフトクリッピング（振幅オーバーフロー防止）
return SignalEnvelopeUtils.softClip(output)
```

### SessionID 制御

```swift
// 古いタスクが volume を 0 に戻す破綻を防ぐ
guard fadeSessionId == self.playbackSessionId else {
    timer.invalidate()
    return
}
```

### fadeEnabled フラグ

```swift
// 再生開始時にフェードを一時無効化
public func play(preset: UISoundPreset) throws {
    fadeEnabled = false
    fadeTimer?.invalidate()
    fadeTimer = nil
    // ...
}
```

---

## 7. Quick Checklist

音源実装時のチェックリスト：

- [ ] `attack >= 0.03s`（高音）, `>= 0.06s`（中音）, `>= 0.12s`（低音）
- [ ] `release` は音楽的に自然な長さ（0.1〜0.2s程度）
- [ ] Filter の cutoff/Q は急変しない
- [ ] LFO周期は 0.5秒以上
- [ ] Harmonics本数を途中で変えない
- [ ] 最終出力に `softClip` を適用
- [ ] 複数音のミックス時はゲインを控えめに

---

## 8. Gymnopédie Implementation Example

`GymnopedieMainMelodySignal.swift` での実装例：

```swift
// 滑らかさ方針（SignalEnvelopeUtils guide準拠）:
// - 低音(200Hz以下): attack 120ms以上
// - 中音(200-500Hz): attack 60ms以上
// - 高音(500Hz以上): attack 30ms以上

let melodyAttack: Float = 0.13   // 高音メロディ用
let melodyDecay: Float = 4.0     // legato感を強化

let bassAttack: Float = 0.15     // 低音は長めに（推奨120ms+）
let bassDecay: Float = 3.5       // 床感を長く持続

let chordAttack: Float = 0.10    // 中音域も滑らかに（推奨60ms+）
let chordDecay: Float = 2.5      // 響きを長く
```

---

## 9. Related Documents

- `signal-envelope-utils-guide.md` — SignalEnvelopeUtils API詳細
- `_guide-audio-seamless-loop-generation.md` — シームレスループのゼロクロス処理
- `_guide-audio-system-impl.md` — オーディオシステム全体の実装
- `architecture/_arch-audio-parameter-safety-rules.md` — パラメータ安全ルール
- `report/report-audio-distortion-noise.md` — 歪み・雑音のRCA
- `runbook/_2025-11-29_audio_playback_volume_corruption_fix.md` — 音量破損問題の解決

---

## Revision History

| Date | Version | Change |
|------|---------|--------|
| 2025-11-30 | 1.0 | 初版作成 |
