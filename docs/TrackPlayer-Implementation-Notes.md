# TrackPlayer 実装ノート

音源ファイル再生（TrackPlayer）の実装で遭遇した問題と解決策のまとめです。

---

## 目次

1. [概要](#概要)
2. [アーキテクチャ](#アーキテクチャ)
3. [重大バグと解決策](#重大バグと解決策)
4. [ベストプラクティス](#ベストプラクティス)
5. [音源ファイル管理](#音源ファイル管理)
6. [テスト方法](#テスト方法)

---

## 概要

### TrackPlayerとは

WAV/CAFファイルを再生するための専用プレイヤー。AudioServiceの一部として統合され、合成音源（ClickSuppressionDrone等）と並行して使用できる。

### 主な機能

- WAV/CAFファイルの再生
- シームレスループ再生
- クロスフェード対応
- フェードイン/フェードアウト
- システム音量連動
- モノラル/ステレオ自動対応

### ファイル構成

```
Core/Audio/
├── Players/
│   └── TrackPlayer.swift           # ファイル再生プレイヤー
├── Presets/
│   └── AudioFilePresets.swift      # 音源プリセット定義
├── Services/Volume/
│   └── SafeVolumeLimiter.swift     # 音量制限（masterBusMixer統合）
└── AudioService.swift              # TrackPlayer統合
```

---

## アーキテクチャ

### 音声処理フロー（最終版）

```
AudioFile (WAV/CAF)
    ↓
AVAudioFile (read)
    ↓
AVAudioPCMBuffer (full file in memory)
    ↓
AVAudioPlayerNode (volume = 1.0, file native format)
    ↓
masterBusMixer (format conversion: file → 48kHz/2ch)
    ↓
SafeVolumeLimiter (48kHz/2ch, -6dB cap)
    ↓
AVAudioEngine.mainMixerNode (48kHz/2ch, Dynamic Gain Compensation)
    ↓
AVAudioEngine.outputNode (Apple auto-wiring)
    ↓
System Output (Speaker/Headphones/Bluetooth)
```

### masterBusMixerアーキテクチャの重要性

**従来の問題:**
- `mainMixer → Limiter → output`という接続がAppleの自動配線と競合
- ランタイム再構成で`-10868`エラー（クラッシュ）
- フォーマット不一致で無音

**解決策:**
```
Sources → masterBusMixer → Limiter → mainMixer → output
                                               ↑
                                    Apple自動配線を尊重
```

**利点:**
- Appleの自動配線（mainMixer→output）を妨害しない
- 全ての音源が統一された経路を通る
- フォーマット変換が明確な場所で行われる

### 重要な設計原則

1. **AVAudioSessionを先にアクティベート（最重要）**
   - セッション未アクティベートだと`outputNode.inputFormat`が44.1kHz/2chを返す
   - セッションアクティベート後は正しいデバイスフォーマット（48kHz/2ch）を返す
   - **必ずファイル再生前にもセッションをアクティベート**

2. **Limiterはエンジン起動前に構成**
   - `configure → register → start`の順序を厳守
   - エンジン起動中の再構成は絶対禁止（-10868クラッシュ）
   - 出力フォーマット（48kHz/2ch）で統一

3. **フォーマット統一の原則**
   - Limiterは常に出力フォーマット（48kHz/2ch）で構成
   - TrackPlayerはファイルのネイティブフォーマットを使用
   - masterBusMixerが自動的にフォーマット変換
   - **ファイルフォーマットでLimiterを構成してはいけない**

4. **TrackPlayerは音量調整しない**
   - `playerNode.volume = 1.0` 固定
   - マスター音量で制御（Dynamic Gain Compensation）

5. **音源の分離管理**
   - 合成音源（ClickSuppressionDrone）とファイル再生は別管理
   - `disableSources()`/`enableSources()`で制御
   - ノードはアタッチしたまま、`suspend()`/`resume()`で無音化

---

## 重大バグと解決策

### 1. AVAudioEngineランタイム再構成クラッシュ（-10868エラー）

**症状:**
```
Thread 1: "error -10868"
required condition is false: !srcNodeMixerConns.empty() && !isSrcNodeConnectedToIONode
```

**原因:**
エンジン起動**後**にLimiterを`configure()`していた。AVAudioEngineは起動中のグラフ再構成を許さない。

**間違ったコード:**
```swift
// ❌ エンジン起動後に構成（クラッシュ）
try engine.start()
volumeLimiter.configure(engine: engine.engine, format: format)  // ← -10868エラー
```

**正しいコード:**
```swift
// ✅ エンジン起動前に構成
volumeLimiter.configure(engine: engine.engine, format: outputFormat)
try engine.start()
```

**解決策の詳細:**
```swift
// SafeVolumeLimiter.swift
public func configure(engine: AVAudioEngine, format: AVAudioFormat) {
    // Idempotent check: 同じフォーマットなら何もしない
    if isConfigured, !needsRebind,
       let existing = configuredFormat,
       existing.sampleRate == format.sampleRate,
       existing.channelCount == format.channelCount {
        return
    }

    // CRITICAL: エンジン起動中は再構成を拒否
    if engine.isRunning {
        print("⚠️ [SafeVolumeLimiter] Engine is running, cannot reconfigure (would crash)")
        return
    }

    // 構成処理...
}
```

**重要ポイント:**
- **"Attach → Configure → Connect → Start"** の順序を厳守
- エンジン起動中は絶対に再構成しない
- `isConfigured`フラグで冪等性を確保

---

### 2. フォーマット不一致による無音（44.1kHz ↔ 48kHz）

**症状:**
- 再生ログは正常に出力される
- エンジンは動作している
- しかし音が全く聞こえない
- ログに`44100.0 Hz`と`48000.0 Hz`が混在

**原因:**
ファイル再生時に**AVAudioSessionをアクティベートせず**に`outputNode.inputFormat`を取得。
デフォルトで44.1kHz/2chが返され、Limiterを44.1kHzで構成。
後で合成再生時にセッションアクティベート → 48kHz/2chに変わり、フォーマット不一致が発生。

**問題の流れ:**
```
1. ファイル再生開始
   → セッション未アクティベート
   → outputNode.inputFormat → 44.1kHz/2ch（デフォルト）
   → Limiterを44.1kHzで構成

2. 合成再生に切替
   → セッションアクティベート → 48kHz/2ch
   → Limiter再構成を試みる
   → エンジン起動中 → 再構成拒否
   → 結果: 44.1kHz Limiter + 48kHzソース = 無音
```

**間違ったコード:**
```swift
// ❌ セッション未アクティベートでフォーマット取得
public func playAudioFile(_ audioFile: AudioFilePreset) throws {
    let outputFormat = engine.engine.outputNode.inputFormat(forBus: 0)  // ← 44.1kHz
    volumeLimiter.configure(engine: engine.engine, format: outputFormat)
    // ...
}
```

**正しいコード:**
```swift
// ✅ セッション先行アクティベート
public func playAudioFile(_ audioFile: AudioFilePreset) throws {
    // CRITICAL: セッションを先にアクティベート
    if !sessionActivated {
        try activateAudioSession()  // ← これで48kHz/2chになる
        sessionActivated = true
    }

    let outputFormat = engine.engine.outputNode.inputFormat(forBus: 0)  // ← 48kHz
    volumeLimiter.configure(engine: engine.engine, format: outputFormat)
    // ...
}
```

**重要ポイント:**
- **"Session First, Format Next, Configure Before Start"**
- 合成再生・ファイル再生の両方で同じ48kHz/2chフォーマットを使用
- ファイルのネイティブフォーマット（44.1kHz/1ch）はmasterBusMixerで変換

**ログの確認:**
```
// ✅ 正常（統一されている）
🔊 [SafeVolumeLimiter] Format: 48000.0 Hz, 2 channels
🎵 [AudioService] Audio file format: 44100.0 Hz, 1ch
🎵 [AudioService] Limiter configured with output format: 48000.0 Hz, 2ch

// ❌ 異常（不一致）
🔊 [SafeVolumeLimiter] Format: 44100.0 Hz, 2 channels  ← 問題！
⚠️ Engine is running, cannot reconfigure (would crash)
   Requested format: 48000.0Hz/2ch
```

---

### 3. masterBusMixer接続エラー

**症状:**
```
required condition is false: [_nodes containsObject: node1] && [_nodes containsObject: node2]
```

**原因:**
`masterBusMixer`と`limiterNode`をエンジンにアタッチする前に接続しようとした。

**解決策:**
ノードのアタッチと接続を分離。

```swift
// SafeVolumeLimiter.swift
public func attachNodes(to engine: AVAudioEngine) {
    guard !nodesAttached else { return }

    // 先にアタッチ
    engine.attach(masterBusMixer)
    engine.attach(limiterNode)

    nodesAttached = true
}

public func configure(engine: AVAudioEngine, format: AVAudioFormat) {
    // アタッチを確認
    attachNodes(to: engine)

    // その後に接続
    engine.connect(masterBusMixer, to: limiterNode, format: format)
    engine.connect(limiterNode, to: engine.mainMixerNode, format: nil)  // Auto-conversion
}
```

---

### 4. チャンネル数不一致クラッシュ（旧問題・参考）

**症状:**
```
required condition is false: _outputFormat.channelCount == buffer.format.channelCount
*** Terminating app due to uncaught exception 'com.apple.coreaudio.avfaudio'
```

**原因:**
ミキサーのステレオフォーマット（2ch）でモノラルファイル（1ch）を再生しようとした。

**解決済み:**
TrackPlayerはファイルのネイティブフォーマットを使用し、masterBusMixerで変換。

---

### 5. 音が聞こえない（playerNode.volume未設定）

**症状:**
- 再生ログは正常
- `playerNode.isPlaying` が `true`
- マスター音量も正常
- しかし音が聞こえない

**原因:**
`AVAudioPlayerNode.volume` が初期化されていなかった。

**解決済み:**
```swift
// TrackPlayer.swift
public func play(loop: Bool, crossfadeDuration: TimeInterval) {
    playerNode.volume = 1.0  // ✅ 必須
    playerNode.play()
}
```

---

### 6. 合成音源との混在問題

**症状:**
- ファイル再生時に合成音源（ClickSuppressionDrone）も鳴る
- 停止後も合成音源が鳴り続ける

**原因:**
`LocalAudioEngine.sources`配列が残り、`engine.start()`時に全て起動。

**解決済み:**
`disableSources()`/`enableSources()`メソッドで制御。

```swift
// LocalAudioEngine.swift
public func disableSources() {
    sources.forEach {
        $0.stop()
        $0.suspend()  // 無音出力 + 診断ログ停止
    }
    shouldStartSources = false
}

public func enableSources() {
    sources.forEach { $0.resume() }
    shouldStartSources = true
}
```

**重要ポイント:**
- ノードはアタッチしたまま（グラフ構造維持）
- `suspend()`で無音出力に切り替え
- 診断ログも停止

---

### 7. 停止後も音が鳴り続ける

**症状:**
- 停止ボタンを押しても音が鳴り続ける
- `ClickSuppressionDrone Diagnostics`ログが出続ける

**原因:**
`stop()`メソッドがファイル再生時にエンジンを止めていなかった。

**解決済み:**
```swift
// AudioService.swift
public func stop(fadeOut fadeOutDuration: TimeInterval = 0.5) {
    // 1) TrackPlayer停止
    if let player = trackPlayer, player.isPlaying {
        player.stop(fadeOut: playerFadeDuration)
    }

    // 2) マスターフェードアウト
    let masterFadeDuration = max(fadeOutDuration, playerFadeDuration)
    self.fadeOut(duration: masterFadeDuration)

    // 3) ALWAYS stop engine（ファイル・合成関係なく）
    DispatchQueue.main.asyncAfter(deadline: .now() + masterFadeDuration) { [weak self] in
        self?.engine.stop()
        self?.volumeLimiter.reset()
        self?.engine.disableSources()
    }
}
```

---

### 8. エラー時のUIロック

**症状:**
- クラッシュ後に再生ボタンが押せなくなる
- `isPlaying`が`true`のまま残る

**原因:**
例外発生時に状態がクリーンアップされない。

**解決済み:**
```swift
// AudioService.swift
public func play(preset: NaturalSoundPreset) throws {
    do {
        try _playInternal(preset: preset)
    } catch {
        cleanupStateOnError()  // ✅ 状態クリーンアップ
        throw error
    }
}

private func cleanupStateOnError() {
    fadeTimer?.invalidate()
    isPlaying = false
    currentPreset = nil
    currentAudioFile = nil
    if engine.isEngineRunning {
        engine.stop()
    }
    volumeLimiter.reset()
    // ...
}
```

---

## ベストプラクティス

### 1. セッション管理

```swift
// ✅ 必ず先にアクティベート
if !sessionActivated {
    try activateAudioSession()
    sessionActivated = true
}

// ✅ その後にフォーマット取得
let outputFormat = engine.engine.outputNode.inputFormat(forBus: 0)  // 48kHz/2ch
```

### 2. Limiter構成

```swift
// ✅ エンジン起動前に一度だけ
let outputFormat = engine.engine.outputNode.inputFormat(forBus: 0)
volumeLimiter.configure(engine: engine.engine, format: outputFormat)

// ✅ その後にエンジン起動
try engine.start()
```

### 3. TrackPlayer構成

```swift
// ✅ ファイルのネイティブフォーマットを使用
let file = try AVAudioFile(forReading: url)
let fileFormat = file.processingFormat  // 44.1kHz/1ch等

// ✅ masterBusMixerに接続（自動変換される）
trackPlayer?.configure(
    engine: engine.engine,
    format: fileFormat,
    destination: volumeLimiter.masterBusMixer
)
```

### 4. 音量制御

```swift
// ✅ TrackPlayerは常に最大音量
playerNode.volume = 1.0

// ✅ マスター音量で制御（Dynamic Gain Compensation）
engine.mainMixerNode.outputVolume = dynamicGain

// ✅ 最終段で安全リミット
SafeVolumeLimiter(maxLevel: -6dB)
```

### 5. エンジン停止

```swift
// ✅ 統一された停止処理（ファイル・合成両対応）
public func stop(fadeOut: TimeInterval = 0.5) {
    // TrackPlayer停止
    trackPlayer?.stop(fadeOut: fadeOut)

    // マスターフェードアウト
    fadeOut(duration: fadeOut)

    // エンジン停止（必ず実行）
    DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) {
        engine.stop()
        volumeLimiter.reset()
        engine.disableSources()
    }
}
```

### 6. エラーハンドリング

```swift
// ✅ 必ず状態をクリーンアップ
public func play(preset: NaturalSoundPreset) throws {
    do {
        try _playInternal(preset: preset)
    } catch {
        cleanupStateOnError()
        throw error
    }
}
```

### 7. モード切替

```swift
// ✅ 完了ハンドラ付き停止
audioService.stopAndWait(fadeOut: 0.5) {
    // エンジン完全停止後に次の再生開始
    try? audioService.playAudioFile(newFile)
}
```

---

## 音源ファイル管理

### ファイルフォーマット

**推奨: CAF (Core Audio Format)**
- Appleの標準フォーマット
- 効率的なストレージ
- 高品質なメタデータ

**フォールバック: WAV**
- 汎用フォーマット
- クロスプラットフォーム互換性

### ディレクトリ構成

```
clock-tsukiusagi/
└── Resources/
    └── Audio/
        ├── test_tone_440hz.caf      # テスト音源
        ├── test_tone_440hz.wav      # フォールバック
        └── (future audio files...)
```

### プリセット定義

```swift
// AudioFilePresets.swift
public enum AudioFilePreset: String, CaseIterable, Identifiable {
    case testTone = "test_tone_440hz"

    public func url() -> URL? {
        // Try CAF first
        if let url = Bundle.main.url(forResource: rawValue, withExtension: "caf") {
            return url
        }
        // Fallback to WAV
        return Bundle.main.url(forResource: rawValue, withExtension: "wav")
    }

    public var loopSettings: LoopSettings {
        switch self {
        case .testTone:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 0.5,
                fadeInDuration: 0.2,
                fadeOutDuration: 0.5
            )
        }
    }
}
```

---

## テスト方法

### 基本再生テスト

1. アプリ起動
2. "音源ファイル" を選択
3. "Test Tone (440Hz)" を選択
4. "再生" ボタンをタップ
5. 音が聞こえることを確認

### チェックリスト

- [ ] 音が聞こえる（440Hz のトーン）
- [ ] システム音量で音量調整できる
- [ ] ループ再生される（5秒ごとに繰り返し）
- [ ] 停止ボタンで完全に停止する
- [ ] 合成音源（クリック音防止）と切り替えできる
- [ ] 複数回再生・停止しても安定している
- [ ] クラッシュしない
- [ ] UIがロックしない

### デバッグログの確認

**正常なログ:**
```
🎵 [AudioService] Activating audio session...
   ✅ Session activated
🔊 [SafeVolumeLimiter] Configuring soft limiter
   Format: 48000.0 Hz, 2 channels
🎵 [AudioService] Audio file format: 44100.0 Hz, 1ch
🎵 [AudioService] Limiter configured with output format: 48000.0 Hz, 2ch
🎵 [TrackPlayer] Configured and connected to masterBusMixer
🎵 [TrackPlayer] Loaded file: test_tone_440hz.caf
   Duration: 5.0s
   Sample rate: 44100.0 Hz
   Channels: 1
🎵 [TrackPlayer] Playback started (loop: true, crossfade: 0.5s)
🎵 [TrackPlayer] Player node volume: 1.0
🎵 [AudioService] Fade in complete
```

**異常なログ:**
```
❌ Thread 1: "error -10868"  ← ランタイム再構成
⚠️ Engine is running, cannot reconfigure  ← フォーマット不一致
required condition is false: [_nodes containsObject: node1]  ← ノード未アタッチ
🎵 [TrackPlayer] Player node volume: 0.0  ← 音量未設定
```

---

## トラブルシューティング

### 音が出ない

**チェック項目:**
1. セッションがアクティベートされているか？
2. Limiterが48kHz/2chで構成されているか？
3. TrackPlayerがmasterBusMixerに接続されているか？
4. `playerNode.volume`が1.0か？
5. システム音量が0でないか？
6. エンジンが起動しているか？

**デバッグコマンド:**
```swift
print("sessionActivated: \(sessionActivated)")
print("limiter format: \(volumeLimiter.configuredFormat)")
print("playerNode.volume: \(playerNode.volume)")
print("systemVolume: \(AVAudioSession.sharedInstance().outputVolume)")
print("engine.isRunning: \(engine.isRunning)")
```

### クラッシュする（-10868）

**原因:** エンジン起動中に再構成

**解決策:**
```swift
// ✅ 必ずエンジン起動前に構成
volumeLimiter.configure(engine: engine.engine, format: outputFormat)
try engine.start()
```

### フォーマット不一致

**原因:** セッション未アクティベート

**解決策:**
```swift
// ✅ セッションを先にアクティベート
if !sessionActivated {
    try activateAudioSession()
    sessionActivated = true
}
```

---

## まとめ

### 最重要原則（5つ）

1. **"Session First, Format Next, Configure Before Start"**
   - セッションアクティベート → フォーマット取得 → Limiter構成 → エンジン起動

2. **フォーマット統一（48kHz/2ch）**
   - 全ての再生タイプで出力フォーマットを統一
   - ファイルフォーマットでLimiterを構成しない

3. **エンジン起動中は再構成禁止**
   - `configure → start`の順序を厳守
   - `-10868`クラッシュを防ぐ

4. **masterBusMixerアーキテクチャ**
   - Appleの自動配線を尊重
   - 全ての音源が統一された経路を通る

5. **エラー時の状態クリーンアップ**
   - 必ず`isPlaying`等をリセット
   - UIロックを防ぐ

### 次のステップ

- [ ] 複数音源の追加（pink/brown noise等）
- [ ] クロスフェードの洗練
- [ ] ストリーミング再生（大容量ファイル対応）

---

**作成日**: 2025-11-11
**最終更新**: 2025-11-12
**対象**: TrackPlayer実装者
**関連**: Phase 3 Audio Integration

---
