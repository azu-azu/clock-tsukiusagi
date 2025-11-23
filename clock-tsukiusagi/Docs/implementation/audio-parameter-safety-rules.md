# Audio Source Architecture Rules

**Version**: 1.0
**Last Updated**: 2025-11-23
**Purpose**: 音源の性質別分類と配置ルール

---

## 🎧 目的

音源は大きく2種類に分かれる：

1. **PureTone（純音系・楽器系）**
2. **NaturalSound（環境音・ノイズ系）**

この2つは性質も設計方針も異なるため、**混ざると事故の元**になる。
ここでは、両者の違いと配置ルールを明確にする。

---

## 🌙 1. PureTone（純音）系

### 代表例

* LunarPulse（528Hz Sine）
* Harmonic系
* Binaural系
* TreeChime（純音寄り）

### 特徴

* 基本は **正弦波 / 矩形波 / 粒状合成の楽器系**
* パラメータは少数（3〜6個程度）
* **1個の数値が音質を大きく変える**
* 音の"キャラクター性"が強い
* ユーザーが「その音そのもの」を期待する

### 設計ルール

* NaturalSoundPresets に入れてはいけない
* **専用モジュールに分離する**（将来）
* 値を変えるのはOK（ただし「別プリセット」として追加）
* 既存音源の値を変えるとユーザーの印象が変わるため **バージョン制（v1 / v2）が有効**

### 配置（将来の理想形）

```
Core/Audio/PureTone/
    PureTonePreset.swift
    PureToneParams.swift
    LunarPulse.swift
    TreeChime.swift
    PureToneBuilder.swift
```

### 現在の配置（暫定）

* 音源実装: `Core/Audio/Sources/LunarPulse.swift`, `Core/Audio/Sources/TreeChime.swift`
* プリセット登録: `Core/Audio/AudioService.swift` 内でハードコード
* enum定義: `NaturalSoundPresets.swift` に暫定的に配置（将来分離予定）

---

## 🍃 2. NaturalSound（自然音）系

### 代表例

* MoonlitSea
* DarkShark
* LunarTide
* DustStorm
* AbyssalBreath
* その他の環境ノイズ源

### 特徴

* ノイズベース + LFO + フィルタ + グレイン…など **多変数**
* 少し数値が変わっても破綻しない
* ユーザーは「雰囲気」を重視する（0.02 → 0.03 の差で壊れたりはしない）
* SignalEngine の効果（リバーブ・ローパス）が前提

### 設計ルール

* すべて NaturalSoundPresets で一元管理
* Builder（SignalPresetBuilder）経由で生成する
* 音を改良するために値を調整しても問題ない
* PureTone の領域に踏み込まないこと

### 配置

```
Core/Audio/Presets/NaturalSoundPresets.swift
Core/Audio/Signal/SignalPresetBuilder.swift
Core/Audio/Signal/Presets/*.swift
```

---

## 🌗 3. PureTone と NaturalSound の境界線

| 要素 | PureTone | NaturalSound |
|------|----------|--------------|
| 波形 | 正弦波・調和波 | ノイズベース |
| パラメータ数 | 少ない（繊細） | 多い（幅広い） |
| 音の壊れやすさ | 壊れやすい | 比較的壊れにくい |
| 傾向 | 楽器・癒し音 | 環境音・雰囲気 |
| 配置場所 | PureToneModule（将来） | NaturalSoundPresets |
| パラメータ管理 | ハードコード推奨 | プリセット構造体 |

---

## 🌟 4. 将来の追加ルール

### PureTone はバージョン制推奨

例：

* LunarPulse_v1（現行）
* LunarPulse_v2（新しい呼吸パターン）
* LunarPulse_Chime（TreeChime入り）

### NaturalSound は自由に拡張OK

音の性質が崩れにくいため、パラメータ調整による改善も可能

### Hybrid（純音＋自然音）は PureTone 側で扱う

調和性が必要なので PureTone の管理に近い

---

## 💡 5. パラメータの扱いに関する本質的なルール

### **既存プリセットの"音そのもの"を変えない（新プリセットを作る）**

* ❌ **"パラメータ変更禁止"** ではない
* ⭕ **"ユーザーが選んだ音を勝手に書き換えない"**

### 実装例

#### ✅ 正しいやり方：新プリセットとして追加

```swift
case .lunarPulse:
    // 既存の音をそのまま維持
    let pulse = LunarPulse(
        frequency: 528.0,
        amplitude: 0.2,
        lfoFrequency: 0.06,
        lfoMinimum: 0.02,
        lfoMaximum: 0.12
    )
    engine.register(pulse)

case .lunarPulse_v2:  // ✅ 新バージョンとして追加
    let pulse = LunarPulse(
        frequency: 528.0,
        amplitude: 0.25,   // 改良版
        lfoFrequency: 0.08,
        lfoMinimum: 0.03,
        lfoMaximum: 0.15
    )
    engine.register(pulse)
```

#### ✅ 正しいやり方：バリエーション分離

```swift
case .lunarPulse:  // 純音のみ
    let pulse = LunarPulse(...)
    engine.register(pulse)

case .lunarPulseChime:  // チャイム付き
    let pulse = LunarPulse(...)
    engine.register(pulse)

    let chime = TreeChime(...)
    engine.register(chime)
```

#### ❌ 間違ったやり方：既存音源を書き換え

```swift
case .lunarPulse:
    let pulse = LunarPulse(
        frequency: 528.0,
        amplitude: 0.21,   // ❌ 0.2 → 0.21 に変更（音が変わる）
        lfoFrequency: 0.06,
        lfoMinimum: 0.02,
        lfoMaximum: 0.12
    )
    engine.register(pulse)
```

### なぜ書き換えてはいけないのか

1. **ユーザーの期待を裏切る**: 「この音が好きで選んだ」という選択を無効にする
2. **信頼を失う**: アプリのアップデート後に「音が変わった」と感じさせる
3. **後戻りできない**: 一度リリースした音は、ユーザーの記憶に刻まれている

---

## 🔍 現在のPureTone音源パラメータ（参考）

### LunarPulse (月の脈動)

**場所**: `Core/Audio/AudioService.swift` (case .lunarPulse)

```swift
let pulse = LunarPulse(
    frequency: 528.0,      // ソルフェジオ周波数
    amplitude: 0.2,        // 基本音量
    lfoFrequency: 0.06,    // 超低速LFO（約16.7秒周期）
    lfoMinimum: 0.02,      // 振幅変調の最小値
    lfoMaximum: 0.12       // 振幅変調の最大値
)
```

### TreeChime (高周波チャイム)

**場所**: `Core/Audio/AudioService.swift` (case .lunarPulse)

```swift
let chime = TreeChime(
    grainRate: 25.0,       // 25粒/秒（連続的だが密集しすぎない）
    grainDuration: 0.12,   // 余韻長め（幻想的な質感）
    brightness: 7000.0     // 高周波帯域の中心
)
```

---

## 📐 音源を追加する際のガイドライン

### PureTone系を追加する場合

1. **新しいenum caseを追加**（例: `.lunarPulse_v2`, `.harmonicTone`）
2. **AudioService.swiftにハードコードで実装**
3. **既存音源のパラメータは変更しない**
4. **実機で音を確認する**

### NaturalSound系を追加する場合

1. **NaturalSoundPresets.swiftに構造体を追加**
2. **SignalPresetBuilder.swiftにビルダーを実装**
3. **パラメータ調整は自由に行ってOK**

---

## 🚀 将来の理想形: PureToneModule分離

純音系が増えてきたら、独立モジュール化を検討してください。

### 理想的な構造

```
Core/Audio/PureTone/
    PureTonePreset.swift       # 純音系プリセット定義
    PureToneParams.swift       # パラメータ構造体
    PureToneBuilder.swift      # ビルダー
    LunarPulse.swift           # 音源実装
    TreeChime.swift            # 音源実装
```

### メリット

1. **音響的な分離**: 環境音と純音を明確に分ける
2. **パラメータ管理の精度**: 純音専用の構造で管理
3. **拡張性**: 新しい純音系プリセットを追加しやすい
4. **事故防止**: NaturalSoundPresetsと混ざらない

---

## ✅ チェックリスト

音源を追加・変更する前に、以下を確認してください:

- [ ] これはPureTone系かNaturalSound系か判断したか？
- [ ] 既存プリセットの音は変更していないか？
- [ ] 新しい音は新しいプリセットとして追加しているか？
- [ ] 実機で音を確認したか？

---

**🌙 音はユーザー体験の核心。新しい音は追加できるが、既存の音は守る。**
