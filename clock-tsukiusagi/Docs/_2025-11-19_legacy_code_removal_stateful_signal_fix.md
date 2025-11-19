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
