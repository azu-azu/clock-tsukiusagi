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
└── AudioService.swift              # TrackPlayer統合
```

---

## アーキテクチャ

### 音声処理フロー

```
AudioFile (WAV/CAF)
    ↓
AVAudioFile (read)
    ↓
AVAudioPCMBuffer (full file in memory)
    ↓
AVAudioPlayerNode (volume = 1.0)
    ↓
AVAudioEngine.mainMixerNode (Dynamic Gain Compensation)
    ↓
SafeVolumeLimiter (-6dB cap)
    ↓
AVAudioEngine.outputNode
    ↓
System Output (Speaker/Headphones/Bluetooth)
```

### 重要な設計原則

1. **TrackPlayerは音量調整しない**
   - `playerNode.volume = 1.0` 固定
   - マスター音量で制御（Dynamic Gain Compensation）

2. **エンジンは起動してから接続**
   - `engine.start()` → `trackPlayer.configure()`
   - 逆順だとノードが切断される

3. **音源配列は明示的にクリア**
   - `engine.stop()` だけでは不十分
   - `engine.clearSources()` で配列をクリア

4. **ファイルフォーマットをそのまま使う**
   - ミキサーフォーマットではなく `file.processingFormat` を使用
   - チャンネル数不一致を防ぐ

---

## 重大バグと解決策

### 1. チャンネル数不一致クラッシュ

**症状:**
```
required condition is false: _outputFormat.channelCount == buffer.format.channelCount
*** Terminating app due to uncaught exception 'com.apple.coreaudio.avfaudio'
```

**原因:**
ミキサーのステレオフォーマット（2ch）でモノラルファイル（1ch）を再生しようとした。

**間違ったコード:**
```swift
// ❌ ミキサーのフォーマットを使う（チャンネル数が合わない）
let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
trackPlayer?.configure(engine: engine.engine, format: mixerFormat)
```

**正しいコード:**
```swift
// ✅ ファイルのフォーマットを使う
let file = try AVAudioFile(forReading: url)
let fileFormat = file.processingFormat  // モノラルならそのまま
trackPlayer?.configure(engine: engine.engine, format: fileFormat)
```

**理由:**
- AVAudioEngineはノード間で自動的にフォーマット変換を行う
- PlayerNode → Mixer の接続でモノラル→ステレオ変換される
- バッファとノードのフォーマットが一致していればOK

---

### 2. 音が聞こえない問題

**症状:**
- 再生ログは正常に出力される
- `playerNode.isPlaying` が `true` になる
- しかし音が聞こえない
- マスター音量は正常（0.125程度）

**原因:**
`AVAudioPlayerNode.volume` が初期化されていなかった（デフォルト値が低い）。

**間違ったコード:**
```swift
// ❌ playerNode.volume を設定していない
playerNode.play()
```

**正しいコード:**
```swift
// ✅ 明示的に最大音量に設定
playerNode.volume = 1.0
playerNode.play()
```

**理由:**
- TrackPlayerの音量は固定（1.0）
- マスター音量で全体を制御（Dynamic Gain Compensation）
- playerNode.volume が低いと、マスター音量を上げても聞こえない

**デバッグ方法:**
```swift
print("🎵 [TrackPlayer] Player node volume: \(playerNode.volume)")  // ← これで確認
```

---

### 3. エンジン起動順序エラー

**症状:**
- 音が全く出ない
- ログは正常
- 何度試しても無音

**原因:**
TrackPlayer設定後にエンジンを再起動すると、ノード接続が切断される。

**間違ったコード:**
```swift
// ❌ TrackPlayer設定 → エンジン起動（ノードが切断される）
trackPlayer?.configure(engine: engine.engine, format: fileFormat)
try engine.start()  // ← ここで接続が切れる！
```

**正しいコード:**
```swift
// ✅ エンジン起動 → TrackPlayer設定
try engine.start()  // 先にエンジン起動
trackPlayer?.configure(engine: engine.engine, format: fileFormat)  // 後でノード接続
```

**理由:**
- AVAudioEngineはノードを `attach` 後に `connect` で接続
- `engine.start()` でエンジンを再起動すると、一部の接続がリセットされる
- エンジンが起動済みの状態でノードを接続するのが正しい

**参考ログ:**
```
🎵 [AudioService] Audio file format:
   Channels: 1
   Sample rate: 44100.0 Hz
🎵 [AudioService] Starting engine...
LocalAudioEngine: Starting audio engine...
LocalAudioEngine: AVAudioEngine started
🎵 [TrackPlayer] Configured and connected to engine  ← 順序が正しい
```

---

### 4. 合成音源との混在問題（最重要）

**症状:**
1. 音源ファイルを再生すると、合成音源（ClickSuppressionDrone）も一緒に鳴る
2. 音源ファイルを停止しても、合成音源が鳴り続ける
3. 何度も再生・停止を繰り返すと、音が出なくなる

**原因:**
`LocalAudioEngine.sources` 配列が蓄積し、`engine.start()` 時に全ての音源が起動される。

**問題のコード:**
```swift
// LocalAudioEngine.swift
public func register(_ source: AudioSource) throws {
    sources.append(source)  // ← 追加するだけ、削除しない
}

public func start() throws {
    try sources.forEach { try $0.start() }  // ← 配列の全て起動！
}

public func stop() {
    sources.forEach { $0.stop() }  // ← 停止するだけ、配列に残る
}
```

**問題の流れ:**
```
1. ClickSuppressionDrone再生
   → sources = [ClickSuppressionDrone]

2. 停止
   → engine.stop() 呼び出し
   → sources = [ClickSuppressionDrone]  ← まだ配列に残る

3. TrackPlayer再生
   → engine.start() 呼び出し
   → sources.forEach { $0.start() }
   → ClickSuppressionDroneも再起動！  ← 問題発生

4. TrackPlayer停止
   → trackPlayer.stop() のみ
   → ClickSuppressionDroneは鳴り続ける  ← さらに問題
```

**解決策:**
`clearSources()` メソッドを実装し、配列を明示的にクリア。

**追加コード:**
```swift
// LocalAudioEngine.swift
/// 全ての音源を登録解除してクリア
public func clearSources() {
    print("LocalAudioEngine: Clearing all sources (count: \(sources.count))")

    // 全ての音源を停止
    sources.forEach { $0.stop() }

    // 配列をクリア
    sources.removeAll()

    print("LocalAudioEngine: All sources cleared")
}
```

**使用箇所:**
```swift
// AudioService.swift - playAudioFile()
if isPlaying && currentPreset != nil {
    engine.stop()
    engine.clearSources()  // ← 合成音源を配列から削除
    isPlaying = false
    currentPreset = nil
} else if isPlaying {
    engine.stop()
    engine.clearSources()  // ← 念のため全クリア
}

// AudioService.swift - stop()
DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) { [weak self] in
    self?.engine.stop()
    self?.engine.clearSources()  // ← 停止後もクリア
    print("🎵 [AudioService] Synthesis engine stopped and cleared after fade")
}
```

**重要ポイント:**
- `stop()` だけでは音源が配列に残る
- `clearSources()` で明示的に削除する
- ファイル再生前に必ずクリア
- 停止時もクリア（次回再生のため）

---

## ベストプラクティス

### 1. 音量制御

```swift
// ✅ TrackPlayerは常に最大音量
playerNode.volume = 1.0

// ✅ マスター音量で制御（Dynamic Gain Compensation）
engine.mainMixerNode.outputVolume = dynamicGain

// ✅ 最終段で安全リミット
SafeVolumeLimiter(maxLevel: -6dB)
```

### 2. エンジン管理

```swift
// ✅ 正しい順序
try engine.start()
trackPlayer?.configure(engine: engine.engine, format: fileFormat)
try trackPlayer?.load(url: url)
trackPlayer?.play(loop: true, crossfadeDuration: 0.5)

// ✅ 停止時はクリア
engine.stop()
engine.clearSources()
```

### 3. フォーマット処理

```swift
// ✅ ファイルのフォーマットをそのまま使う
let file = try AVAudioFile(forReading: url)
let fileFormat = file.processingFormat

// ✅ エンジンが自動変換してくれる
trackPlayer?.configure(engine: engine.engine, format: fileFormat)
```

### 4. エラーハンドリング

```swift
// ✅ ファイルが見つからない場合
guard let url = audioFile.url() else {
    throw AudioError.engineStartFailed(NSError(domain: "AudioService", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Audio file not found: \(audioFile.rawValue)"
    ]))
}

// ✅ バッファ作成失敗
guard let buffer = AVAudioPCMBuffer(
    pcmFormat: file.processingFormat,
    frameCapacity: AVAudioFrameCount(file.length)
) else {
    throw TrackPlayerError.bufferCreationFailed
}
```

### 5. ログ出力

```swift
// ✅ 重要な情報を出力
print("🎵 [TrackPlayer] Loaded file: \(url.lastPathComponent)")
print("   Duration: \(Double(buffer.frameLength) / file.fileFormat.sampleRate)s")
print("   Sample rate: \(file.fileFormat.sampleRate) Hz")
print("   Channels: \(file.fileFormat.channelCount)")
print("   Player node volume: \(playerNode.volume)")
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

### Xcodeプロジェクト設定

1. ファイルをドラッグ＆ドロップ
2. "Copy items if needed" にチェック
3. Target Membership: `clock-tsukiusagi` を選択

### プリセット定義

```swift
// AudioFilePresets.swift
public enum AudioFilePreset: String, CaseIterable, Identifiable {
    case testTone = "test_tone_440hz"
    // Future presets:
    // case pinkNoise = "pink_noise_60s"
    // case brownNoise = "brown_noise_60s"

    public var displayName: String {
        switch self {
        case .testTone:
            return "Test Tone (440Hz)"
        }
    }

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

### 音源生成スクリプト

```bash
cd scripts
python3 generate_test_tone.py
```

**生成される音源:**
- 440Hz サイン波（A4音程）
- 5秒間
- 44.1kHz サンプルレート
- モノラル
- フェードイン/アウト付き（100ms）
- WAV + CAF両方

---

## テスト方法

### 基本再生テスト

```swift
// AudioTestView.swift
1. アプリ起動
2. "音源ファイル" を選択
3. "Test Tone (440Hz)" を選択
4. "再生" ボタンをタップ
5. 音が聞こえることを確認
```

### チェックリスト

- [ ] 音が聞こえる（440Hz のトーン）
- [ ] システム音量で音量調整できる
- [ ] ループ再生される（5秒ごとに繰り返し）
- [ ] 停止ボタンで完全に停止する
- [ ] 合成音源（クリック音防止）と切り替えできる
- [ ] 複数回再生・停止しても安定している

### デバッグログの確認

**正常なログ:**
```
🎵 [AudioService] playAudioFile() called with: Test Tone (440Hz)
🎵 [AudioService] Audio file format:
   Channels: 1
   Sample rate: 44100.0 Hz
LocalAudioEngine: Starting audio engine...
LocalAudioEngine: AVAudioEngine started
🎵 [TrackPlayer] Configured and connected to engine
🎵 [TrackPlayer] Loaded file: test_tone_440hz.caf
   Duration: 5.0s
   Sample rate: 44100.0 Hz
   Channels: 1
🎵 [TrackPlayer] Playback started (loop: true, crossfade: 0.5s)
🎵 [TrackPlayer] Player node volume: 1.0
🎵 [AudioService] Starting fade in...
🎵 [AudioService] Fade in complete - target: 0.5012
```

**異常なログ:**
```
⚠️ [AudioFilePreset] File not found: test_tone_440hz.caf  ← ファイルがない
required condition is false: _outputFormat.channelCount == buffer.format.channelCount  ← チャンネル数不一致
🎵 [TrackPlayer] Player node volume: 0.0  ← 音量が0
```

### 実機テスト

**必須確認項目:**
- [ ] iPhone実機で動作（シミュレータでは不完全）
- [ ] ヘッドホンで再生
- [ ] Bluetooth接続で再生
- [ ] スピーカーで再生（音量注意）
- [ ] ロック画面でも継続再生
- [ ] バックグラウンドでも継続再生
- [ ] 電話着信時の中断・再開

---

## トラブルシューティング

### 音が出ない

**チェック項目:**
1. `playerNode.volume` が 1.0 に設定されているか？
2. マスター音量が 0 でないか？
3. システム音量が 0 でないか？
4. エンジンが起動しているか？（`engine.isRunning`）
5. ファイルが正しく読み込まれているか？（`buffer != nil`）

**デバッグコマンド:**
```swift
print("playerNode.volume: \(playerNode.volume)")
print("engine.mainMixerNode.outputVolume: \(engine.mainMixerNode.outputVolume)")
print("systemVolume: \(AVAudioSession.sharedInstance().outputVolume)")
print("engine.isRunning: \(engine.isRunning)")
print("buffer: \(String(describing: buffer))")
```

### 合成音源と混在する

**解決策:**
`playAudioFile()` の最初に `clearSources()` を呼ぶ。

```swift
if isPlaying && currentPreset != nil {
    engine.stop()
    engine.clearSources()  // ← 必須
    isPlaying = false
    currentPreset = nil
}
```

### 複数回再生で失敗

**原因:** 音源が蓄積している

**解決策:**
停止時にも `clearSources()` を呼ぶ。

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) { [weak self] in
    self?.engine.stop()
    self?.engine.clearSources()  // ← 追加
}
```

### クラッシュする

**原因:** チャンネル数不一致

**解決策:**
ファイルの `processingFormat` を使う。

```swift
let file = try AVAudioFile(forReading: url)
let fileFormat = file.processingFormat  // ← これを使う
trackPlayer?.configure(engine: engine.engine, format: fileFormat)
```

---

## まとめ

### 重要ポイント（5つ）

1. **playerNode.volume = 1.0 は必須**
   - マスター音量で制御するため

2. **エンジン起動 → ノード接続の順序**
   - 逆だとノードが切断される

3. **ファイルフォーマットをそのまま使う**
   - チャンネル数不一致を防ぐ

4. **clearSources() で配列をクリア**
   - stop() だけでは不十分

5. **実機でテスト**
   - シミュレータでは完全に動作しない

### 次のステップ

- [ ] 複数音源の追加（pink/brown noise等）
- [ ] クロスフェードの洗練
- [ ] 複数ファイルの同時再生（ミキシング）
- [ ] ストリーミング再生（大容量ファイル対応）

---

**作成日**: 2025-11-11
**対象**: TrackPlayer実装者
**関連**: Phase 3 Audio Integration

---
