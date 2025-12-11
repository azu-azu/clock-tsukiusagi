# 音量制御ガイド

## 概要

TsukiSoundの音量制御は、音質を保ちながら適切な音量を維持するために階層的に設計されています。このドキュメントでは、正しい音量調整方法と、絶対に避けるべきアンチパターンを説明します。

---

## 音量制御の階層構造

```
Signal (個別音源)
    ↓ 個別ゲイン
FinalMixer (ミキサー)
    ↓ masterGain
Effects (リバーブ等)
    ↓
FinalMixerOutputNode
    ↓
SafeVolumeLimiter
    ↓
mainMixerNode (volumeCapLinear による制御)
    ↓
outputNode → スピーカー/イヤホン
```

---

## 全体音量を調整する正しい方法

### 推奨: volumeCapLinear を変更する

**場所**: `TsukiSound/Core/Audio/Service/AudioService.swift`

```swift
private let volumeCapLinear: Float = 0.75  // -2.5dB
```

**メリット**:
- 1箇所の変更で全プリセットに適用
- 音のバランスを保持
- 新規プリセット追加時も自動適用
- エフェクト処理後の最終段で調整

**値の目安**:
| 値 | dB | 説明 |
|---|---|---|
| 0.50 | -6dB | 控えめ（元の設定） |
| 0.75 | -2.5dB | 標準（現在の設定） |
| 1.0 | 0dB | 最大（制限なし） |

---

## 絶対にやってはいけないこと

### NG: 個別SignalのゲインをUIの音量として使う

```swift
// ❌ 絶対にダメ
let melodyGain: Float = 0.75  // 元: 0.28
let bassGain: Float = 0.35    // 元: 0.12
let chordGain: Float = 0.25   // 元: 0.08
```

**なぜダメなのか**:

1. **クリッピング/歪み**: 複数の音が重なると信号が1.0を超え、歪みが発生
2. **バランス崩壊**: 慎重に調整された音色バランスが崩れる
3. **リバーブ飽和**: 入力が大きすぎるとリバーブが不自然になる
4. **保守性の悪化**: 11ファイル以上を一括変更する必要がある

### NG: 各プリセットで同じmasterGainを設定する

```swift
// ❌ 冗長でDRY原則に反する
case .jupiterRemastered:
    mixer.masterGain = 1.5  // 全プリセットに同じ値をコピペ
case .moonlitGymnopedie:
    mixer.masterGain = 1.5  // 同じ値を繰り返し
case .acousticGymnopedie:
    mixer.masterGain = 1.5  // 新規追加時に忘れるリスク
```

**なぜダメなのか**:
- 同じ値を複数箇所にコピペしている
- 変更時に全箇所を修正する必要がある
- 新規プリセット追加時に設定を忘れるリスク

---

## 各層の役割と適切な使い方

### Signal内のゲイン（音色設計用）

**用途**: 音色のバランス調整（絶対に音量調整には使わない）

```swift
// ✅ 音色バランスのための設定（変更しない）
let melodyGain: Float = 0.28   // メロディの存在感
let bassGain: Float = 0.12     // ベースの支え
let chordGain: Float = 0.08    // 和音の厚み
```

これらの値は**音色設計の一部**であり、音量調整には使いません。

### FinalMixer.masterGain（プリセット別調整用）

**用途**: 特定のプリセットだけ音量を変えたい場合のみ

```swift
// ✅ 特定プリセットだけ音量を下げたい場合
mixer.masterGain = 0.8  // このプリセットだけ少し控えめに
```

全プリセット共通の音量調整には使いません。

### volumeCapLinear（全体音量調整用）

**用途**: アプリ全体の音量レベル調整

```swift
// ✅ 全体音量を調整する正しい方法
private let volumeCapLinear: Float = 0.75
```

---

## 音量調整のフローチャート

```
「音量を上げたい」
    │
    ├─ 全プリセット共通？
    │   │
    │   └─ YES → volumeCapLinear を上げる ✅
    │
    └─ 特定プリセットだけ？
        │
        └─ YES → FinalMixer.masterGain を調整 ✅


「特定の音が聞こえにくい」
    │
    ├─ メロディ vs 伴奏のバランス？
    │   │
    │   └─ YES → Signal内のゲイン比率を調整 ✅
    │           （例: melody 0.28, bass 0.12 の比率）
    │
    └─ 全体的に小さい？
        │
        └─ YES → volumeCapLinear を上げる ✅
```

---

## 過去の失敗例（2025-11-27）

### 何が起きたか

「音量が小さい」という要望に対し、個別Signalのゲインを約2〜3倍に上げた。

### 結果

- 高音が変に響く（クリッピング）
- 音のバランスが崩壊
- リバーブが飽和して不自然な響き
- 停止/再生時に音崩れ

### 解決方法

全ての変更を元に戻し、`volumeCapLinear` を 0.50 → 0.75 に変更（1箇所のみ）。

---

## まとめ

| やりたいこと | 正しい方法 | ダメな方法 |
|---|---|---|
| 全体音量を上げる | volumeCapLinear | 個別Signalのゲイン |
| 特定プリセットの音量 | FinalMixer.masterGain | 個別Signalのゲイン |
| 音色バランス調整 | Signal内のゲイン比率 | - |

**原則**: 音量調整は下流（出力に近い側）で行う。上流（音源側）のゲインは音色設計専用。
