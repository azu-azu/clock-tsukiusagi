# Audio Source Architecture Rules

**Version**: 2.0
**Last Updated**: 2025-11-23
**Purpose**: 音源の3層アーキテクチャと責務分離ルール

---

## 🎧 目的

このアプリの音源システムは**3層アーキテクチャ**で構成される：

1. **UISoundPreset（UI層）** - 画面表示専用
2. **NaturalSoundPreset（技術層）** - 自然音パラメータ
3. **PureTonePreset（技術層）** - 純音パラメータ

この3層を明確に分離することで、UI変更が技術実装に影響せず、技術層は音響品質のみに集中できる。

---

## 🎨 1. UISoundPreset（UI層）

### 役割

**画面に表示する音源の選択肢を管理する**（技術実装とは無関係）

### 配置

```
Core/Audio/Presets/UISoundPreset.swift
```

### 特徴

* すべての音源（PureTone + NaturalSound）を統一管理
* 表示名（日本語・英語）
* 絵文字
* 表示順序
* テスト音源フラグ

### 実装例

```swift
public enum UISoundPreset: String, CaseIterable, Identifiable {
    case oceanWavesSeagulls
    case moonlitSea
    case lunarPulse  // PureToneだがUI上は他と並列
    case darkShark
    // ...

    public var displayName: String { ... }
    public var englishTitle: String { ... }
}
```

### ルール

* ✅ 表示名・絵文字の変更は自由
* ✅ 順序変更も自由
* ✅ 新しい音源を追加する際は必ずここに追加
* ❌ 技術パラメータを持ってはいけない

---

## 🌙 2. PureTonePreset（技術層）

### 役割

**純音・楽器系の音源パラメータを管理する**

### 配置

```
Core/Audio/PureTone/
    PureTonePreset.swift     # プリセット定義
    PureToneParams.swift     # パラメータ構造体
    PureToneBuilder.swift    # ビルダー
    LunarPulse.swift         # 音源実装
    TreeChime.swift          # 音源実装
```

### 代表例

* LunarPulse（528Hz Sine）
* TreeChime（高周波粒状合成）
* Harmonic系（将来）
* Binaural系（将来）

### 特徴

* 基本は **正弦波 / 矩形波 / 粒状合成の楽器系**
* パラメータは少数（3〜6個程度）
* **1個の数値が音質を大きく変える**
* 音の"キャラクター性"が強い
* ユーザーが「その音そのもの」を期待する

### ルール

* ✅ 値を変えるのはOK（ただし「別プリセット」として追加）
* ✅ バージョン制推奨（v1, v2, v3...）
* ❌ 既存プリセットの値を書き換えてはいけない
* ❌ NaturalSoundPresetsに入れてはいけない

### 実装例

```swift
public enum PureTonePreset {
    case lunarPulse
    case lunarPulseChime

    public var params: PureToneParams { ... }
    public var includesChime: Bool { ... }
}
```

---

## 🍃 3. NaturalSoundPreset（技術層）

### 役割

**自然音・環境音系の音源パラメータを管理する**

### 配置

```
Core/Audio/Presets/NaturalSoundPresets.swift
Core/Audio/Signal/SignalPresetBuilder.swift
Core/Audio/Signal/Presets/*.swift
```

### 代表例

* MoonlitSea（深夜の海）
* DarkShark（黒いサメの影）
* LunarTide（月光の潮流）
* AbyssalBreath（深海の呼吸）
* その他の環境ノイズ源

### 特徴

* ノイズベース + LFO + フィルタ + グレイン…など **多変数**
* 少し数値が変わっても破綻しない
* ユーザーは「雰囲気」を重視する（0.02 → 0.03 の差で壊れたりはしない）
* SignalEngine の効果（リバーブ・ローパス）が前提

### ルール

* ✅ Builder（SignalPresetBuilder）経由で生成する
* ✅ 音を改良するために値を調整してもOK
* ✅ パラメータ調整による改善も可能
* ❌ PureToneを入れてはいけない

---

## 🔁 4. 3層の接続フロー

### AudioServiceでのマッピング

```swift
// UISoundPreset → 技術プリセットへの自動マッピング

private func registerSource(for uiPreset: UISoundPreset) throws {
    // PureToneか？
    if let pureTonePreset = mapToPureTone(uiPreset) {
        let sources = PureToneBuilder.build(pureTonePreset)
        sources.forEach { engine.register($0) }
        return
    }

    // NaturalSoundか？
    guard let naturalPreset = mapToNaturalSound(uiPreset) else {
        return
    }

    // SignalEngine経由で生成
    let mixerOutput = signalBuilder.makeMixerOutput(for: naturalPreset)
    engine.register(mixerOutput)
}
```

### マッピングメソッド

```swift
private func mapToPureTone(_ uiPreset: UISoundPreset) -> PureTonePreset? {
    switch uiPreset {
    case .lunarPulse:
        return .lunarPulseChime
    default:
        return nil
    }
}

private func mapToNaturalSound(_ uiPreset: UISoundPreset) -> NaturalSoundPreset? {
    switch uiPreset {
    case .moonlitSea:
        return .moonlitSea
    case .darkShark:
        return .darkShark
    // ...
    case .lunarPulse:
        return nil  // PureToneが処理
    }
}
```

---

## 📊 5. 3層の比較表

| 要素 | UISoundPreset | NaturalSoundPreset | PureTonePreset |
|------|---------------|-------------------|---------------|
| 役割 | UI表示 | 自然音パラメータ | 純音パラメータ |
| 波形 | - | ノイズベース | 正弦波・調和波 |
| パラメータ数 | 0 | 多い（幅広い） | 少ない（繊細） |
| 変更の影響 | UI のみ | 音の雰囲気 | 音の本質 |
| 変更の自由度 | 高い | 中程度 | 低い（別プリセット推奨） |
| 配置 | UI層 | 技術層 | 技術層 |

---

## 💡 6. パラメータの扱いに関する本質的なルール

### **既存プリセットの"音そのもの"を変えない（新プリセットを作る）**

* ❌ **"パラメータ変更禁止"** ではない
* ⭕ **"ユーザーが選んだ音を勝手に書き換えない"**

### 実装例

#### ✅ 正しいやり方：新プリセットとして追加

```swift
// PureTonePreset.swift
public enum PureTonePreset {
    case lunarPulse
    case lunarPulse_v2  // ✅ 新バージョンとして追加

    public var params: PureToneParams {
        switch self {
        case .lunarPulse:
            // 既存の音をそのまま維持
            return PureToneParams(
                frequency: 528.0,
                amplitude: 0.2,
                lfoFrequency: 0.06,
                lfoMinimum: 0.02,
                lfoMaximum: 0.12
            )
        case .lunarPulse_v2:
            // 改良版
            return PureToneParams(
                frequency: 528.0,
                amplitude: 0.25,   // 改良版
                lfoFrequency: 0.08,
                lfoMinimum: 0.03,
                lfoMaximum: 0.15
            )
        }
    }
}
```

#### ✅ 正しいやり方：バリエーション分離

```swift
// PureTonePreset.swift
public enum PureTonePreset {
    case lunarPulse         // 純音のみ
    case lunarPulseChime    // チャイム付き

    public var includesChime: Bool {
        switch self {
        case .lunarPulseChime: return true
        case .lunarPulse: return false
        }
    }
}

// PureToneBuilder.swift
public static func build(_ preset: PureTonePreset) -> [AudioSource] {
    var sources: [AudioSource] = []

    let pulse = LunarPulse(...)
    sources.append(pulse)

    if preset.includesChime {
        let chime = TreeChime(...)
        sources.append(chime)
    }

    return sources
}
```

#### ❌ 間違ったやり方：既存音源のパラメータを書き換え

```swift
// PureTonePreset.swift
public enum PureTonePreset {
    case lunarPulse

    public var params: PureToneParams {
        switch self {
        case .lunarPulse:
            return PureToneParams(
                frequency: 528.0,
                amplitude: 0.21,   // ❌ 0.2 → 0.21 に変更（音が変わる）
                lfoFrequency: 0.06,
                lfoMinimum: 0.02,
                lfoMaximum: 0.12
            )
        }
    }
}
```

### なぜ書き換えてはいけないのか

1. **ユーザーの期待を裏切る**: 「この音が好きで選んだ」という選択を無効にする
2. **信頼を失う**: アプリのアップデート後に「音が変わった」と感じさせる
3. **後戻りできない**: 一度リリースした音は、ユーザーの記憶に刻まれている

---

## 🔍 7. 現在のPureTone音源パラメータ（参考）

### LunarPulse (月の脈動)

**場所**: `Core/Audio/PureTone/PureTonePreset.swift` (case .lunarPulse)

```swift
// PureTonePreset.swift
public var params: PureToneParams {
    switch self {
    case .lunarPulse, .lunarPulseChime:
        return PureToneParams(
            frequency: 528.0,      // ソルフェジオ周波数
            amplitude: 0.2,        // 基本音量
            lfoFrequency: 0.06,    // 超低速LFO（約16.7秒周期）
            lfoMinimum: 0.02,      // 振幅変調の最小値
            lfoMaximum: 0.12       // 振幅変調の最大値
        )
    }
}
```

### TreeChime (高周波チャイム)

**場所**: `Core/Audio/PureTone/PureToneBuilder.swift`

```swift
// PureToneBuilder.swift (lunarPulseChimeの場合のみ追加)
if preset.includesChime {
    let chime = TreeChime(
        grainRate: 25.0,       // 25粒/秒（連続的だが密集しすぎない）
        grainDuration: 0.12,   // 余韻長め（幻想的な質感）
        brightness: 7000.0     // 高周波帯域の中心
    )
    sources.append(chime)
}
```

---

## 📐 8. 音源を追加する際のガイドライン

### PureTone系を追加する場合

1. **UISoundPreset.swiftに新しいcaseを追加**（UI層）
   ```swift
   public enum UISoundPreset: String, CaseIterable, Identifiable {
       case harmonicTone  // ✅ 新しい音源
       // ...
   }
   ```

2. **PureTonePreset.swiftに新しいcaseを追加**（技術層）
   ```swift
   public enum PureTonePreset {
       case harmonicTone  // ✅ 新しいプリセット

       public var params: PureToneParams { ... }
   }
   ```

3. **AudioService.swiftでマッピングを追加**
   ```swift
   private func mapToPureTone(_ uiPreset: UISoundPreset) -> PureTonePreset? {
       switch uiPreset {
       case .harmonicTone: return .harmonicTone  // ✅ マッピング追加
       // ...
       }
   }
   ```

4. **既存音源のパラメータは変更しない**
5. **実機で音を確認する**

### NaturalSound系を追加する場合

1. **UISoundPreset.swiftに新しいcaseを追加**（UI層）
   ```swift
   public enum UISoundPreset: String, CaseIterable, Identifiable {
       case forestRain  // ✅ 新しい音源
       // ...
   }
   ```

2. **NaturalSoundPreset.swiftに新しいcaseを追加**（技術層）
   ```swift
   public enum NaturalSoundPreset: String, CaseIterable, Identifiable {
       case forestRain  // ✅ 新しいプリセット
       // ...
   }
   ```

3. **NaturalSoundPresets.swiftに構造体を追加**
   ```swift
   public struct ForestRain {
       public static let noiseAmplitude: Float = 0.3
       // ...
   }
   ```

4. **SignalPresetBuilder.swiftにビルダーを実装**
   ```swift
   private func createRawSignal(for preset: NaturalSoundPreset) -> Signal? {
       switch preset {
       case .forestRain: return ForestRainSignal.makeSignal()
       // ...
       }
   }
   ```

5. **AudioService.swiftでマッピングを追加**
   ```swift
   private func mapToNaturalSound(_ uiPreset: UISoundPreset) -> NaturalSoundPreset? {
       switch uiPreset {
       case .forestRain: return .forestRain  // ✅ マッピング追加
       // ...
       }
   }
   ```

6. **パラメータ調整は自由に行ってOK**

---

## 🚀 9. PureToneModule分離（実装済み）

**ステータス**: ✅ **完了** (2025-11-23)

純音系が増えてきたため、独立モジュール化を実施しました。

### 実装済みの構造

```
Core/Audio/PureTone/
    PureTonePreset.swift       # 純音系プリセット定義
    PureToneParams.swift       # パラメータ構造体
    PureToneBuilder.swift      # ビルダー
    LunarPulse.swift           # 音源実装
    TreeChime.swift            # 音源実装
```

### 実現されたメリット

1. **音響的な分離**: 環境音と純音を明確に分離
2. **パラメータ管理の精度**: 純音専用の構造で管理
3. **拡張性**: 新しい純音系プリセットを追加しやすい
4. **事故防止**: NaturalSoundPresetsと混ざらない
5. **3層アーキテクチャ**: UI層と技術層の完全な責務分離

---

## ✅ 10. チェックリスト

音源を追加・変更する前に、以下を確認してください:

- [ ] UI層と技術層を混同していないか？
  - [ ] UISoundPresetは表示のみ（技術パラメータなし）
  - [ ] PureTonePreset / NaturalSoundPresetは技術のみ（表示名なし）
- [ ] これはPureTone系かNaturalSound系か判断したか？
- [ ] マッピングメソッド（mapToPureTone / mapToNaturalSound）を追加したか？
- [ ] 既存プリセットの音は変更していないか？
- [ ] 新しい音は新しいプリセットとして追加しているか？
- [ ] 実機で音を確認したか？

---

**🌙 音はユーザー体験の核心。新しい音は追加できるが、既存の音は守る。**
