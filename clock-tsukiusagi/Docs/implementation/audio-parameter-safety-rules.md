# Audio Parameter Safety Rules

**Version**: 1.0
**Last Updated**: 2025-11-23
**Purpose**: 音を壊さないためのパラメータ管理ルール

---

## 🚨 Critical Rule: 音源パラメータは絶対に壊してはいけない

### 基本原則

**音源の初期化パラメータは、一度決定したら絶対に変更してはいけません。**

理由:
- 純音系（LunarPulse等）は、わずかなパラメータ変更で音質が激変する
- 528Hz → 529Hz のような微細な変化でも、ユーザー体験が完全に壊れる
- lfoMinimum: 0.02 → 0.021 のような小数点の変化も同様

---

## 📋 現在の音源パラメータ一覧（厳守対象）

### LunarPulse (月の脈動)

**場所**: `clock-tsukiusagi/Core/Audio/AudioService.swift:752-758`

```swift
let pulse = LunarPulse(
    frequency: 528.0,      // ❌ 変更禁止
    amplitude: 0.2,        // ❌ 変更禁止
    lfoFrequency: 0.06,    // ❌ 変更禁止
    lfoMinimum: 0.02,      // ❌ 変更禁止
    lfoMaximum: 0.12       // ❌ 変更禁止
)
```

**音響的特徴**:
- 528Hz: ソルフェジオ周波数（healing tone）
- LFO周期: 超低速（0.06Hz = 約16.7秒周期）で呼吸を表現
- 振幅変調: 0.02〜0.12 の範囲で微細に揺らぐ

**変更してはいけない理由**:
- 周波数が1Hzでも変わると、ソルフェジオ周波数の音響効果が失われる
- LFO周期が変わると、呼吸のリズムが完全に変わる
- 振幅範囲が変わると、音の「消え方」と「立ち上がり方」が変わり、癒し効果が損なわれる

---

### TreeChime (高周波チャイム)

**場所**: `clock-tsukiusagi/Core/Audio/AudioService.swift:762-767`

```swift
let chime = TreeChime(
    grainRate: 25.0,       // ❌ 変更禁止
    grainDuration: 0.12,   // ❌ 変更禁止
    brightness: 7000.0     // ❌ 変更禁止
)
```

**音響的特徴**:
- grainRate: 25粒/秒 = 連続的だが密集しすぎない
- grainDuration: 0.12秒 = 余韻が長めで幻想的
- brightness: 7000Hz = 高周波帯域の中心

**変更してはいけない理由**:
- grainRateが変わると、「シャラララ」の密度が変わり、LunarPulseとのバランスが崩れる
- grainDurationが変わると、粒の余韻が変わり、ethereal（幽玄）な質感が失われる
- brightnessが変わると、高周波帯域が変わり、metallic shimmerの印象が完全に変わる

---

## 🛡️ 安全な拡張方法

### ✅ OK: 新しいプリセットを追加する

```swift
case .lunarPulse:
    // 既存のパラメータは一切変更しない
    let pulse = LunarPulse(
        frequency: 528.0,
        amplitude: 0.2,
        lfoFrequency: 0.06,
        lfoMinimum: 0.02,
        lfoMaximum: 0.12
    )
    engine.register(pulse)

case .newPreset:  // ✅ 新規プリセットとして追加
    let pulse = LunarPulse(
        frequency: 432.0,  // 新しい周波数
        amplitude: 0.3,    // 新しい振幅
        lfoFrequency: 0.08,
        lfoMinimum: 0.03,
        lfoMaximum: 0.15
    )
    engine.register(pulse)
```

### ✅ OK: TreeChimeのみを削除して純音版を作る

```swift
case .lunarPulsePure:  // 純音のみ
    let pulse = LunarPulse(
        frequency: 528.0,  // 同じパラメータ
        amplitude: 0.2,
        lfoFrequency: 0.06,
        lfoMinimum: 0.02,
        lfoMaximum: 0.12
    )
    engine.register(pulse)
    // TreeChimeは登録しない

case .lunarPulseChime:  // チャイム付き
    let pulse = LunarPulse(
        frequency: 528.0,  // 同じパラメータ
        amplitude: 0.2,
        lfoFrequency: 0.06,
        lfoMinimum: 0.02,
        lfoMaximum: 0.12
    )
    engine.register(pulse)

    let chime = TreeChime(
        grainRate: 25.0,   // 同じパラメータ
        grainDuration: 0.12,
        brightness: 7000.0
    )
    engine.register(chime)
```

---

## ❌ 絶対にやってはいけないこと

### ❌ NG例1: パラメータを「プリセット値」に置き換える

```swift
// ❌ これは絶対にダメ
let pulse = LunarPulse(
    frequency: NaturalSoundPresets.LunarPulse.frequency,  // ❌
    amplitude: NaturalSoundPresets.LunarPulse.amplitude,  // ❌
    lfoFrequency: NaturalSoundPresets.LunarPulse.lfoFrequency,  // ❌
    lfoMinimum: NaturalSoundPresets.LunarPulse.lfoMinimum,  // ❌
    lfoMaximum: NaturalSoundPresets.LunarPulse.lfoMaximum   // ❌
)
```

**理由**:
- NaturalSoundPresetsの値が間違っていたら、即座に音が壊れる
- プリセット値を誰かが「修正」したつもりで変更すると、音が変わる
- ハードコード値なら、誰も触れないから安全

### ❌ NG例2: 「改善」のつもりでパラメータを微調整する

```swift
// ❌ これも絶対にダメ
let pulse = LunarPulse(
    frequency: 528.0,
    amplitude: 0.21,      // ❌ 0.2 → 0.21 に「改善」
    lfoFrequency: 0.06,
    lfoMinimum: 0.02,
    lfoMaximum: 0.12
)
```

**理由**:
- 0.2 → 0.21 のような「小さな改善」でも、音の印象が大きく変わる
- ユーザーが慣れた音が変わると、信頼が失われる

### ❌ NG例3: リファクタリングで間接参照を導入する

```swift
// ❌ これも絶対にダメ
let params = getLunarPulseParams()  // ❌ 関数経由で取得
let pulse = LunarPulse(
    frequency: params.frequency,
    amplitude: params.amplitude,
    lfoFrequency: params.lfoFrequency,
    lfoMinimum: params.lfoMinimum,
    lfoMaximum: params.lfoMaximum
)
```

**理由**:
- 関数の中身が変わったら、音が変わる
- 直接ハードコードなら、誰も触れないから安全

---

## 📐 パラメータ変更が必要な場合の手順

### Step 1: 必ず新しいプリセットとして追加する

既存のプリセットを変更するのではなく、新しいプリセットを追加してください。

### Step 2: ユーザーに選択肢を与える

- 既存のプリセット: 変更しない（ユーザーが慣れた音を保つ）
- 新しいプリセット: 新しいパラメータで追加（ユーザーが試せる）

### Step 3: 音響テストを必ず実施する

- 実機で音を確認する
- 既存プリセットと新プリセットを聴き比べる
- ユーザーに聴かせて印象を確認する

---

## 🔍 音が壊れたときの復旧手順

### 1. git logで音が正しかったcommitを特定する

```bash
git log --oneline --all
```

### 2. AudioService.swiftの差分を確認する

```bash
git diff <正しいcommit> HEAD -- clock-tsukiusagi/Core/Audio/AudioService.swift
```

### 3. パラメータが変わっていたら、元に戻す

```bash
git checkout <正しいcommit> -- clock-tsukiusagi/Core/Audio/AudioService.swift
```

### 4. ビルドして音を確認する

```bash
xcodebuild -project clock-tsukiusagi.xcodeproj -scheme clock-tsukiusagi -destination 'platform=iOS Simulator,name=iPhone 16' build
```

---

## 📚 参考: なぜLunarPulseとTreeChimeはハードコードなのか

### NaturalSoundPresetsを使っている音源との違い

**NaturalSoundPresetsを使う音源（例: MoonlitSea, DarkShark）**:
- ノイズ系（環境音）
- パラメータが多い（10個以上）
- 微調整の影響が比較的小さい
- プリセット値を一元管理した方が保守性が高い

**ハードコード音源（例: LunarPulse, TreeChime）**:
- 純音・楽器系
- パラメータが少ない（5個前後）
- 微調整の影響が極めて大きい
- **音の同一性がアプリの価値の中核**

### 結論

**LunarPulseとTreeChimeは、AudioService.swiftに直接ハードコードするのが正解です。**

---

## 🚀 将来の拡張: PureToneModule分離案

ふじこちゃんの提案通り、純音系を独立モジュール化することを検討してください。

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

- [ ] 既存の音源パラメータは一切変更していないか？
- [ ] 新しいプリセットとして追加しているか？
- [ ] ハードコード値を使っているか？（純音系の場合）
- [ ] 実機で音を確認したか？
- [ ] git commitする前に、音が壊れていないか確認したか？

---

**🌙 Remember: 音は一度壊れると、ユーザーの信頼も壊れます。慎重に。**
