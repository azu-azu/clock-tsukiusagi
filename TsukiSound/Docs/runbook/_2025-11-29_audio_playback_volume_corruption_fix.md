# 2回目再生時の音量・ピッチ異常の修正

**日付**: 2025-11-29
**カテゴリ**: Audio / Bug Fix
**ステータス**: 解決済み

---

## 問題の概要

一度再生して停止し、2回目に再生すると以下の問題が発生：
1. **ピッチが低くなる** - 全体的に音程が下がって聞こえる
2. **音量が0になる** - `mainMixerNode.outputVolume` が 0.0 のまま

---

## 根本原因

### 原因1: サンプルレート変動（44100Hz → 48000Hz）

**発生箇所**: `LocalAudioEngine.register()`

```swift
// ❌ 問題のコード
let format = engine.outputNode.inputFormat(forBus: 0)
```

`AVAudioEngine.outputNode.inputFormat(forBus: 0)` はエンジン再起動後に異なるサンプルレートを返すことがある。
- 1回目: 44100Hz
- 2回目: 48000Hz

サンプルレートが変わると、同じ周波数でも実際のピッチが変化する。

**修正**:
```swift
// ✅ 固定フォーマットを使用
let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
```

### 原因2: フェードアウトタイマーの残留

**発生箇所**: `AudioService.fadeOut()` / `stopAndWait()`

`stopAndWait()` の completion handler で `play()` が呼ばれる流れ：

```
stopAndWait() → fadeOut() 開始 → 0.5秒後 → completion() → play()
```

問題：フェードアウトは0.5秒間、60ステップで volume を 1.0 → 0.0 に下げる。
`play()` が呼ばれた時点でフェードアウトはほぼ完了しているが、残りのタイマーコールバックが新しい再生を邪魔する。

さらに、Timer callback 内で `Task { @MainActor ... }` を使用していたため：
- `fadeTimer?.invalidate()` を呼んでも
- すでに dispatch された Task は停止できない
- その Task が volume を 0.0 に設定してしまう

---

## 解決策

### 修正1: 固定サンプルレート

`LocalAudioEngine.swift`:
```swift
public func register(_ source: AudioSource) {
    // 固定フォーマットを使用（44100Hz, 2ch）してサンプルレート変動を防ぐ
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    // ...
}
```

### 修正2: フェード無効化フラグ

`AudioService.swift`:
```swift
private var fadeEnabled: Bool = true

public func play(preset: UISoundPreset) throws {
    // CRITICAL: 前のセッションのフェードアウトを即座に無効化
    fadeEnabled = false
    fadeTimer?.invalidate()
    fadeTimer = nil
    // ...
}

private func fadeOut(duration: TimeInterval) {
    guard fadeEnabled else { return }
    // ...
}
```

### 修正3: セッションID保護

```swift
private var playbackSessionId = UUID()

private func fadeOut(duration: TimeInterval) {
    let fadeSessionId = playbackSessionId  // 開始時のIDをキャプチャ

    fadeTimer = Timer.scheduledTimer(...) { [weak self] timer in
        Task { @MainActor [weak self] in
            // セッションが変わったら無視
            guard fadeSessionId == self.playbackSessionId else {
                timer.invalidate()
                return
            }
            // フェード処理...
        }
    }
}
```

### 修正4: 遅延音量復元

```swift
// 0.6秒後に音量を強制再設定（念のため）
let currentSessionId = playbackSessionId
DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
    guard let self = self, currentSessionId == self.playbackSessionId else { return }
    self.fadeEnabled = true
    self.applyDynamicGainCompensation()
}
```

---

## Swift 6 Concurrency 対応

Timer callback は MainActor 外で実行されるため、MainActor-isolated プロパティに直接アクセスすると警告が出る：

```
Main actor-isolated property 'fadeEnabled' can not be referenced from a Sendable closure
```

**解決策**: Timer callback 内で `Task { @MainActor ... }` を使用してプロパティアクセスを MainActor 上で行う。

```swift
fadeTimer = Timer.scheduledTimer(...) { [weak self] timer in
    guard let self = self else {
        timer.invalidate()
        return
    }

    Task { @MainActor [weak self] in
        guard let self = self else { return }
        // ここで MainActor-isolated プロパティにアクセス可能
        guard self.fadeEnabled else { return }
        self.engine.setMasterVolume(newVolume)
    }
}
```

---

## デバッグ用ログ（✂️マーク付き）

問題調査時に使用したログ。本番前に削除すること：

```swift
// AudioService.swift
print("🎵 [AudioService] after applyDynamicGainCompensation() mainMixerVolume=\(engine.engine.mainMixerNode.outputVolume)")

// FinalMixerOutputNode.swift
print("🎵 [FinalMixerOutputNode] attachAndConnect() sampleRate=\(sr), time=\(state.time), volume=\(state.volume)")
```

---

## 教訓

1. **AVAudioEngine のフォーマットは信用しない** - outputNode.inputFormat は状況によって変わる
2. **Timer + Task の組み合わせに注意** - invalidate() しても dispatch 済みの Task は止まらない
3. **セッションIDパターンは有効** - 世代管理で古いコールバックを無視できる
4. **フラグによる即時無効化** - 非同期処理を止める最もシンプルな方法

---

## 関連ファイル

- `TsukiSound/Core/Audio/Service/AudioService.swift`
- `TsukiSound/Core/Audio/Service/LocalAudioEngine.swift`
- `TsukiSound/Core/Audio/Mixing/FinalMixerOutputNode.swift`
- `TsukiSound/Core/Audio/Service/AudioSessionManager.swift`
