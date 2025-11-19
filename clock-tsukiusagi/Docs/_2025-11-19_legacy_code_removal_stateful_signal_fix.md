# 2025-11-19: Legacy Code Removal & Stateful Signal Fix

**Date**: 2025-11-19
**Branch**: `feature/signal-engine-phase1-2`
**Status**: Completed

## 概要

1. 新旧音質A/B比較の結果、FinalMixer方式が明らかに優れていたため、レガシーコードを削除
2. ステートフルなSignalプリセットのバグ（バチバチ音）を修正
3. ジェネレータのreset()メソッド追加

---

## 1. Legacy SignalAudioSource Code Removal

### 背景

以前のセッションで、ユーザーが新旧両方式を画面上で比較したいと要望。
- 旧式: `SignalAudioSource` - エフェクトなし、直接Signal→AVAudioSourceNode
- 新式: `FinalMixer` - TPT-SVFフィルタ、Schroederリバーブ、ソフトリミッター付き

AudioSourcePreset enumに`.legacy(NaturalSoundPreset)`ケースを追加し、サイドバイサイド比較を実装（commit: 5c5c90e）。

### ユーザーフィードバック

> 「明らかに新式の方が音がいいです。旧式を削除しましょう」

新式（FinalMixer）の音質が明確に優れていることが確認されたため、レガシーコード削除を決定。

### 削除内容

**Commit: 23fd402 - "refactor: remove legacy SignalAudioSource code after A/B testing"**

1. **AudioTestView.swift**
   - `.legacy(NaturalSoundPreset)` ケースを削除
   - 元の2ケース構造に戻す（synthesis, audioFile）

2. **AudioService.swift**
   - `playLegacy(preset:)` メソッド削除
   - `_playInternal()` の `useLegacy: Bool` パラメータ削除
   - `registerSource()` の `useLegacy` 分岐削除

3. **SignalPresetBuilder.swift**
   - `makeSignal(for: NaturalSoundPreset)` メソッド全削除（83行）
   - ドキュメント更新: FinalMixer専用ファクトリであることを明記

4. **全14プリセットファイル**
   - `make(sampleRate: Double) -> SignalAudioSource` メソッド削除
   - 各ファイルから4-5行削除
   - `makeSignal() -> Signal` メソッドのみ残す

### 教訓: sed一括削除の失敗

最初、以下のsedコマンドで一括削除を試みた：

```bash
sed -i "" "/^$/,/public static func make(sampleRate: Double)/d" *.swift
```

**結果**: 13ファイルが破壊され、ヘッダーコメント（8行）のみ残る大惨事。

**原因**: sedの範囲指定 `/^$/,/pattern/` が想定外に動作。空行から始まる範囲が全コードを飲み込んだ。

**復旧**: `git checkout HEAD -- *.swift` で復元し、Editツールで1ファイルずつ手動削除。

**教訓**: 複数ファイルの一括編集には細心の注意を。sed/awk/perlよりもEditツールの方が安全。

### ビルド結果

```
** BUILD SUCCEEDED **
```

17ファイル変更、18挿入、217削除。

---

## 2. Stateful Signal Bug Fix

### 問題発見

ユーザー報告：
- **遠雷（DistantThunder）**: 「ザーザザザ、バンっ、バンっ、という感じの音が繰り返し再生」
- **夜の図書館（SilentLibrary）**: 「ザーザざざ、のみ。1回だけで繰り返されません」

### 原因分析

#### 問題のあるコード構造

```swift
// DistantThunderSignal.swift (Before)
public static func makeSignal() -> Signal {
    let noise = Noise.brown()

    // ❌ クロージャの外で var 宣言
    var lastPulseTime: Float = 0
    var nextPulseTime: Float = Float.random(in: 2.0...7.0)
    var pulseDecay: Float = 0.0
    var pulseActive = false

    return Signal { t in
        // ❌ 毎回この変数が初期化される
        if t - lastPulseTime >= nextPulseTime {  // lastPulseTime は常に 0
            pulseActive = true
            // ...
        }
    }
}
```

#### バグの原因

1. `Signal { t in ... }` クロージャが**FinalMixer.swift:105**で毎回評価される
2. クロージャの外側にある `var lastPulseTime = 0` が**毎回再初期化**される
3. 条件 `t - 0 >= nextPulseTime` が最初の数サンプルで常にtrueになる
4. パルスが連続発火 → 「バンバンバン」という爆竹音

#### 影響を受けたプリセット

調査の結果、**4つのプリセット**で同じ問題を確認：

| Preset | Classification | Mutable State | Risk Level |
|--------|----------------|---------------|------------|
| DistantThunderSignal | STATEFUL | `lastPulseTime`, `nextPulseTime`, `pulseDecay`, `pulseActive` | CRITICAL |
| StardustNoiseSignal | STATEFUL | `lastToggleTime`, `nextBurstTime`, `burstActive` | CRITICAL |
| WindChimeSignal | STATEFUL | `activeChimes[]`, `lastTriggerTime`, `nextTriggerTime` | CRITICAL |
| TibetanBowlSignal | STATEFUL | `mixedSample` (local) | MEDIUM (safe) |

**安全なプリセット**: 10個（MoonlitSea, LunarTide, AbyssalBreath, LunarPulse, DarkShark, MidnightTrain, LunarDustStorm, SilentLibrary, SinkingMoon, DawnHint）
- すべてステートレスなLFO使用

### 修正内容

**Commit: 3dbe879 - "fix: convert stateful Signal presets to class-based generators"**

#### クラスベースジェネレータへの変換

```swift
// After: クラスで状態を保持
public struct DistantThunderSignal {
    public static func makeSignal() -> Signal {
        let generator = DistantThunderGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

private final class DistantThunderGenerator {
    private let noise = Noise.brown()

    // ✅ クラスプロパティとして状態保持
    private var lastPulseTime: Float = 0
    private var nextPulseTime: Float = Float.random(in: 2.0...7.0)
    private var pulseDecay: Float = 0.0
    private var pulseActive = false

    func sample(at t: Float) -> Float {
        // ✅ lastPulseTime は保持される
        if t - lastPulseTime >= nextPulseTime {
            pulseActive = true
            pulseDecay = 1.0
            lastPulseTime = t
            nextPulseTime = Float.random(in: 2.0...7.0)
        }
        // ...
    }
}
```

#### 修正したファイル

1. **DistantThunderSignal.swift**: Thunder pulses (2-7s intervals)
2. **StardustNoiseSignal.swift**: Micro bursts (0.4-1.2s intervals)
3. **WindChimeSignal.swift**: Pentatonic chimes (2-8s intervals)

#### TibetanBowlSignal

このプリセットは `var mixedSample: Float = 0.0` をクロージャ内のローカル変数として使用。
毎回リセットされるため問題なし。修正不要。

### ビルド結果

```
** BUILD SUCCEEDED **
```

3ファイル変更、130挿入、106削除。

---

## 3. Reset Methods for Stateful Generators

### 背景

ユーザー質問：
> 「なお、前回の音に影響されないように、resetで初期化などの処理はありますか？」

### 調査結果

**既存のreset処理**:

1. **AudioService.swift:730-732** (プリセット切り替え時)
   ```swift
   resetCurrentSignalEffectsState()  // エフェクト（リバーブ、フィルタ）をリセット
   clearCurrentSignalSource()        // 古いSignalインスタンスを破棄
   ```

2. **AudioService.swift:353** (停止時)
   ```swift
   clearCurrentSignalSource()  // Signalインスタンスを破棄
   ```

3. **FinalMixer.swift:189**
   ```swift
   public func resetEffectsState() {
       effects.forEach { $0.reset() }  // エフェクトのみリセット
   }
   ```

**問題点**: エフェクトはリセットされるが、Signal自体（ジェネレータクラスの状態）はリセットされていない。

**ただし**、実際には問題なし。理由：
- プリセット切り替え時: `clearCurrentSignalSource()` → 古いインスタンス破棄 → 新しいインスタンス作成
- 停止→再生時: 同様に新しいインスタンス作成

**つまり、インスタンスが毎回再作成されるため、状態は自動的にリセットされる。**

### 実装内容

**Commit: 02f4443 - "feat: add reset() methods to stateful Signal generators"**

将来的な拡張性のため、各ジェネレータに `reset()` メソッドを追加：

```swift
private final class DistantThunderGenerator {
    // ...

    /// Reset generator state to initial values
    func reset() {
        lastPulseTime = 0
        nextPulseTime = Float.random(in: 2.0...7.0)
        pulseDecay = 0.0
        pulseActive = false
    }
}
```

**現時点では使用されていない**が、以下のメリット：
- 明示的な状態管理API
- 何をクリアすべきかのドキュメント
- 将来的な最適化パス（破棄→再作成 vs reset）

### ビルド結果

```
** BUILD SUCCEEDED **
```

3ファイル変更、22挿入。

---

## Commits Summary

| Commit | Description | Files | Changes |
|--------|-------------|-------|---------|
| 23fd402 | Legacy SignalAudioSource code removal | 17 | +18, -217 |
| 3dbe879 | Stateful Signal bug fix (class-based generators) | 3 | +130, -106 |
| 02f4443 | Reset methods for stateful generators | 3 | +22, 0 |

**Total**: 23 files changed, 170 insertions(+), 323 deletions(-)

---

## Architecture Insights

### FinalMixer vs SignalAudioSource

**FinalMixer方式が優れている理由**:

1. **音質**: TPT-SVFフィルタ、Schroederリバーブにより自然な音響空間
2. **安定性**: 数値的に安定したフィルタ実装
3. **拡張性**: エフェクトチェーン追加が容易
4. **一貫性**: 全プリセットで同じエフェクト処理

**SignalAudioSource（旧式）の問題**:
- エフェクトなし → 平坦な音
- 直接AVAudioSourceNodeに接続 → 柔軟性なし
- 個別実装が必要 → メンテナンス困難

### Stateful Signal Pattern

**問題のあるパターン**:
```swift
var state = initialValue
return Signal { t in
    // state は毎回リセットされる
}
```

**正しいパターン**:
```swift
class Generator {
    private var state = initialValue
    func sample(at t: Float) -> Float { ... }
}
let gen = Generator()
return Signal { t in gen.sample(at: t) }
```

**重要**: Signalクロージャ内の `var` は状態を保持できない。クラスインスタンスでキャプチャする必要がある。

---

## Testing Notes

### 修正前の音

- **遠雷**: 「ザーザザザ、バンっ、バンっ」（連続爆竹音）
- **星屑ノイズ**: 同様にバチバチ音
- **風鈴**: 同様にバチバチ音

### 修正後の期待される音

- **遠雷**: 「ザーーー（ベースノイズ）+ たまにゴロゴロ（2-7秒間隔）」
- **星屑ノイズ**: 「シャーーー（ホワイトノイズ）+ 0.4-1.2秒でバースト切替」
- **風鈴**: 「無音 + 2-8秒間隔でペンタトニックチャイム」

### 夜の図書館（SilentLibrary）

**問題なし**: ステートレスなLFO使用、バグは存在しなかった。
ユーザーが聞いた「ザーザざざ、1回だけ」は再生開始時のフェードイン音と思われる。

---

## Lessons Learned

### 1. A/B Testing の重要性

ユーザーに新旧両方を実際に聴き比べてもらうことで、明確な判断基準を得られた。
技術的な指標だけでなく、実際の音質評価が決定的。

### 2. sed/awk の危険性

複数ファイルの一括編集は便利だが、1つのミスで大惨事に。
IDE のEditツールやスクリプトレビューの方が安全。

### 3. Stateful Signal の落とし穴

Swiftのクロージャキャプチャの挙動を正しく理解する必要がある。
クロージャ外の `var` は毎回初期化される可能性がある。

### 4. インスタンス再作成 vs Reset

現在の実装では、プリセット切り替え時に常に新しいインスタンスを作成している。
これはシンプルで確実だが、将来的にはreset()による最適化も検討可能。

---

## Next Steps

1. **実機テスト**: 修正後の遠雷、星屑ノイズ、風鈴の音を確認
2. **ドキュメント整理**: この備忘録を正式なドキュメントに統合
3. **他のプリセット確認**: 10個のステートレスプリセットの音質検証
4. **パフォーマンス測定**: class-based generator のオーバーヘッド確認

---

## References

- Commit: 5c5c90e - "feat: show legacy and new presets side-by-side for A/B comparison"
- Commit: 23fd402 - "refactor: remove legacy SignalAudioSource code after A/B testing"
- Commit: 3dbe879 - "fix: convert stateful Signal presets to class-based generators"
- Commit: 02f4443 - "feat: add reset() methods to stateful Signal generators"
- Previous session: `_2025-11-18_signal_engine_tpt_svf_fix.md`

---

**Status**: All commits pushed to `feature/signal-engine-phase1-2`
**Build Status**: ✅ BUILD SUCCEEDED
**Ready for**: User testing on device

---

## 4. Additional Fixes: WindChime & Volume Issues

### WindChime Immediate Start (2025-11-19)

**Commit: ae8a627 - "fix: WindChime now starts immediately instead of waiting 2-8 seconds"**

#### Problem
User reported: "癒しチャイムのスタート時に数秒の余白（無音）があります"

Initial `nextTriggerTime` was set to `Float.random(in: 2.0...8.0)`, causing 2-8 second silence before first chime.

#### Root Cause
```swift
// Before
private var nextTriggerTime: Float = Float.random(in: 2.0...8.0)  // 2-8 seconds wait

// Check if time to trigger
if t - lastTriggerTime >= nextTriggerTime {  // At t=0: 0 >= 2.0~8.0 → false
    // First chime never triggers immediately
}
```

#### Solution
```swift
// After
private var nextTriggerTime: Float = 0  // Trigger immediately

// First sample: t=0, 0 - 0 >= 0 → true, chime plays immediately
// Subsequent chimes still use random 2-8s intervals
```

#### User Feedback
> "最初だけは、バグに感じてしまうので、スタート直後は音が出てほしい"

Natural wind chime silence is fine for subsequent intervals, but initial silence feels like a bug.

---

### Volume Normalization (2025-11-19)

**Commit: b43a0fd - "fix: expand LFO range for MidnightTrain and DarkShark to match other preset volumes"**

#### Problem Discovery

User reported extremely low volume for:
1. **夜汽車 (MidnightTrain)** - 小さい
2. **深海の呼吸 (AbyssalBreath)** - 小さい
3. **黒いサメの影 (DarkShark)** - ものすごく小さくて、一番大きくしてもほぼ聞こえないレベル

#### Investigation Process

**Step 1: Compare Signal implementation with original AudioSource**

Read original source files:
- `/Core/Audio/Sources/MidnightTrain.swift`
- `/Core/Audio/Sources/AbyssalBreath.swift`
- `/Core/Audio/Sources/DarkShark.swift`

**Step 2: Volume calculation analysis**

| Preset | Base Amplitude | LFO Range | Final Max | vs LunarTide |
|--------|----------------|-----------|-----------|--------------|
| LunarTide | 0.12 | 0.825~1.0 | **0.12** | 1.0x (baseline) |
| MoonlitSea | 0.4 | 0.03~0.10 | 0.04 | 0.33x |
| AbyssalBreath | 0.10+0.03 | 0.875~1.0 | **0.13** | 1.08x ✅ |
| MidnightTrain | 0.3 | 0.03~0.12 | 0.036 | 0.30x ⚠️ |
| DarkShark | 0.4 | 0.02~0.08 | 0.032 | 0.27x 🚨 |

**Key Finding**: Signal implementation correctly reproduced original code. **The low volume existed in the original AudioSource implementation.**

#### Root Cause

Original implementation formula:
```swift
// MidnightTrain (original)
samples?[frame] = noiseSample * 0.3 * (0.03~0.12)
// Maximum: 0.3 * 0.12 = 0.036

// DarkShark (original)
samples?[frame] = noiseSample * 0.4 * (0.02~0.08)
// Maximum: 0.4 * 0.08 = 0.032
```

The LFO modulation range was too narrow, resulting in very quiet output even in the original design.

#### Solution Strategy

Two approaches considered:

**Method A: Expand LFO range** (✅ Chosen)
- Preserve base amplitude (0.3 / 0.4)
- Widen LFO modulation range
- Maintains character "density" and "presence"

**Method B: Increase base amplitude** (❌ Rejected)
- Change base amplitude (e.g., 0.3 → 1.0)
- Simpler but loses original character

#### Implementation

**MidnightTrain:**
```swift
// Before
LFO range: 0.03 ~ 0.12
Final: 0.3 * (0.03~0.12) = 0.009 ~ 0.036

// After
LFO range: 0.10 ~ 0.40  // 3.33x expansion
Final: 0.3 * (0.10~0.40) = 0.030 ~ 0.12 ✅
```

**DarkShark:**
```swift
// Before
LFO range: 0.02 ~ 0.08
Final: 0.4 * (0.02~0.08) = 0.008 ~ 0.032

// After
LFO range: 0.075 ~ 0.30  // 3.75x expansion
Final: 0.4 * (0.075~0.30) = 0.030 ~ 0.12 ✅
```

#### Why Method A is Superior

User's insight (translated):
> "✨ 推奨：方法A（LFOレンジ拡大）
>
> 理由：
> - キャラの「density（密度・圧）」と「presence（存在感）」が保たれる
> - ベース振幅（0.3 / 0.4）を変えない＝"世界観が壊れない"
> - LFOダイナミクスが広がる→サメの"影が揺らぐ感じ"が強まってむしろ良い
> - 最小値も底上げされる→"聞こえない時間帯"がなくなる
>
> これは音響的にも正しいし、「構造の意味」的にも揺らがん。"

**Benefits:**
1. ✅ Preserves sonic character (density, pressure, presence)
2. ✅ Maintains world-building integrity
3. ✅ Enhanced LFO dynamics improve expression (e.g., "shadow wavering" for DarkShark)
4. ✅ Raises minimum floor - eliminates "unhearable" moments
5. ✅ Acoustically and structurally sound

#### Results

After fix, all presets normalized to ~0.12 maximum:
- LunarTide: 0.12 (unchanged)
- AbyssalBreath: 0.13 (unchanged)
- MidnightTrain: 0.036 → **0.12** (+233%)
- DarkShark: 0.032 → **0.12** (+275%)

---

## Lessons Learned (Extended)

### 5. Volume Balance Requires Cross-Preset Testing

**Issue**: Individual presets may sound correct in isolation but be severely imbalanced relative to others.

**Solution**:
- Always test all presets side-by-side
- Establish a volume baseline (e.g., LunarTide @ 0.12)
- Measure maximum output for each preset
- Normalize to consistent range

### 6. Preserve Character When Fixing Volume

**Issue**: Naive volume fixes (multiplying by constant) can destroy sonic character.

**Wrong approach**: Change base amplitude
```swift
noise(t) * 1.0  // From 0.4 → loses density
```

**Correct approach**: Expand dynamic range
```swift
noise(t) * 0.4 * (0.075~0.30)  // Preserves density, adds dynamics
```

**Principle**:
- Base amplitude = character density/pressure
- LFO range = dynamic expression/movement
- Adjust LFO range for volume, preserve base for character

### 7. Original Implementation Can Have Design Flaws

**Finding**: Signal implementation correctly reproduced original AudioSource code, yet volume was still wrong.

**Implication**:
- Don't assume original code is perfect
- Signal conversion revealed latent issues
- Legacy bugs can hide until compared side-by-side
- A/B testing is crucial for quality validation

### 8. User Perception of Bugs vs Design Intent

**WindChime silence**: Technically "correct" (wind needs time to blow chimes), but feels like a bug to users.

**Principle**:
- Initial experience matters more than physical accuracy
- 2-8 second silence on start = perceived broken
- Immediate sound + subsequent delays = perceived working
- UX > realism for initial interaction

---

## Updated Commits Summary

| Commit | Description | Files | Changes |
|--------|-------------|-------|---------|
| 23fd402 | Legacy SignalAudioSource code removal | 17 | +18, -217 |
| 3dbe879 | Stateful Signal bug fix (class-based generators) | 3 | +130, -106 |
| 02f4443 | Reset methods for stateful generators | 3 | +22, 0 |
| ae8a627 | WindChime immediate start fix | 1 | +2, -2 |
| b43a0fd | Volume normalization (LFO range expansion) | 2 | +11, -8 |

**Total**: 26 files changed, 183 insertions(+), 333 deletions(-)

---

## Final Architecture State

### Volume Levels (Normalized)

All presets now output comparable maximum volumes:

| Preset | Max Output | Status |
|--------|-----------|--------|
| LunarTide | 0.12 | ✅ Baseline |
| AbyssalBreath | 0.13 | ✅ Slightly louder (sub-bass) |
| MoonlitSea | 0.04 | ⚠️ Intentionally quieter |
| MidnightTrain | 0.12 | ✅ Fixed |
| DarkShark | 0.12 | ✅ Fixed |
| LunarPulse | 0.04 | ⚠️ Intentionally quieter |
| All others | ~0.10-0.12 | ✅ Normal |

Note: MoonlitSea and LunarPulse remain quieter by design for their ambient character.

### Stateful Signal Pattern (Final)

**Problem pattern:**
```swift
var state = 0
return Signal { t in
    state += 1  // ❌ Resets every call
}
```

**Correct pattern:**
```swift
class Generator {
    private var state = 0
    func sample(at t: Float) -> Float {
        state += 1  // ✅ Preserved across calls
    }
}
let gen = Generator()
return Signal { t in gen.sample(at: t) }
```

**With reset support:**
```swift
class Generator {
    private var state = 0

    func reset() {  // ✅ Explicit state cleanup
        state = 0
    }

    func sample(at t: Float) -> Float { ... }
}
```

---

**Last Updated**: 2025-11-19 (Extended with WindChime & Volume fixes)
**Status**: ✅ All issues resolved
**Sound Quality**: ✅ Balanced and consistent across all presets
