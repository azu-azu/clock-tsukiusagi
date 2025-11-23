# 自然音プリセット復活実装ガイド

> **⚠️ 注意**: このドキュメントは2025-11-14時点の実装を記録したものです。
>
> **2025-11-23更新**: 音源アーキテクチャが3層構造に変更されました:
> - **UISoundPreset** (UI層): 表示専用
> - **NaturalSoundPreset** (技術層): 自然音パラメータ
> - **PureTonePreset** (技術層): 純音パラメータ
>
> このドキュメント内の `NaturalSoundPreset` への直接参照は、現在は `UISoundPreset` → マッピング → `NaturalSoundPreset/PureTonePreset` の流れに変更されています。
>
> 最新の実装については [`audio-parameter-safety-rules.md`](./audio-parameter-safety-rules.md) を参照してください。

## 概要

欠落していた4つの自然音プリセット（癒しチャイム、チベタンボウル、波の音、焚き火の音）をgit履歴から復活させ、統合した実装記録。

**実施日**: 2025-11-14
**対象バージョン**: commit e51bc1a以降
**関連Issue**: 音源停止問題、全プリセット同一音問題

---

## 実装概要

### 復活した音源

1. **WindChime (癒しチャイム)**
   - ファイル: `clock-tsukiusagi/Core/Audio/Sources/WindChime.swift`
   - 特徴: ペンタトニックスケール、ランダムトリガー、ADSR エンベロープ

2. **TibetanBowl (チベタンボウル)**
   - ファイル: `clock-tsukiusagi/Core/Audio/Sources/TibetanBowl.swift`
   - 特徴: 倍音合成、ビブラート変調、5倍音構造

3. **OceanWaves (波の音)**
   - ファイル: `clock-tsukiusagi/Core/Audio/Sources/OceanWaves.swift`
   - 特徴: ホワイトノイズ、LFO音量変調、5秒周期の波

4. **CracklingFire (焚き火の音)**
   - ファイル: `clock-tsukiusagi/Core/Audio/Sources/CracklingFire.swift`
   - 特徴: ピンクノイズベース、ランダムパルス、指数減衰エンベロープ

---

## 発見された問題と解決策

### 問題0: 音源復活時の初期エラー（型の曖昧性）

**発生タイミング**: git履歴から音源を復活させた直後

**症状**:
- `NoiseType is ambiguous` エラー
- `ChordType is ambiguous` エラー
- `AudioFilePresets` の switch が非exhaustive エラー

**原因**:
復活させた音源ファイルが、古いモジュール構造を参照していた。具体的には:

1. **NoiseType の曖昧性**
   - 古い実装: `NoiseSource.NoiseType` と `NoiseGenerator.NoiseType` が両方存在
   - 新しい実装: `NoiseGenerator.NoiseType` に統一されている
   - 復活した音源が古い参照を使用していた

2. **ChordType の曖昧性**
   - 古い実装: `ChordGenerator.ChordType` が存在
   - 新しい実装: 別の場所に移動または統一されている

3. **switch の非exhaustive**
   - 新しいプリセットケースを追加したが、`AudioFilePresets` の switch に追加し忘れ

**解決策**:

#### 1. NoiseType の統一

```swift
// ❌ 復活直後の古いコード
let noiseGen = NoiseSource(type: .pink)  // NoiseSource.NoiseType

// ✅ 修正後
let noiseGen = NoiseGenerator(type: .pink)  // NoiseGenerator.NoiseType
```

**影響を受けたファイル**:
- `AmbientDrone.swift`
- `OceanWaves.swift`
- `CracklingFire.swift`

#### 2. ChordType の参照修正

```swift
// ❌ 復活直後の古いコード
let chord = ChordGenerator.ChordType.sus4

// ✅ 修正後（現在のモジュール構造に合わせる）
let chordType: ChordType = .sus4
```

#### 3. AudioFilePresets の switch を exhaustive に

すべての新規プリセットケースを追加:

```swift
extension NaturalSoundPreset {
    public var audioFilePreset: AudioFilePreset? {
        switch self {
        // ... 既存のケース
        case .pleasantWarm:
            return nil  // Uses synthesis
        case .pleasantCalm:
            return nil  // Uses synthesis
        case .pleasantDeep:
            return nil  // Uses synthesis
        case .ambientFocus:
            return nil  // Uses synthesis
        case .ambientRelax:
            return nil  // Uses synthesis
        case .ambientSleep:
            return nil  // Uses synthesis
        case .windChime:
            return nil  // Uses synthesis
        case .tibetanBowl:
            return nil  // Uses synthesis
        case .oceanWaves:
            return nil  // Uses synthesis
        case .cracklingFire:
            return nil  // Uses synthesis
        }
    }
}
```

**重要な教訓**:
- git履歴から古いコードを復活させる際は、**必ず現在のモジュール構造に合わせる**こと
- 型の参照が曖昧な場合は、完全修飾名（`ModuleName.TypeName`）で確認する
- 新しいenumケースを追加したら、**すべてのswitch文を確認**すること

---

### 問題1: 停止ボタンが効かない（ゴーストタスク問題）

**症状**:
- 停止ボタンを押しても音が鳴り続ける
- `AVAudioSourceNode` の render callback が止まらない

**原因**:
- 合成音源（PinkNoise, BrownNoise, PleasantDrone等）に `suspend()/resume()` の実装が不足
- `stop()` メソッドが空実装のため、render callback が動作し続ける

**解決策**:
すべての合成音源に以下のパターンを実装:

```swift
// Helper class for shared mutable state in closures
private final class AudioState {
    var isSuspended = false
}

public final class SomeAudioSource: AudioSource {
    private let audioState = AudioState()

    public func suspend() {
        audioState.isSuspended = true
        print("🎵 [SomeAudioSource] Suspended (output silence)")
    }

    public func resume() {
        audioState.isSuspended = false
        print("🎵 [SomeAudioSource] Resumed (output active)")
    }

    // render callback 内
    _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
        // If suspended, output silence
        if state.isSuspended {
            for buffer in abl {
                guard let data = buffer.mData else { continue }
                let samples = data.assumingMemoryBound(to: Float.self)
                for frame in 0..<Int(frameCount) {
                    samples[frame] = 0.0
                }
            }
            return noErr
        }
        // ... 通常の処理
    }
}
```

**適用した音源**:
- PinkNoise
- BrownNoise
- PleasantDrone
- AmbientDrone
- DetunedOscillator
- WindChime (新規)
- TibetanBowl (新規)
- OceanWaves (新規)
- CracklingFire (新規)

---

### 問題2: 全プリセットが同じ音になる

**症状**:
- どのプリセットを選択しても同じ音が再生される
- 複数の音源が同時に鳴っている

**原因**:
- `LocalAudioEngine` に音源をクリアする機能がなかった
- プリセット切り替え時に古い音源が残り続け、新しい音源と同時再生されていた

**解決策**:

#### 1. LocalAudioEngine に clearSources() メソッドを追加

```swift
// clock-tsukiusagi/Core/Audio/Engine/LocalAudioEngine.swift

/// すべての音源をクリア（デタッチして削除）
public func clearSources() {
    print("LocalAudioEngine: Clearing all sources (count: \(sources.count))")

    // Stop and detach all sources
    sources.forEach {
        $0.stop()
        $0.suspend()
        // Detach the source node from engine
        engine.detach($0.sourceNode)
    }

    // Clear the sources array
    sources.removeAll()

    print("LocalAudioEngine: All sources cleared")
}
```

#### 2. AudioService.play() で音源切り替え前にクリア

```swift
// clock-tsukiusagi/Core/Audio/AudioService.swift

public func play(_ preset: NaturalSoundPreset) async {
    // CRITICAL: Clear all previous sources before registering new one
    // This prevents multiple sources from playing simultaneously
    engine.clearSources()
    print("🎵 [AudioService] Cleared previous sources")

    // Register new source
    registerSource(for: preset)

    // ... 続きの処理
}
```

**重要**: この修正により、プリセット切り替え時に必ず古い音源がクリアされ、新しい音源だけが再生されるようになった。

---

### 問題3: PleasantDrone の設定が間違っていた

**症状**:
- PleasantDrone の音色が以前と異なる

**原因**:
- 設定値が間違ってコピーされていた
  - 誤: `rootFrequency: 174.0 (F3)`, `chordType: .major`
  - 正: `rootFrequency: 196.0 (G3)`, `chordType: .sus4`

**解決策**:

```swift
// clock-tsukiusagi/Core/Audio/Presets/NaturalSoundPresets.swift

public struct PleasantDrone {
    public static let rootFrequency: Double = 196.0  // G3 (was 174.0 F3)
    public static let chordType: ChordType = .sus4  // (was .major)
    public static let amplitude: Double = 0.22  // (was 0.25)

    // ... 他の設定
}
```

---

## 実装手順

### 前提条件

**⚠️ 重要**: git履歴から古いコードを復活させる場合、以下の点に注意:

1. **モジュール構造の変更を確認する**
   - 型の参照が変わっている可能性がある（例: `NoiseSource.NoiseType` → `NoiseGenerator.NoiseType`）
   - 古い型参照は曖昧性エラーの原因になる

2. **依存関係を確認する**
   - 復活させた音源が依存する補助クラスもすべて復活させる
   - 欠けている依存があると、コンパイルエラーになる

3. **enum の変更を追跡する**
   - 新しいケースを追加したら、すべての switch 文を exhaustive にする
   - Xcode のコンパイルエラーで見つからない場合もあるので、手動で確認する

---

### 1. git 履歴から音源を復活

```bash
# 古いコミットから該当ファイルを確認
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Sources/WindChime.swift
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Sources/TibetanBowl.swift
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Sources/OceanWaves.swift
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Sources/CracklingFire.swift
```

**⚠️ 注意**: 復活させたコードを**そのままコピーしない**こと。現在のモジュール構造に合わせて修正が必要。

### 2. 依存する補助クラスも復活

```bash
# 変調コンポーネント
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Modulation/EnvelopeGenerator.swift
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Modulation/RandomTrigger.swift
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Modulation/LFO.swift

# 基本音源
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Sources/Oscillator.swift
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Sources/MultiOscillator.swift
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Sources/PulseGenerator.swift
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Sources/BandpassNoise.swift
git show e51bc1a^:clock-tsukiusagi/Core/Audio/Sources/NoiseSource.swift
```

**チェックリスト**:
- [ ] すべての依存ファイルを復活させた
- [ ] 型の参照を現在のモジュール構造に合わせて修正した
- [ ] コンパイルエラー（曖昧性エラー含む）をすべて解消した

### 2.1. 型の曖昧性を解消

復活させたコードで以下のような型参照があれば修正:

```swift
// ❌ 古い参照（曖昧性エラーの可能性）
let noiseGen = NoiseSource(type: .pink)

// ✅ 現在の参照
let noiseGen = NoiseGenerator(type: .pink)
```

### 3. 各音源に suspend/resume を追加

すべての音源に `AudioState` ヘルパークラスと suspend/resume メソッドを実装。

### 4. NaturalSoundPresets に設定を追加

```swift
// clock-tsukiusagi/Core/Audio/Presets/NaturalSoundPresets.swift

public enum NaturalSoundPreset: String, CaseIterable, Identifiable {
    // ... 既存のケース
    case windChime          // 癒しチャイム
    case tibetanBowl        // チベタンボウル風
    case oceanWaves         // 波の音
    case cracklingFire      // 焚き火の音

    public var displayName: String {
        switch self {
        // ...
        case .windChime:
            return "癒しチャイム"
        case .tibetanBowl:
            return "チベタンボウル"
        case .oceanWaves:
            return "波の音"
        case .cracklingFire:
            return "焚き火の音"
        }
    }
}

// 設定構造体を追加
public struct NaturalSoundPresets {
    // MARK: - Wind Chime（癒しチャイム）
    public struct WindChime {
        public static let frequencies: [Double] = [
            1047.0,  // C6
            1175.0,  // D6
            1319.0,  // E6
            1568.0,  // G6
            1760.0,  // A6
            2093.0   // C7
        ]
        public static let amplitude: Double = 0.3
        public static let minInterval: Double = 2.0
        public static let maxInterval: Double = 8.0
        public static let attackTime: Double = 0.01
        public static let decayTime: Double = 3.0
        public static let sustainLevel: Double = 0.0
        public static let releaseTime: Double = 1.0
    }

    // ... TibetanBowl, OceanWaves, CracklingFire の設定も同様に追加
}
```

### 5. AudioService に登録処理を追加

```swift
// clock-tsukiusagi/Core/Audio/AudioService.swift

private func registerSource(for preset: NaturalSoundPreset) {
    switch preset {
    // ... 既存のケース

    case .windChime:
        let source = WindChime(
            frequencies: NaturalSoundPresets.WindChime.frequencies,
            amplitude: NaturalSoundPresets.WindChime.amplitude,
            minInterval: NaturalSoundPresets.WindChime.minInterval,
            maxInterval: NaturalSoundPresets.WindChime.maxInterval,
            attackTime: NaturalSoundPresets.WindChime.attackTime,
            decayTime: NaturalSoundPresets.WindChime.decayTime,
            sustainLevel: NaturalSoundPresets.WindChime.sustainLevel,
            releaseTime: NaturalSoundPresets.WindChime.releaseTime
        )
        engine.register(source)

    case .tibetanBowl:
        let source = TibetanBowl(
            fundamentalFrequency: NaturalSoundPresets.TibetanBowl.fundamentalFrequency,
            amplitude: NaturalSoundPresets.TibetanBowl.amplitude,
            harmonics: NaturalSoundPresets.TibetanBowl.harmonics,
            vibratoFrequency: NaturalSoundPresets.TibetanBowl.vibratoFrequency,
            vibratoDepth: NaturalSoundPresets.TibetanBowl.vibratoDepth
        )
        engine.register(source)

    case .oceanWaves:
        let source = OceanWaves(
            noiseAmplitude: NaturalSoundPresets.OceanWaves.noiseAmplitude,
            lfoFrequency: NaturalSoundPresets.OceanWaves.lfoFrequency,
            lfoDepth: NaturalSoundPresets.OceanWaves.lfoDepth,
            lfoMinimum: NaturalSoundPresets.OceanWaves.lfoMinimum,
            lfoMaximum: NaturalSoundPresets.OceanWaves.lfoMaximum
        )
        engine.register(source)

    case .cracklingFire:
        let source = CracklingFire(
            baseAmplitude: NaturalSoundPresets.CracklingFire.baseAmplitude,
            pulseAmplitude: NaturalSoundPresets.CracklingFire.pulseAmplitude,
            minInterval: NaturalSoundPresets.CracklingFire.pulseMinInterval,
            maxInterval: NaturalSoundPresets.CracklingFire.pulseMaxInterval,
            minPulseDuration: NaturalSoundPresets.CracklingFire.pulseMinDuration,
            maxPulseDuration: NaturalSoundPresets.CracklingFire.pulseMaxDuration
        )
        engine.register(source)
    }
}
```

### 6. AudioFilePresets の switch を exhaustive に

```swift
// clock-tsukiusagi/Core/Audio/Presets/AudioFilePresets.swift

extension NaturalSoundPreset {
    public var audioFilePreset: AudioFilePreset? {
        switch self {
        // ... 既存のケース
        case .windChime:
            return nil  // Uses synthesis (WindChime)
        case .tibetanBowl:
            return nil  // Uses synthesis (TibetanBowl)
        case .oceanWaves:
            return nil  // Uses synthesis (OceanWaves)
        case .cracklingFire:
            return nil  // Uses synthesis (CracklingFire)
        }
    }
}
```

---

## 注意事項・ベストプラクティス

### 1. 音源のライフサイクル管理

**必須**: すべての `AVAudioSourceNode` ベースの音源には `suspend()/resume()` を実装すること。

```swift
// ❌ 悪い例: 空実装
public func stop() {
    // 何もしない → render callback が動き続ける
}

// ✅ 良い例: suspend で無音化
public func suspend() {
    audioState.isSuspended = true
}

public func resume() {
    audioState.isSuspended = false
}
```

### 2. 音源の切り替え

**必須**: 新しい音源を登録する前に、必ず `clearSources()` を呼ぶこと。

```swift
// ❌ 悪い例: クリアせずに登録
registerSource(for: newPreset)  // 古い音源と同時再生される

// ✅ 良い例: クリア後に登録
engine.clearSources()  // 古い音源を完全に削除
registerSource(for: newPreset)  // 新しい音源だけが再生される
```

### 3. AVAudioEngine のノード管理

**重要**: ノードをデタッチする順序に注意。

```swift
public func clearSources() {
    sources.forEach {
        $0.stop()        // 1. 音源を停止
        $0.suspend()     // 2. 無音化
        engine.detach($0.sourceNode)  // 3. エンジンからデタッチ
    }
    sources.removeAll()  // 4. 配列をクリア
}
```

### 4. パラメータの受け渡し

**注意**: `AVAudioSourceNode` のクロージャ内で使用する変数は、必ずローカルコピーを作成すること。

```swift
public init(amplitude: Double) {
    // ❌ 悪い例: 直接キャプチャ
    _sourceNode = AVAudioSourceNode { ... in
        let sample = sin(phase) * amplitude  // エラーの可能性
    }

    // ✅ 良い例: ローカルコピー
    let localAmplitude = amplitude
    _sourceNode = AVAudioSourceNode { ... in
        let sample = sin(phase) * localAmplitude  // 安全
    }
}
```

### 5. switch 文の exhaustive チェック

**必須**: `NaturalSoundPreset` に新しいケースを追加したら、以下のファイルも更新すること。

1. `NaturalSoundPreset.displayName` - 表示名
2. `AudioService.registerSource(for:)` - 音源登録
3. `AudioFilePresets.audioFilePreset` - ファイルプリセット（合成音源は `nil`）

---

## テスト項目

### 基本動作確認

- [ ] すべてのプリセット（14種類）が選択可能
- [ ] 各プリセットで異なる音が再生される
- [ ] 停止ボタンで確実に音が止まる
- [ ] プリセット切り替え時に音源が正しく切り替わる

### 詳細確認

#### WindChime
- [ ] ランダムな間隔でチャイム音が鳴る（2〜8秒）
- [ ] ペンタトニックスケールの音程が聞こえる
- [ ] 各音が自然に減衰する

#### TibetanBowl
- [ ] 持続的な倍音が聞こえる
- [ ] ビブラートによる揺らぎがある
- [ ] 深い瞑想的な音色

#### OceanWaves
- [ ] 波の強弱が周期的に変化する（約5秒周期）
- [ ] ホワイトノイズベースの自然な波音
- [ ] 音量が滑らかに上下する

#### CracklingFire
- [ ] 持続的なベース音（ピンクノイズ）
- [ ] ランダムなパチパチ音（0.5〜3秒間隔）
- [ ] 焚き火らしい雰囲気

---

## 関連ファイル

### 新規作成

```
clock-tsukiusagi/Core/Audio/Sources/
├── WindChime.swift          (新規)
├── TibetanBowl.swift        (新規)
├── OceanWaves.swift         (新規)
└── CracklingFire.swift      (新規)
```

### 修正

```
clock-tsukiusagi/Core/Audio/
├── Engine/LocalAudioEngine.swift      (clearSources() 追加)
├── AudioService.swift                 (clearSources() 呼び出し、登録処理追加)
├── Presets/NaturalSoundPresets.swift  (4プリセット設定追加)
├── Presets/AudioFilePresets.swift     (switch exhaustive 対応)
└── Sources/
    ├── PinkNoise.swift                (suspend/resume 追加)
    ├── BrownNoise.swift               (suspend/resume 追加)
    ├── PleasantDrone.swift            (suspend/resume 追加、設定修正)
    ├── AmbientDrone.swift             (suspend/resume 追加)
    └── DetunedOscillator.swift        (suspend/resume 追加)
```

---

## トラブルシューティング

### 型の曖昧性エラー（"X is ambiguous"）

**症状**: `NoiseType is ambiguous` や `ChordType is ambiguous` などのコンパイルエラー

**原因**: git履歴から復活させたコードが古い型参照を使用している

**解決策**:

1. **エラー箇所を特定**
   ```
   error: 'NoiseType' is ambiguous for type lookup in this context
   ```

2. **完全修飾名で確認**
   ```swift
   // どちらの型を使うべきか確認
   let type1: NoiseSource.NoiseType = .pink
   let type2: NoiseGenerator.NoiseType = .pink
   ```

3. **現在のモジュール構造に合わせて修正**
   ```swift
   // ❌ 古い参照
   let noiseGen = NoiseSource(type: .pink)

   // ✅ 現在の参照
   let noiseGen = NoiseGenerator(type: .pink)
   ```

4. **影響を受けるファイルをすべて修正**
   - git履歴から復活させたすべてのファイルをチェック
   - 特に `AmbientDrone.swift`, `OceanWaves.swift`, `CracklingFire.swift` など

---

### 音が止まらない場合

1. `suspend()` メソッドが実装されているか確認
2. render callback 内で `isSuspended` チェックがあるか確認
3. `AudioState` クラスが正しくキャプチャされているか確認

**デバッグ方法**:
```swift
public func suspend() {
    audioState.isSuspended = true
    print("🎵 [SourceName] Suspended (output silence)")  // ログで確認
}
```

---

### 複数の音が重なる場合

1. `AudioService.play()` で `clearSources()` を呼んでいるか確認
2. `LocalAudioEngine.clearSources()` が正しく実装されているか確認
3. ノードが正しくデタッチされているか確認

**デバッグ方法**:
```swift
public func clearSources() {
    print("LocalAudioEngine: Clearing all sources (count: \(sources.count))")
    // ... クリア処理
    print("LocalAudioEngine: All sources cleared")
}
```

プリセット切り替え時に以下のログが出力されるか確認:
```
🎵 [AudioService] Cleared previous sources
LocalAudioEngine: Clearing all sources (count: 1)
LocalAudioEngine: All sources cleared
```

---

### ビルドエラー

#### 1. switch が exhaustive でない

**エラー**: `switch must be exhaustive`

**解決策**: 新しいenumケースをすべての switch 文に追加

影響を受けるファイル:
- `NaturalSoundPreset.displayName`
- `AudioService.registerSource(for:)`
- `AudioFilePresets.audioFilePreset`

#### 2. 未使用変数の警告

**警告**: `initialization of immutable value 'localLFODepth' was never used`

**解決策**:
```swift
// ❌ 警告が出る
let localLFODepth = lfoDepth  // 未使用

// ✅ 明示的に破棄
let _ = lfoDepth  // Note: depth is controlled by other parameters
```

#### 3. 依存ファイルの欠落

**エラー**: `Cannot find type 'EnvelopeGenerator' in scope`

**解決策**: 依存するすべてのファイルを復活させる
- `EnvelopeGenerator.swift`
- `RandomTrigger.swift`
- `LFO.swift`
- その他の補助クラス

---

## まとめ

この実装により、以下が達成された:

1. ✅ 4つの欠落していた自然音プリセットを復活
2. ✅ 停止ボタンが正しく機能するよう修正
3. ✅ プリセット切り替え時の音源クリア機構を実装
4. ✅ すべての合成音源に suspend/resume を実装
5. ✅ PleasantDrone の設定を正しい値に修正

現在、合計14種類の自然音プリセットがすべて正常に動作している。
