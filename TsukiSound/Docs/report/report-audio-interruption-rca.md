# RCA: オーディオ中断時の音声バグ

**Date**: 2025-12-05
**Status**: Resolved
**Severity**: Critical

---

## 問題の説明

**症状**: 再生中に別アプリを開いたりすると、音が止まったり、ブツっとなったり雑音が入ったりバグる

**再現条件**:
- TsukiSoundで音声再生中
- 別のアプリにスイッチ（例: LINE、Safari等）
- その後TsukiSoundに戻る

---

## 設計原則：3つのライフサイクルレイヤー

iOSオーディオシステムには3つの独立したライフサイクルレイヤーが存在する。
これらを混同すると、将来（AirPlay, SharePlay, Spatial Audio等）で破綻する。

| レイヤー | 責務 | iOSの意図 | 典型的処理 |
|---------|------|-----------|-----------|
| **Interruption** | 電話/通知/他アプリ優先再生 | 音を一時停止せよ | pause/stop |
| **Session Lifecycle** | iOSがセッションをリリース/再付与 | 権限返却→再取得せよ | setActive(true) |
| **Playback Graph** | エンジン/ノードのライフサイクル | デバイスが変わった、グラフ再構築せよ | node.play() |

---

## 根本原因分析

### Layer 1: Interruption（中断イベント処理）

#### 原因1-1: 中断ハンドリングの二重登録

**問題箇所**:
- `AudioService.swift` と `AudioSessionManager.swift` の両方で `AVAudioSession.interruptionNotification` を監視

**影響**:
- 中断イベントが2回処理される
- 競合状態で予期しない動作

```swift
// AudioService.swift
interruptionObserver = NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification, ...
)

// AudioSessionManager.swift
notificationCenter.addObserver(
    forName: AVAudioSession.interruptionNotification, ...
)
```

#### 原因1-2: 停止経路の二重化

**問題箇所**: `LocalAudioEngine.setupSessionCallbacks()`

**影響**:
- `AudioSessionManager.onInterruptionBegan` が `LocalAudioEngine.stop()` を呼び出す
- これは `AudioService.pause()` とは別経路でエンジンを停止
- `AudioService.isPlaying` と実際のエンジン状態が不整合に

```swift
// LocalAudioEngine.swift（修正前）
sessionManager.onInterruptionBegan = { [weak self] in
    self?.stop()  // エンジンを直接停止 → AudioService.isPlayingは更新されない
}
```

---

### Layer 2: Session Lifecycle（セッション権限管理）

#### 原因2: セッション再アクティベート不足

**問題箇所**: `AudioService.setupInterruptionHandling()`

**影響**:
- 中断終了後、セッションの再アクティベートが行われていない
- iOSは中断終了後、明示的に `setActive(true)` を呼ばないと音声出力を許可しない場合がある

```swift
// AudioService.swift（修正前）
case .ended:
    if options.contains(.shouldResume) && self.settings.autoResumeAfterInterruption {
        try? self.resume()  // resume()はセッション再アクティベートを行わない
    }
```

---

### Layer 3: Playback Graph（再生グラフ管理）

#### 原因3: TrackPlayer再生未再開

**問題箇所**: `AudioService.resume()`

**影響**:
- `engine.start()` のみでトラックプレイヤーの再生は再開されない
- TrackPlayerの `playerNode` が停止状態のまま
- エンジンとノードは別ライフサイクル

```swift
// AudioService.swift（修正前）
do {
    try engine.start()  // エンジンは起動するが...
} catch {
    throw AudioError.engineStartFailed(error)
}
// playerNode.play() が呼ばれていない → 音が出ない
```

---

## 修正内容

### Fix 1+2: Interruptionレイヤーの一元化

**対象**: `LocalAudioEngine.swift`

AudioSessionManagerのコールバックを無効化し、中断処理はAudioServiceに一元化。

```swift
private func setupSessionCallbacks() {
    // Architecture Decision: Interruption責務の一元化
    //
    // 中断ハンドリング（Interruption）、セッションライフサイクル（Session Lifecycle）、
    // 再生グラフ管理（Playback Graph）は AudioService で一元管理する。
    //
    // LocalAudioEngine は純粋にエンジン操作（start/stop/setVolume）のみを責務とし、
    // 中断イベントに対する判断や状態管理は行わない。
    //
    sessionManager.onInterruptionBegan = nil
    sessionManager.onInterruptionEnded = nil
    sessionManager.onRouteChanged = nil
}
```

**設計意図**: Interruptionの処理責務を AudioService に集約。LocalAudioEngine は純粋にエンジン操作のみ。

---

### Fix 3: Session Lifecycleの適切な管理

**対象**: `AudioService.swift`

```swift
case .ended:
    // Session Lifecycle: 中断終了後のセッション再アクティベート
    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        if options.contains(.shouldResume) && self.settings.autoResumeAfterInterruption {
            // iOSから権限が戻った → 明示的にセッションを再アクティベート
            try? AVAudioSession.sharedInstance().setActive(true)
            try? self.resume()
        }
    }
```

**設計意図**: Interruptionイベントの「結果」としてセッション権限が変わる。これは別レイヤーの問題なので明示的に処理。

---

### Fix 4: Playback Graphの再構築

**対象**: `AudioService.swift`

```swift
public func resume() throws {
    // ... 既存のチェック ...

    // エンジンを再開
    try engine.start()

    // Playback Graph: TrackPlayerを再開
    //
    // エンジンとノードは別ライフサイクル。
    // engine.start() だけでは playerNode の再生は再開されない。
    // 明示的に再生を開始する必要がある。
    //
    startTrackPlayerIfNeeded()

    // フェードイン
    fadeIn(duration: 0.5)

    // ...
}
```

**設計意図**: エンジンとノードは別ライフサイクル。エンジン起動後、再生ノードも明示的に再開する。

---

## 修正ファイル一覧

| レイヤー | ファイル | 変更内容 |
|---------|----------|----------|
| Interruption | `LocalAudioEngine.swift` | sessionCallbacksを無効化 |
| Session Lifecycle | `AudioService.swift` | 中断終了時にセッション再アクティベート |
| Playback Graph | `AudioService.swift` | resume()にTrackPlayer再生再開を追加 |

---

## テスト項目

| レイヤー | テスト内容 | 期待結果 |
|---------|-----------|----------|
| Interruption | 電話着信→切る | 音が自動で戻る |
| Session Lifecycle | 他アプリ→戻る | 音が継続 |
| Playback Graph | Bluetooth接続/切断 | 音が継続 |

---

## 教訓

1. **iOSオーディオには3つの独立したライフサイクルがある**
   - Interruption / Session Lifecycle / Playback Graph
   - これらを混同すると不整合が発生する

2. **中断ハンドリングは一箇所で一元管理すべき**
   - 複数箇所で監視すると競合状態になる
   - 状態（isPlaying等）との不整合が発生する

3. **エンジンとノードは別ライフサイクル**
   - `engine.start()` だけでは `playerNode` は再開しない
   - 明示的に `node.play()` を呼ぶ必要がある

---

## 関連ドキュメント

- `trouble-audio-distortion-noise.md` - オーディオ歪み問題のRCA
- `trouble-audio-no-sound-silent-switch.md` - サイレントスイッチ問題
- `architecture/audio-system-spec.md` - オーディオシステム仕様
