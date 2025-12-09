# Now Playing Implementation Guide

**Version**: 1.0
**Status**: Production
**Last Updated**: 2025-11-24
**Related Tags**: `audio-phase3-integration-complete`, `now-playing-lock-screen`

---

## 1. 概要

### 1.1 Now Playingとは

**Now Playing**は、iOSのロック画面とコントロールセンターに音楽/オーディオの再生情報と操作ボタンを表示する標準機能です。

**主要コンポーネント**:
- **MPNowPlayingInfoCenter**: メタデータ（曲名、アーティスト、アートワーク）の管理
- **MPRemoteCommandCenter**: 再生/一時停止/停止などのコマンドハンドラ登録

### 1.2 なぜLive Activityではなくこれを選んだのか

**判断理由**:
1. **操作が最優先**: ロック画面で直接再生/一時停止できることが重要
2. **ユーザーの混乱を回避**: Live ActivityとNow Playingが同時表示されると混乱
3. **実装のシンプルさ**: Widget Extension不要、1ファイル168行で完結
4. **標準UIの利点**: ユーザーは既に慣れている（Musicアプリと同じ）

**Live Activityとの比較**:

| 機能 | Now Playing | Live Activity |
|------|-------------|---------------|
| ロック画面コントロール | ✅ Play/Pause/Stop | ❌ 状態表示のみ |
| コントロールセンター | ✅ 完全なコントロール | ❌ 非対応 |
| Dynamic Island | ❌ 非対応 | ✅ Compact/Expanded |
| Bluetoothヘッドセット | ✅ ハードウェアボタン対応 | ❌ 操作不可 |
| 実装の複雑さ | 低（1ファイル、168行） | 高（Widget Extension必要） |
| テスト | シミュレータ可 | 実機必須 |

**結論**: オーディオ再生アプリでは、**操作 > 状態表示**。Now Playingがより良いUX。

### 1.3 コンポーネント構成

```
AudioService (singleton)
└── NowPlayingController
    ├── MPNowPlayingInfoCenter (メタデータ管理)
    └── MPRemoteCommandCenter (コマンドハンドラ)
```

**ファイル**:
- `/Core/Services/NowPlaying/NowPlayingController.swift` (168行) - Now Playing実装
- `/Core/Audio/AudioService.swift` - 統合ポイント

---

## 2. アーキテクチャ

### 2.1 NowPlayingControllerの設計パターン

**スレッドセーフティモデル**:
```swift
@MainActor
public final class NowPlayingController {
    // nonisolated(unsafe): MPRemoteCommandCenterハンドラは
    // バックグラウンドスレッドで実行されるため
    nonisolated(unsafe) private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

    // ターゲット保持（ARCによる解放を防止）
    nonisolated(unsafe) private var playTarget: Any?
    nonisolated(unsafe) private var pauseTarget: Any?
    nonisolated(unsafe) private var stopTarget: Any?
    nonisolated(unsafe) private var togglePlayPauseTarget: Any?
}
```

**Public API**:
- `updateNowPlaying(title:artist:album:artwork:duration:elapsedTime:)` - メタデータ更新
- `updatePlaybackState(isPlaying:)` - 再生/一時停止状態の更新
- `clearNowPlaying()` - 情報をクリア
- `setupRemoteCommands(onPlay:onPause:onStop:)` - コマンドハンドラ登録
- `disableRemoteCommands()` - クリーンアップ

### 2.2 AudioServiceとの統合ポイント

**セットアップライフサイクル**:
```
AudioService.init()
  → activateAudioSession() [重要: setupRemoteCommandsの前に実行]
  → setupCallbacks()
  → setupNowPlayingCommands()
     → nowPlayingController?.setupRemoteCommands(onPlay:onPause:onStop:)
```

**更新ポイント**:
- `play(preset:)` → `updateNowPlaying()` + `updateNowPlayingState()`
- `pause(reason:)` → `updateNowPlayingState()`
- `resume()` → `updateNowPlayingState()`
- `stop()` → `clearNowPlaying()`

### 2.3 スレッドセーフティモデル

**重要な原則**:
1. **MPRemoteCommandCenterハンドラはバックグラウンドスレッドで実行される**
2. **AudioServiceは@MainActor** - UIと密結合のため
3. **解決策**: `Task { @MainActor }` でバックグラウンド → メインアクターにディスパッチ

**実装パターン**:
```swift
// NowPlayingController: nonisolated（ハンドラがバックグラウンドで実行）
nonisolated public func setupRemoteCommands(
    onPlay: @escaping () -> Void,
    onPause: @escaping () -> Void,
    onStop: @escaping () -> Void
) { ... }

// AudioService: Task { @MainActor } でラップ
nowPlayingController?.setupRemoteCommands(
    onPlay: { [weak self] in
        guard let self = self else { return }
        Task { @MainActor in  // ← これが重要
            guard let preset = self.currentPreset else { return }
            try? self.play(preset: preset)
        }
    }
)
```

---

## 3. 実装手順

### 3.1 Audio Sessionのセットアップ（最重要）

**原則**: "Session First, Format Next, Configure Before Start"

#### セッションの有効化タイミング

**重要**: `setupRemoteCommands()`の**前に**audio sessionを有効化すること。

```swift
// AudioService.init() - Line 172-181
do {
    try activateAudioSession()
    sessionActivated = true
    print("✅ [AudioService] Audio session activated in init for remote commands")
} catch {
    print("⚠️ [AudioService] Failed to activate session in init: \(error)")
    // Continue anyway - will retry on first play()
}

// この後でsetupNowPlayingCommands()を呼ぶ
setupCallbacks()
setupInterruptionHandling()
setupBreakSchedulerCallbacks()
setupNowPlayingCommands()  // ← sessionが有効化された後
```

#### カテゴリ設定

**重要**: `.mixWithOthers`オプションを**使わない**こと。

```swift
// AudioService.swift - Line 732-766
private func activateAudioSession() throws {
    let session = AVAudioSession.sharedInstance()

    // Note: .mixWithOthers removed to enable lock screen controls
    // Lock screen controls require exclusive audio session
    try session.setCategory(.playback, mode: .default, options: [])
    try session.setActive(true, options: [])
}
```

**なぜ`.mixWithOthers`がダメなのか**:
- このオプションは「他のオーディオと混ざっても良い」という意味
- iOSは「このアプリは再生制御が重要ではない」と判断
- 結果: ロック画面コントロールが表示されない

#### 操作の順序

```
1. AVAudioSession.setCategory(.playback)
2. AVAudioSession.setActive(true)
3. MPRemoteCommandCenter.shared().playCommand.addTarget { ... }
4. 最初のaudio再生
```

この順序を守らないと、ロック画面コントロールが表示されない。

### 3.2 Remote Commandsの登録

#### コマンドハンドラの登録方法

```swift
// NowPlayingController.swift - Line 102-156
nonisolated public func setupRemoteCommands(
    onPlay: @escaping () -> Void,
    onPause: @escaping () -> Void,
    onStop: @escaping () -> Void
) {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Play コマンド - ターゲットを保持
    commandCenter.playCommand.isEnabled = true
    playTarget = commandCenter.playCommand.addTarget { _ in
        onPlay()
        return .success
    }

    // Pause コマンド - ターゲットを保持
    commandCenter.pauseCommand.isEnabled = true
    pauseTarget = commandCenter.pauseCommand.addTarget { _ in
        onPause()
        return .success
    }

    // Stop コマンド - ターゲットを保持
    commandCenter.stopCommand.isEnabled = true
    stopTarget = commandCenter.stopCommand.addTarget { _ in
        onStop()
        return .success
    }

    // Toggle play/pause command (ロック画面の単一ボタン)
    commandCenter.togglePlayPauseCommand.isEnabled = true
    togglePlayPauseTarget = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
        guard let strongSelf = self else {
            return .commandFailed
        }

        // 現在の再生レートを取得
        let currentRate = strongSelf.nowPlayingInfoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0

        if currentRate > 0.0 {
            // 再生中 → 停止
            onPause()
        } else {
            // 停止中 → 再生
            onPlay()
        }

        return .success
    }

    // スキップコマンドは無効化（音声ドローンには不要）
    commandCenter.nextTrackCommand.isEnabled = false
    commandCenter.previousTrackCommand.isEnabled = false
    commandCenter.skipForwardCommand.isEnabled = false
    commandCenter.skipBackwardCommand.isEnabled = false
}
```

#### ターゲット保持パターン（重要）

**問題**: `addTarget()`の戻り値を保持しないと、ARCがハンドラを解放してしまう。

**解決策**: インスタンスプロパティとしてターゲットを保持:
```swift
// NowPlayingController.swift - Line 21-26
nonisolated(unsafe) private var playTarget: Any?
nonisolated(unsafe) private var pauseTarget: Any?
nonisolated(unsafe) private var stopTarget: Any?
nonisolated(unsafe) private var togglePlayPauseTarget: Any?
```

**なぜ`nonisolated(unsafe)`が必要なのか**:
- `MPRemoteCommandCenter`ハンドラはバックグラウンドスレッドで実行される
- `@MainActor`プロパティにはバックグラウンドからアクセスできない
- `nonisolated(unsafe)`でコンパイラに「スレッドセーフは自分で保証する」と伝える

#### togglePlayPauseCommandの実装

**なぜ必要なのか**:
- ロック画面は**単一のトグルボタン**を表示（別々のplay/pauseボタンではない）
- `playCommand`/`pauseCommand`だけでは不十分

**実装方法**:
```swift
// NowPlayingController.swift - Line 130-149
togglePlayPauseTarget = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
    guard let strongSelf = self else {
        return .commandFailed
    }

    // 現在の再生レートを取得（1.0 = 再生中、0.0 = 停止中）
    let currentRate = strongSelf.nowPlayingInfoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0

    if currentRate > 0.0 {
        // 再生中 → 停止
        onPause()
    } else {
        // 停止中 → 再生
        onPlay()
    }

    return .success
}
```

**ポイント**: `MPNowPlayingInfoPropertyPlaybackRate`を読んで現在の状態を判定。

### 3.3 メタデータ管理

#### Now Playing情報の更新

```swift
// AudioService.swift - Line 966-987
private func updateNowPlaying() {
    guard let preset = currentPreset else {
        nowPlayingController?.clearNowPlaying()
        return
    }

    let title = "\(preset)"  // enumを文字列に変換
    nowPlayingController?.updateNowPlaying(
        title: title,
        artist: "TsukiSound",
        album: "Natural Sound Drones",
        artwork: nil,  // TODO: アプリアイコンまたはプリセット固有のアートワーク
        duration: nil, // 無限再生なのでnil
        elapsedTime: 0
    )
}
```

#### 再生状態の同期

```swift
// AudioService.swift
private func updateNowPlayingState() {
    nowPlayingController?.updatePlaybackState(isPlaying: isPlaying)
}

// NowPlayingController.swift - Line 76-87
public func updatePlaybackState(isPlaying: Bool) {
    guard var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo else {
        return
    }

    // 再生レート: 1.0 = 再生中, 0.0 = 一時停止
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

    nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
}
```

**重要**: `playbackRate`を正しく設定しないと、ロック画面コントロールが正しく動作しない。

#### アートワークの扱い

```swift
// NowPlayingController.swift - Line 59-63
if let artwork = artwork {
    let artworkImage = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
    nowPlayingInfo[MPMediaItemPropertyArtwork] = artworkImage
}
```

**実装済み（2025-12-09）**: `UISoundPreset.artworkImage` で絵文字から画像を生成し、Now Playing に設定。

```swift
// UISoundPreset.swift
public var artworkImage: UIImage? {
    let size = CGSize(width: 300, height: 300)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        UIColor(white: 0.1, alpha: 1.0).setFill()
        context.fill(CGRect(origin: .zero, size: size))
        let emoji = icon as NSString
        let font = UIFont.systemFont(ofSize: 180)
        // ... 絵文字を中央に描画
    }
}

// AudioService.swift - updateNowPlaying()
nowPlayingController?.updateNowPlaying(
    title: preset.englishTitle,
    artist: "TsukiSound",
    album: "Natural Sound Drones",
    artwork: preset.artworkImage,  // 絵文字画像を設定
    duration: nil,
    elapsedTime: 0
)
```

これにより、ダイナミックアイランドの Now Playing 表示でスピーカーマークの代わりに絵文字アイコン（🪐 / 🌖）が表示される。

### 3.4 AudioServiceとの統合

#### ライフサイクルセットアップ

```swift
// AudioService.swift - Line 672-694
private func setupNowPlayingCommands() {
    nowPlayingController?.setupRemoteCommands(
        onPlay: { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                guard let preset = self.currentPreset else { return }
                try? self.play(preset: preset)
            }
        },
        onPause: { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.pause(reason: .user)
            }
        },
        onStop: { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.stop()
            }
        }
    )
}
```

**ポイント**:
- `[weak self]` でretain cycleを防止
- `Task { @MainActor }` でバックグラウンドスレッド → メインアクターにディスパッチ
- `guard let self` でnilチェック（main actor dispatchの前に実行）

#### 更新ポイント

```swift
// play(preset:)
public func play(preset: UISoundPreset) throws {
    // ... 再生処理 ...

    isPlaying = true
    currentPreset = preset

    // Now Playing更新
    updateNowPlaying()
    updateNowPlayingState()
}

// pause(reason:)
public func pause(reason: PauseReason) {
    // ... 停止処理 ...

    isPlaying = false
    pauseReason = reason

    // 状態のみ更新
    updateNowPlayingState()
}

// stop()
public func stop() {
    // ... 停止処理 ...

    isPlaying = false
    currentPreset = nil

    // Now Playingをクリア
    nowPlayingController?.clearNowPlaying()
}
```

#### エラーハンドリング

現在の実装では、Now Playing関連のエラーは無視しています（オーディオ再生自体には影響しないため）:
```swift
try? self.play(preset: preset)  // エラーは無視
```

将来的にログ記録やユーザー通知を追加する場合は、この部分を拡張してください。

---

## 4. 実装で苦労した点と解決策

### 4.1 ロック画面コントロールが表示されない問題

**問題**: Now Playingカードは表示されるが、ボタンが機能しない。タップするとアプリが開くだけ。

**症状**:
- ロック画面にNow Playingカードが表示される
- Play/pauseボタンが見えるが、タップしても反応しない
- 再生状態が変わらない

**根本原因**:
`.mixWithOthers`オプションがiOSにロック画面コントロールを無効化させていた。

このオプションは「このアプリのオーディオは他のオーディオと混ざっても良い」という意味で、iOSは「再生制御が重要ではない」と判断してしまう。

**解決策**:
```swift
// ❌ これだと動かない
try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])

// ✅ これで動く
try session.setCategory(.playback, mode: .default, options: [])
```

排他的な`.playback`カテゴリにすることで、iOSに「このアプリは再生制御が重要」と伝える。

**コミット**: 41fbb92
**ファイル**: AudioService.swift:746-749

**教訓**: ロック画面コントロールが必要な場合、`.mixWithOthers`は使わない。

---

### 4.2 Audio Sessionの有効化タイミング問題

**問題**: MPRemoteCommandCenterがハンドラを正しく登録できない。

**症状**:
- ロック画面コントロールが時々表示されない
- ハンドラが呼ばれない（ログが出ない）

**根本原因**:
Remote commands設定**前に**audio sessionが有効化されていなかった。

MPRemoteCommandCenterは、audio sessionが有効な状態でないと、ロック画面コントロールを正しく登録できない。

**解決策**:
`init()`で最初にsessionを有効化:

```swift
// AudioService.init() - Line 172-181
do {
    try activateAudioSession()
    sessionActivated = true
    print("✅ [AudioService] Audio session activated in init for remote commands")
} catch {
    print("⚠️ [AudioService] Failed to activate session in init: \(error)")
    // Continue anyway - will retry on first play()
}

// この後でsetupNowPlayingCommands()
setupCallbacks()
setupInterruptionHandling()
setupBreakSchedulerCallbacks()
setupNowPlayingCommands()  // ← sessionが有効化された後
```

**確立された原則**: "Session First, Format Next, Configure Before Start"

**コミット**: 41fbb92
**ファイル**: AudioService.swift:172-188

**教訓**: audio sessionの有効化は、**何よりも先に**実行する。

---

### 4.3 コマンドターゲットの解放問題

**問題**: しばらく使っているとロック画面コントロールが反応しなくなる。

**症状**:
- 最初は動作する
- 数分後、ロック画面ボタンをタップしても反応しない
- クラッシュやエラーログは無し

**根本原因**:
`addTarget()`の戻り値を保持していなかったため、ARCがハンドラクロージャを解放してしまった。

`MPRemoteCommand.addTarget()`は**弱参照**を返すため、保持しないとすぐに解放される。

**解決策**:
インスタンスプロパティとしてターゲットを保持:

```swift
// NowPlayingController.swift - Line 21-26
nonisolated(unsafe) private var playTarget: Any?
nonisolated(unsafe) private var pauseTarget: Any?
nonisolated(unsafe) private var stopTarget: Any?
nonisolated(unsafe) private var togglePlayPauseTarget: Any?

// 登録時 - Line 111-114
playTarget = commandCenter.playCommand.addTarget { _ in
    onPlay()
    return .success
}
```

**なぜ`nonisolated(unsafe)`が必要なのか**:
- ハンドラクロージャはバックグラウンドスレッドで実行される
- `@MainActor`プロパティにはバックグラウンドからアクセスできない
- `nonisolated(unsafe)`で「スレッドセーフは自分で保証する」と宣言

**コミット**: 41fbb92
**ファイル**: NowPlayingController.swift:21-26, 111-149

**教訓**: `addTarget()`の戻り値は**必ず**保持する。

---

### 4.4 Swift Concurrency / MainActor問題

**問題**: MPRemoteCommandCenterのハンドラがバックグラウンドスレッドで実行される。

**症状**:
- Swift 6 concurrency警告が大量に出る
- "Call to main actor-isolated method from nonisolated context" エラー
- 実行時にスレッド関連のクラッシュ

**根本原因**:
AudioServiceは`@MainActor`（UIと密結合のため）だが、MPRemoteCommandCenterのハンドラはバックグラウンドスレッドで実行される。

バックグラウンドスレッドから直接`@MainActor`メソッドを呼ぶことはできない。

**解決策**:
`Task { @MainActor }` でラップ:

```swift
// AudioService.swift - Line 673-694
nowPlayingController?.setupRemoteCommands(
    onPlay: { [weak self] in
        guard let self = self else { return }
        Task { @MainActor in  // ← これが重要
            guard let preset = self.currentPreset else { return }
            try? self.play(preset: preset)
        }
    },
    onPause: { [weak self] in
        guard let self = self else { return }
        Task { @MainActor in  // ← これが重要
            self.pause(reason: .user)
        }
    },
    onStop: { [weak self] in
        guard let self = self else { return }
        Task { @MainActor in  // ← これが重要
            self.stop()
        }
    }
)
```

**パターン**:
1. `[weak self]` でretain cycleを防止
2. `guard let self` でnilチェック（main actor dispatchの**前に**実行）
3. `Task { @MainActor }` でメインアクターにディスパッチ
4. main actor内で`@MainActor`メソッドを呼ぶ

**コミット**: 41fbb92
**ファイル**: AudioService.swift:673-694, NowPlayingController.swift:102

**教訓**: バックグラウンドスレッドから`@MainActor`メソッドを呼ぶ場合は、`Task { @MainActor }` でラップする。

---

### 4.5 togglePlayPauseCommandの実装

**問題**: ロック画面は単一のトグルボタン、play/pauseの2つのボタンではない。

**症状**:
- 最初の実装では`playCommand`と`pauseCommand`のみ実装
- ロック画面ボタンをタップしても何も起きない
- または、常に再生が呼ばれる（停止中でも）

**根本原因**:
iOSのロック画面は`togglePlayPauseCommand`を使用する（別々のplay/pauseボタンではない）。

現在の状態を判定して、適切なアクションを呼ぶ必要がある。

**解決策**:
現在のplaybackRateを読んで判定:

```swift
// NowPlayingController.swift - Line 130-149
commandCenter.togglePlayPauseCommand.isEnabled = true
togglePlayPauseTarget = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
    guard let strongSelf = self else {
        return .commandFailed
    }

    // 現在の再生レートを取得（1.0 = 再生中、0.0 = 停止中）
    let currentRate = strongSelf.nowPlayingInfoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0

    if currentRate > 0.0 {
        onPause()  // 再生中 → 停止
    } else {
        onPlay()   // 停止中 → 再生
    }

    return .success
}
```

**ポイント**:
- `MPNowPlayingInfoPropertyPlaybackRate`を読む（1.0 = 再生中、0.0 = 停止中）
- 再生中なら`onPause()`、停止中なら`onPlay()`を呼ぶ
- `[weak self]`とstrong self patternでメモリ管理

**コミット**: 41fbb92
**ファイル**: NowPlayingController.swift:130-149

**教訓**: ロック画面用には`togglePlayPauseCommand`の実装が必須。

---

### 4.6 Live ActivityとNow Playingの混在問題

**問題**: ロック画面に2つのUI（Live Activity + Now Playing）が同時表示され、混乱。

**症状**:
- ロック画面にDynamic Island（Live Activity）とNow Playingカードが両方表示される
- Live Activityはタップしてもアプリが開くだけ（操作不可）
- Now Playingは再生/一時停止ボタンが機能する
- ユーザーがどちらを使えば良いか分からない

**根本原因**:
Live Activityは**状態表示のみ**（操作不可）、Now Playingは**操作可能**。

両方が同時に表示されると、役割が重複して混乱を招く。

**解決策**:
Live Activityを無効化:

```swift
// AudioService.swift - Line 294-296, 367-368, 442-444, 483-485, 527-529, 578-579
// Phase 3: Live Activityを更新
// Disabled: Now Playing provides sufficient lock screen integration
// updateLiveActivity()

// Phase 3: Live Activityを終了
// Disabled: Now Playing provides sufficient lock screen integration
// endLiveActivity()
```

**判断理由**（commit 849d506より）:
- ロック画面での**直接操作が最重要**
- Live Activityは「情報ビュー」に過ぎない（ボタンが無い）
- Now Playingで十分な機能を提供できる

**代替案を検討しなかった理由**:
- Live Activityに操作ボタンを追加することは可能だが、深いリンク実装が必要
- Now Playingの方がシンプルで標準的
- ユーザーは既にNow Playing UIに慣れている（Musicアプリなど）

**コミット**: 41fbb92（無効化）, 849d506（ドキュメント化）
**ファイル**: AudioService.swift:294-296他、docs/LiveActivity-Setup-Guide.md

**教訓**: オーディオ再生アプリでは、**操作 > 状態表示**。役割が重複する場合は統合する。

---

## 5. ベストプラクティス

### 5.1 Audio Session管理

✅ **DO**:
- `init()`でsession有効化（remote commands設定**前**）
- `.playback`カテゴリを単独使用（`.mixWithOthers`無し）
- セッション有効化時に診断ログを出力
- エラー発生時も処理を継続（最初の`play()`で再試行）

❌ **DON'T**:
- session有効化前にMPRemoteCommandCenterをセットアップ
- ロック画面コントロールが必要なら`.mixWithOthers`を使用
- sessionが有効と仮定（常に確認）
- セッション有効化失敗で即座にクラッシュ

**理由**: audio sessionの状態がNow Playing機能の前提条件。

### 5.2 コマンドターゲット管理

✅ **DO**:
- ターゲットをインスタンスプロパティに保持
- バックグラウンドスレッドアクセスには`nonisolated(unsafe)`
- `togglePlayPauseCommand`を実装
- 不要なコマンド（next/previous track）を無効化
- すべてのターゲットを`Any?`型で保持

❌ **DON'T**:
- `addTarget()`の戻り値を破棄
- ハンドラがメインスレッドで実行されると仮定
- play/pauseコマンドのみ実装（toggleが無いと動かない）
- すべてのコマンドを有効化（混乱を招く）

**理由**: ターゲット保持がハンドラのライフタイム管理の鍵。

### 5.3 Swift Concurrencyパターン

✅ **DO**:
- remote command setupを`nonisolated`にマーク
- バックグラウンドからmain actor呼び出し時は`Task { @MainActor }`でラップ
- `[weak self]`でretain cycleを防止
- main actor dispatchの**前に**nil check
- Swift 6 concurrency警告をすべて解決

❌ **DON'T**:
- バックグラウンドスレッドから直接`@MainActor`メソッドを呼ぶ
- クロージャ内のweak self参照を忘れる
- `guard let self`の後で`Task { @MainActor }`（順序が逆）
- concurrency警告を無視（将来的に実行時エラーになる）

**理由**: スレッド安全性はNow Playing実装の基盤。

### 5.4 状態管理

✅ **DO**:
- `MPNowPlayingInfoPropertyPlaybackRate`を常に更新
- playback rateを読んで現在の状態を判定（toggleコマンド内）
- 停止時に`clearNowPlaying()`でクリア
- すべての状態変化（play/pause/resume/stop）で更新
- メタデータ（title, artist）を適切に設定

❌ **DON'T**:
- ロック画面UIが自動更新されると仮定
- playback rateの更新を忘れる（コントロールが動かなくなる）
- 停止後に古いNow Playing情報を放置
- 状態変化の一部でのみ更新（不整合が発生）

**理由**: playback rateがiOSの判断基準。

### 5.5 UX設計原則

✅ **DO**:
- 再生制御が必要ならNow Playingを選ぶ
- メタデータはシンプルかつ明確に（title, artist, album）
- 実機でテスト（ロック画面挙動はシミュレータと異なる）
- Bluetoothヘッドセットでもテスト
- アートワークを追加してビジュアルを改善（オプション）

❌ **DON'T**:
- ロック画面でLive ActivityとNow Playingを混在（混乱）
- 操作不可のLive Activityを表示
- シミュレータでのテスト結果を信頼
- 長すぎるタイトル（ロック画面で切れる）

**理由**: Now Playingは標準的なUXパターン、逸脱すると混乱。

---

## 6. よくある落とし穴

### 6.1 「ロック画面コントロールが表示されない」

**チェックリスト**:
- [ ] `setupRemoteCommands()`前にaudio sessionを有効化したか？
- [ ] audio session categoryは`.playback`で`.mixWithOthers`**無し**か？
- [ ] コマンドターゲットをインスタンスプロパティに保存したか？
- [ ] `togglePlayPauseCommand`を有効化して実装したか？
- [ ] 実機でテストしたか？（シミュレータは不完全）

**デバッグ手順**:
1. audio session有効化のログを確認
2. `setupRemoteCommands()`の呼び出しタイミングを確認
3. `.mixWithOthers`が含まれていないか確認
4. 実機で再度テスト

### 6.2 「コントロールは表示されるが動かない」

**チェックリスト**:
- [ ] コマンドターゲットが保持されているか（解放されていないか）？
- [ ] ハンドラが`Task { @MainActor }`でラップされているか？
- [ ] `MPNowPlayingInfoPropertyPlaybackRate`を更新しているか？
- [ ] `togglePlayPauseCommand`が現在のrateを正しく読んでいるか？
- [ ] ハンドラ内で`return .success`しているか？

**デバッグ手順**:
1. ハンドラ内にprintログを追加
2. ログが出ない → ターゲットが解放されている
3. ログは出るが動かない → スレッド問題またはplayback rate未更新

### 6.3 「コントロール使用時にクラッシュ」

**チェックリスト**:
- [ ] すべての`@MainActor`呼び出しが適切にラップされているか？
- [ ] クロージャで`[weak self]`を使っているか？
- [ ] main actor dispatchの**前に**guard文があるか？
- [ ] concurrency警告に対処したか？
- [ ] retain cycleが無いか確認したか？

**デバッグ手順**:
1. クラッシュログからスレッド情報を確認
2. "Main actor-isolated" エラーの場合 → `Task { @MainActor }` 不足
3. "nil" エラーの場合 → `[weak self]` + guard不足

### 6.4 「Now Playing情報が古いまたは不正確」

**チェックリスト**:
- [ ] `updateNowPlaying()`をplay時に呼んでいるか？
- [ ] `updatePlaybackState()`をpause/resume時に呼んでいるか？
- [ ] `clearNowPlaying()`をstop時に呼んでいるか？
- [ ] playback rateが正しく設定されているか（1.0/0.0）？
- [ ] メタデータ（title, artist）が最新か？

**デバッグ手順**:
1. 各更新ポイントにログを追加
2. ロック画面の表示とログを照らし合わせ
3. playback rateの値を確認（1.0 = 再生、0.0 = 停止）

### 6.5 「Live ActivityとNow Playingの混乱」

**判断フレームワーク**:

**Now Playingを使うべき場合**:
- 再生制御（play/pause/stopボタン）が必要
- 標準的な音楽/オーディオアプリ
- Bluetoothヘッドセット対応が必要
- シンプルな実装で十分

**Live Activityを使うべき場合**:
- 状態表示のみ（操作不要）
- Dynamic Islandでのビジュアル表現が重要
- タイマーや進捗表示が主目的
- Now Playingとの競合が無い

**両方を使わない**:
- ロック画面で機能が重複する場合
- ユーザーの混乱を招く場合
- どちらか一方で十分な場合

---

## 7. テストチェックリスト

### 基本機能
- [ ] Audio sessionがコマンド設定前に有効化される
- [ ] ロック画面コントロールが表示される
- [ ] Play/pauseボタンが正しく機能する
- [ ] Stop機能が動作する（該当する場合）
- [ ] メタデータ（title, artist）が正しく表示される

### 統合
- [ ] コントロールセンター統合が動作する
- [ ] Bluetoothヘッドセットボタンが動作する
- [ ] CarPlay統合が動作する（該当する場合）
- [ ] Airpodsのタップ操作が動作する

### 状態管理
- [ ] 再生中にロック → コントロールが表示される
- [ ] 停止中にロック → 情報がクリアされている
- [ ] 一時停止 → 再開が正しく動作する
- [ ] アプリ切り替え後も状態が保持される

### エッジケース
- [ ] アプリ起動直後の挙動
- [ ] バックグラウンド復帰後の挙動
- [ ] 割り込み（電話など）後の復帰
- [ ] ヘッドホン抜き差し時の挙動

### コード品質
- [ ] Swift 6 concurrency警告が無い
- [ ] メモリリークが無い（Instrumentsで確認）
- [ ] クラッシュが無い（様々な操作順序で）
- [ ] ログが適切に出力される

### デバイステスト
- [ ] 実機でテスト（iPhoneシリーズ）
- [ ] Bluetoothヘッドセットでテスト
- [ ] Airpodsでテスト
- [ ] CarPlayでテスト（該当する場合）

**重要**: シミュレータはロック画面挙動を正確に再現しない。**必ず実機でテスト**。

---

## 8. コードリファレンス

### 8.1 主要ファイル

**NowPlayingController.swift** (168行)
- `/Users/mypc/AI_develop/TsukiSound/TsukiSound/Core/Services/NowPlaying/NowPlayingController.swift`
- 作成日: 2025-11-11
- 最終更新: 2025-11-24

**AudioService.swift** (Now Playing関連部分)
- Line 111: `private var nowPlayingController: NowPlayingController?`
- Line 164: `nowPlayingController = NowPlayingController()`
- Line 172-188: Session初期化（**最重要**）
- Line 672-694: Remote commands統合
- Line 966-987: メタデータ更新

### 8.2 重要なコードスニペット

**Audio Session Configuration** (AudioService.swift:732-766)
```swift
private func activateAudioSession() throws {
    let session = AVAudioSession.sharedInstance()

    // Note: .mixWithOthers removed to enable lock screen controls
    try session.setCategory(.playback, mode: .default, options: [])
    try session.setActive(true, options: [])
}
```

**Remote Command Setup** (NowPlayingController.swift:102-156)
```swift
nonisolated public func setupRemoteCommands(
    onPlay: @escaping () -> Void,
    onPause: @escaping () -> Void,
    onStop: @escaping () -> Void
) {
    let commandCenter = MPRemoteCommandCenter.shared()

    playTarget = commandCenter.playCommand.addTarget { _ in
        onPlay()
        return .success
    }
    // ... (pause, stop, toggle)
}
```

**Thread-Safe Integration** (AudioService.swift:673-694)
```swift
private func setupNowPlayingCommands() {
    nowPlayingController?.setupRemoteCommands(
        onPlay: { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                guard let preset = self.currentPreset else { return }
                try? self.play(preset: preset)
            }
        },
        // ... (pause, stop)
    )
}
```

### 8.3 関連コミット

**Phase 3初期実装**:
- `fbd821e` - "feat: implement Phase 3 audio features"
  - NowPlayingController初期実装
  - Date: 2025-11-11

**ロック画面コントロール修正（最重要）**:
- `41fbb92` - "fix: enable lock screen playback controls and clean up Now Playing integration"
  - `.mixWithOthers`削除
  - Early session activation
  - Thread safety annotations
  - Target retention
  - `togglePlayPauseCommand`実装
  - Live Activity無効化
  - Date: 2025-11-24

**ドキュメント化**:
- `849d506` - "docs: add deprecation notice to Live Activity setup guide"
  - Live Activity廃止理由の文書化
  - Date: 2025-11-24

- `bb13c92` - "docs: convert file paths to clickable relative links"
  - ドキュメントリンク改善
  - Date: 2025-11-24

---

## 9. 関連ドキュメント

### アーキテクチャ
- [Audio System Specification](../architecture/_arch-audio-system-spec.md) - オーディオシステム全体の設計
- [Phase 3 Integration Report](../report/report-audio-phase3-integration.md) - Phase 3実装の完全レポート

### トラブルシューティング
- [Audio Distortion/Noise Troubleshooting](../report/report-audio-distortion-noise.md) - 音声品質問題
- [Silent Switch Issues](../report/report-audio-no-sound-silent-switch.md) - 消音スイッチ問題

### 廃止された機能
- [Live Activity Setup Guide (DEPRECATED)](../../../docs/LiveActivity-Setup-Guide.md) - Live Activity実装ガイド（参考用）

### プロジェクト全体
- [CLAUDE.md](../../../CLAUDE.md) - プロジェクトガイド
- [Documentation Index](../README.md) - ドキュメント索引

---

## 10. まとめ

### 10.1 Now Playingの利点

**技術的利点**:
- シンプルな実装（1ファイル、168行）
- Widget Extension不要
- シミュレータでテスト可能
- 標準的なiOS API

**UX利点**:
- ユーザーが既に慣れているUI（Musicアプリと同じ）
- ロック画面で直接操作可能
- Bluetoothヘッドセット対応
- コントロールセンター統合

**保守性の利点**:
- Appleの標準APIに依存
- OSアップデートで自動改善
- ドキュメントが豊富
- コミュニティサポートが充実

### 10.2 重要な教訓

1. **Audio session first**: remote commands設定の**前に**sessionを有効化
2. **No .mixWithOthers**: ロック画面コントロールには排他的`.playback`
3. **Retain targets**: `addTarget()`の戻り値を必ず保持
4. **Thread safety**: `Task { @MainActor }` でバックグラウンド → main actor
5. **togglePlayPauseCommand**: ロック画面用に必須実装
6. **One control surface**: Live ActivityとNow Playingの混在を避ける

### 10.3 次のステップ

**短期的改善**:
- [x] アートワーク追加（アプリアイコンまたはプリセット固有） ✅ 2025-12-09 完了
- [ ] 経過時間の表示（長時間再生の場合）
- [ ] エラーハンドリングの強化

**長期的改善**:
- [ ] CarPlay統合
- [ ] Siri統合（"Hey Siri, play soft organ"）
- [ ] Apple Watch対応
- [ ] ウィジェット追加

**モニタリング**:
- [ ] クラッシュレポートの監視
- [ ] ユーザーフィードバックの収集
- [ ] パフォーマンスメトリクスの追跡

---

## 11. 付録

### 11.1 トラブルシューティングフローチャート

```
ロック画面コントロールが表示されない
  ↓
Audio sessionは有効化されているか？
  NO → init()でactivateAudioSession()を呼ぶ
  ↓
  YES → .mixWithOthersを使っているか？
    YES → options: []に変更
    ↓
    NO → togglePlayPauseCommandは実装されているか？
      NO → 実装する（Section 3.2参照）
      ↓
      YES → 実機でテストしたか？
        NO → 実機でテスト（シミュレータは不完全）
        ↓
        YES → この時点で解決しない場合は、
              サポートに連絡（ログを添付）
```

### 11.2 技術用語集

**MPNowPlayingInfoCenter**: Now Playing情報（メタデータ）を管理するシングルトン

**MPRemoteCommandCenter**: リモートコマンド（play/pause/stop）を管理するシングルトン

**togglePlayPauseCommand**: ロック画面の単一トグルボタン用コマンド

**nonisolated(unsafe)**: Swift Concurrencyで「この要素はactor isolationの外にある」と宣言

**@MainActor**: メインスレッドで実行されるべきことを示すSwift Concurrency annotation

**Task { @MainActor }**: バックグラウンドスレッドからメインアクターにディスパッチ

**playbackRate**: 再生速度（1.0 = 再生中、0.0 = 停止中）

**.mixWithOthers**: 他のオーディオと混合可能なaudio sessionオプション（ロック画面コントロールを無効化）

### 11.3 Apple公式リファレンス

- [MPNowPlayingInfoCenter | Apple Developer](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)
- [MPRemoteCommandCenter | Apple Developer](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter)
- [AVAudioSession | Apple Developer](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Becoming a Now Playable App](https://developer.apple.com/documentation/avfoundation/media_playback/becoming_a_now_playable_app)

---

**Document Version**: 1.1
**Last Updated**: 2025-12-09
**Maintained By**: Claude Code
**Status**: Production-ready
