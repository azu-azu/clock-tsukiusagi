# 🧾 `report-audio-phase3-integration.md`

**TsukiUsagi Audio System – Phase 3 開発レポート**
📅 2025-11-11
👩‍💻 Author: Azu
🏷️ Tag: `audio-phase3-integration-complete`
📂 Location: `Docs/report/report-audio-phase3-integration.md`

---

## 🎯 フェーズ概要

**目的:**
Phase 2で完成した安全性機構に、
「システム統合」と「音源拡張性」を加える。

**主要テーマ:**

1. Live Activity（ロック画面・Dynamic Island連携）
2. Now Playing（コントロールセンター・Lock Screen再生制御）
3. TrackPlayer（音源ファイル再生・シームレスループ）
4. 音源管理の拡張性確保

このフェーズでは「アプリ外でも、iOSと一体化した音体験」をテーマに設計を拡張。

---

## 🧩 実装概要

### 1. Live Activity（ロック画面・Dynamic Island）

#### 実装内容

**ファイル構成:**
- `Core/Activity/AudioActivityAttributes.swift` - Activity定義
- `Core/Activity/AudioActivityController.swift` - ライフサイクル管理
- `AudioLiveActivity/AudioLiveActivityLiveActivity.swift` - Widget UI
- `Info.plist` - `NSSupportsLiveActivities` 追加

**表示内容:**
- **ロック画面**: 再生状態、プリセット名、出力先、次の休憩時刻
- **Dynamic Island**:
  - Expanded: 詳細情報（プリセット、出力先、休憩予定）
  - Compact: アイコン2つ（再生状態 + 出力先）
  - Minimal: 再生状態アイコンのみ

**更新タイミング:**
- 再生開始・停止時
- 出力先変更時（ヘッドホン抜き差し等）
- 休憩スケジュール更新時
- 一時停止時（理由表示）

#### 技術的ポイント

✅ **成功要因:**
- `AudioActivityAttributes` をメインアプリとWidget Extensionの両方に配置
- すべてのプロパティに `public` 修飾子を付与
- `ContentState` に `public init()` を実装
- iOS 16.1/16.2のAPI差異を `#available` で吸収

⚠️ **ハマりポイント:**
- `Info.plist` に `NSSupportsLiveActivities` がないと何も表示されない
- Widget ExtensionからAttributesが見えない → ファイルコピーで解決
- Dynamic Islandに "s" だけ表示 → `.prefix(1)` 使用が原因、アイコンに変更
- デフォルト設定 `false` で初回起動時に動作せず → `true` に変更

🎨 **デザイン:**
- アイコンは40pt（ロック画面）、システムカラー使用
- 背景: `Color.black.opacity(0.8)` で可読性確保
- 状態カラー: 緑（再生）、オレンジ（停止）で視認性向上

---

### 2. Now Playing（コントロールセンター統合）

#### 実装内容

**ファイル:** `Core/Services/NowPlaying/NowPlayingController.swift`

**機能:**
- コントロールセンターでの再生/一時停止/停止
- ロック画面の再生コントロール
- Now Playingメタデータ表示（タイトル、アーティスト、アートワーク）
- リモートコマンドハンドリング

**メタデータ:**
```swift
- タイトル: プリセット名（例: "クリック音防止"）
- アーティスト: "TsukiUsagi"
- アルバム: "Natural Sounds"
- アートワーク: SF Symbol画像（waveform.circle.fill）
```

**コマンド実装:**
- Play: `AudioService.play(preset:)` 呼び出し
- Pause: `AudioService.pause(reason: .user)` 呼び出し
- Stop: `AudioService.stop()` 呼び出し

#### 技術的ポイント

✅ **実装のコツ:**
- `MPRemoteCommandCenter` でリモートコマンド登録
- `MPNowPlayingInfoCenter` でメタデータ更新
- `MPNowPlayingInfoPropertyPlaybackRate` で再生/停止状態を反映
- SF Symbolを `UIImage(systemName:)` でアートワークに変換

🎧 **UX改善:**
- ロック画面から直接操作可能
- コントロールセンターで音源名確認可能
- Bluetoothヘッドセットのボタンでも制御可能

---

### 3. TrackPlayer（音源ファイル再生）

#### 実装内容

**ファイル:**
- `Core/Audio/Players/TrackPlayer.swift` - ファイル再生プレイヤー
- `Core/Audio/Presets/AudioFilePresets.swift` - 音源プリセット定義
- `Core/Audio/AudioTestView.swift` - テストUI
- `scripts/generate_test_tone.py` - テスト音源生成スクリプト

**機能:**
- WAV/CAFファイルの再生
- シームレスループ再生
- クロスフェード対応（設定可能）
- フェードイン/フェードアウト

**音源フォーマット:**
- 優先: CAF（Core Audio Format、Apple推奨）
- フォールバック: WAV（汎用フォーマット）
- チャンネル: モノラル/ステレオ自動対応
- サンプルレート: 44.1kHz

#### 技術的ポイント

**🐛 解決した重大バグ:**

1. **チャンネル数不一致クラッシュ**
   - 問題: ミキサーのステレオフォーマットでモノラルファイル再生
   - 解決: ファイルの `processingFormat` を使用
   ```swift
   let fileFormat = file.processingFormat
   trackPlayer?.configure(engine: engine.engine, format: fileFormat)
   ```

2. **音が聞こえない問題**
   - 問題: `playerNode.volume` が初期化されていなかった
   - 解決: 明示的に `volume = 1.0` を設定
   ```swift
   playerNode.volume = 1.0  // Master volumeで制御するため最大に
   ```

3. **エンジン起動順序エラー**
   - 問題: TrackPlayer設定後にエンジン再起動でノード切断
   - 解決: エンジン起動 → TrackPlayer設定の順序に変更
   ```swift
   try engine.start()  // 先にエンジン起動
   trackPlayer?.configure(engine: engine.engine, format: fileFormat)
   ```

4. **合成音源との混在問題（最重要）**
   - 問題: `sources` 配列が蓄積し、エンジン起動時に全て再生される
   - 症状:
     - ファイル再生中に合成音も鳴る
     - ファイル停止後も合成音が続く
     - 複数回再生で音が出なくなる
   - 解決: `clearSources()` メソッドを実装
   ```swift
   // LocalAudioEngine.swift
   public func clearSources() {
       sources.forEach { $0.stop() }
       sources.removeAll()
   }

   // AudioService.swift - playAudioFile()
   engine.stop()
   engine.clearSources()  // 配列をクリア
   ```

**🎵 シームレスループの仕組み:**
```swift
playerNode.scheduleBuffer(buffer, at: nil, options: [],
    completionCallbackType: .dataPlayedBack) { [weak self] callbackType in
    Task { @MainActor [weak self] in
        // バッファ再生完了時に次をスケジュール
        self?.scheduleBuffer(buffer, loop: true, crossfadeDuration: duration)
    }
}
```

**📁 音源ファイル管理:**
- `Resources/Audio/` に配置
- `AudioFilePreset` enumで管理
- UIから選択可能（Pickerで実装）
- 将来的な拡張を想定（pink/brown noise, ocean waves, rain等）

---

### 4. システム音量連動（Phase 2からの継続改善）

**Dynamic Gain Compensation:**
- システム音量を常時監視（`AVAudioSession.sharedInstance().outputVolume`）
- アプリゲイン = 0.5 / max(systemVolume, 0.1)
- 上限: 0.5012（-6dB安全リミット）
- 下限: systemVolume ≤ 0.1 で再生停止

**安全機構との統合:**
- TrackPlayer音量 = 1.0（固定）
- マスター音量でDynamic Gain適用
- SafeVolumeLimiterで最終段保護
- 3層の安全制御を実現

---

## 🧠 技術的発見と問題解決

| 課題                                  | 原因                                    | 解決策                                           |
| ----------------------------------- | ------------------------------------- | --------------------------------------------- |
| Live Activity表示されない                | `NSSupportsLiveActivities` 未設定         | Info.plistにキー追加                               |
| Dynamic Islandに "s" のみ表示           | `.prefix(1)` でテキスト切り出し使用             | アイコンベースのデザインに変更                               |
| Widget Extensionからビルドエラー          | Attributesファイルが見えない                   | ファイルをExtensionディレクトリにコピー                      |
| TrackPlayerチャンネル数クラッシュ             | ミキサーフォーマットとファイルフォーマットの不一致           | ファイルの `processingFormat` を使用                   |
| TrackPlayer音量が小さい/聞こえない            | `playerNode.volume` 未初期化               | `volume = 1.0` を明示的に設定                        |
| ファイル再生時に合成音源も鳴る                   | `sources` 配列が蓄積、`start()` で全て起動       | `clearSources()` で配列をクリア                       |
| 複数回再生で音が出なくなる                     | 音源が重複登録され、リソース枯渇                      | 再生前に `clearSources()` 呼び出し                     |
| エンジン起動後にノード切断                     | ノード接続後の `engine.start()` で接続が切れる      | エンジン起動 → ノード接続の順序に変更                          |
| Now Playingアートワークが表示されない           | SF SymbolをUIImage経由で渡していなかった         | `UIImage(systemName:)` で変換                     |
| Live Activity更新されない                | `liveActivityEnabled` デフォルト `false` | デフォルトを `true` に変更                             |
| シミュレータでLive Activity動作しない         | システム制限                                | 実機テスト必須（iPhone実機で動作確認）                       |
| Swift 6並行性警告（TrackPlayer）          | completion handler内でMainActor外アクセス | `Task { @MainActor }` でラップ                    |

---

## ✅ 動作確認結果

### Live Activity
- [x] ロック画面に表示（再生状態、プリセット名、出力先、休憩予定）
- [x] Dynamic Island表示（Expanded/Compact/Minimal）
- [x] 再生・停止時のリアルタイム更新
- [x] 出力先変更時の即座反映
- [x] 休憩スケジュール表示
- [x] 一時停止理由の表示

### Now Playing
- [x] コントロールセンターに表示
- [x] ロック画面コントロール動作
- [x] メタデータ表示（タイトル、アーティスト、アートワーク）
- [x] Play/Pause/Stopコマンド動作
- [x] Bluetoothヘッドセットボタン対応

### TrackPlayer
- [x] CAF/WAVファイル再生
- [x] シームレスループ再生
- [x] フェードイン/フェードアウト
- [x] 音量制御（システム音量連動）
- [x] 合成音源との切り替え
- [x] 複数回再生の安定性
- [x] モノラル/ステレオ自動対応

### システム統合
- [x] 画面ロック中も継続再生
- [x] バックグラウンド動作
- [x] ヘッドホン抜き差し検知
- [x] Bluetooth接続/切断対応
- [x] システム音量連動
- [x] 実機テスト（iPhone 13, iOS 17.1）

---

## 🔗 関連ドキュメント

### 技術ガイド
- `docs/LiveActivity-Setup-Guide.md` - Live Activity実装ガイド（詳細版）
- `architect/2025-11-10_audio_architecture_redesign.md` - 全体アーキテクチャ

### レポート
- `Docs/report/report-audio-phase2-safety.md` - Phase 2レポート
- `Docs/changelog/changelog-audio.md` - 変更履歴

### 実装ガイド
- `Docs/implementation/_guide-audio-system-impl.md` - AudioService実装ガイド
- `Docs/runbook/_runbook-audio-ops-and-tests.md` - 運用・テストガイド

### コードリファレンス
- `Core/Activity/` - Live Activity実装
- `Core/Services/NowPlaying/` - Now Playing実装
- `Core/Audio/Players/TrackPlayer.swift` - 音源ファイル再生
- `Core/Audio/Presets/AudioFilePresets.swift` - 音源管理

---

## 🧭 次のフェーズへ（展望）

**Phase 4: Content Expansion（検討中）**

### 音源拡張
- [ ] Pink Noise（ピンクノイズ）
- [ ] Brown Noise（ブラウンノイズ）
- [ ] Ocean Waves（波の音）
- [ ] Rain（雨音）
- [ ] Forest Ambience（森の環境音）

### UI/UX改善
- [ ] 音源プリセットのカスタマイズ
- [ ] お気に入り機能
- [ ] 音源の組み合わせ再生
- [ ] イコライザー調整

### システム統合
- [ ] Shortcuts対応（Siri経由再生）
- [ ] Apple Watch連携
- [ ] CarPlay対応
- [ ] Focus Modesとの連携

### アクセシビリティ
- [ ] VoiceOver最適化
- [ ] ダイナミックタイプ対応
- [ ] ハイコントラスト対応

---

## 🎑 Phase 3 総括と開発者の学び

### 🌕 技術的な完成 — システムと呼吸する音

* アプリを開かなくても使える
* システムUIに自然に溶け込む
* ユーザーが"意識しない快適さ"を実現

これは単なる機能統合やなしに、
**「音がOSの一部として生きている」状態**を創れたということ。
TsukiUsagiの音は、もはやアプリの枠を越えて、
iOS全体に「息づく環境音」になった。

---

### 🧠 技術的洞察 — 再現と安定化への挑戦

今回のPhase 3で最大の壁やったのは、
**「何度も再生を繰り返すと止まる・落ちる」**という根深い問題。

#### 原因:

* AudioEngine起動中にノードを再構成していた
* SafeVolumeLimiterが稼働中に再設定され、engine内部で競合発生

#### 解決:

* “Session First, Format Next, Configure Before Start” 原則の徹底
* エンジン起動中はLimiter再構成を禁止
* フォーマットを48kHz/2chに統一
* ノードの再接続を起動前に完了させる

結果、クラッシュは完全消失。
フェードも正確に動き、音の途切れもなくなった。

---

### 🎛️ 責務の明確化 — 音を支える構造

| コンポーネント            | 役割                        |
| ------------------ | ------------------------- |
| `TrackPlayer`      | 音源ファイルの再生とループ処理           |
| `LocalAudioEngine` | ノードと信号経路の統合・制御            |
| `AudioService`     | フェード、リミッター、プリセット、UXイベント制御 |

この分離により、**エンジン再構築やフェード、Live Activity更新**など
複雑な同期も安全に行えるようになった。

---

### 🔄 安定性検証

* 20回連続の再生/停止テストを実施 → 全て正常終了
* 再生とフェードを同時操作しても途切れなし
* エンジン再起動テスト（バックグラウンド復帰含む） → 安定動作

これにより、**Phase 3は「信頼できる音の基盤」**として完結した。

---

### 💬 開発者の気づき

> 「わかってたのに壊して、また直して、ようやく腑に落ちた」
>
> コードは何度も動いてたけど、“正しい順序”を体が覚えるまで時間がかかった。
> それができた瞬間、音が自然に鳴り始めた。
>
> ― Azu

---

### 🚀 次のステップへの基盤

* 音源の拡張が容易に
* システム統合がさらに深化可能
* ユーザー体験の連続性が確保

🌙 **TsukiUsagiの音は、もうアプリの中だけのものではなく、
iOSシステム全体に息づく“環境の一部”となった。**

---

🗓 **Phase 3 完了日:** 2025-11-11
🧭 **次回レビュー:** Phase 4 計画時
👩‍💻 **担当:** Azu & Claude Code

---
