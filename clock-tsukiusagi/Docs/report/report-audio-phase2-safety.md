# 🧾 `report-audio-phase2-safety.md`

**TsukiUsagi Audio System – Phase 2 開発レポート**
📅 2025-11-10
👩‍💻 Author: Azu
🏷️ Tag: `audio-architecture-phase2-complete`
📂 Location: `Docs/report/report-audio-phase2-safety.md`

---

## 🎯 フェーズ概要

**目的:**
Phase 1で確立した `AudioService` 基盤に、
「安全性」と「持続性」を加える。

**主要テーマ:**

1. Quiet Break（55min/5min cycle）による聴覚休憩
2. Safe Volume Limiter による出力上限の安全制御
3. Fade in/out の導入によるUX向上

このフェーズでは「心地よく、安心して聞ける音体験」をテーマに設計を強化。

---

## 🧩 実装概要

### 1. QuietBreakScheduler

* **ファイル:** `Core/Services/Scheduler/QuietBreakScheduler.swift`
* **目的:** 再生を55分ごとに自動停止し、5分の休憩後に再開。
* **実装ポイント:**

  * `DispatchSourceTimer` を使用し、`wallDeadline`（実時計）で精度維持
  * `Date` を“ground truth”として記録
  * アプリの sleep/wake イベントを監視して、タイマーずれを自動補正
  * `onBreakStart` / `onBreakEnd` コールバックで `AudioService` を制御

🧠 **学び:**
シミュレータでは正常でも、実機ではスリープ復帰で1〜2秒ズレが出る。
→ `UIApplication.willEnterForegroundNotification` を監視して修正。

---

### 2. SafeVolumeLimiter

* **ファイル:** `Core/Services/Volume/SafeVolumeLimiter.swift`
* **目的:** 出力音量の過大を防ぐ（デフォルト -6dB）
* **実装ポイント:**

  * macOS専用 `AVAudioUnitDynamicsProcessor` が使えず、
    → iOS互換の `AVAudioUnitDistortion` を採用（ソフトクリッピング方式）
  * `MainMixerNode → Limiter → OutputNode` の最終段で適用
  * `isConfigured` フラグを設け、ノード重複接続によるクラッシュを防止

🎧 **結果:**

* 短いドローン音では歪みほぼなし。
* ハードリミッタではなく“柔らかい安全帯”として理想的。
* 実機テストで耳に痛いピーク音は完全に除去された。

---

### 3. Fade Effects（音のフェード処理）

* **ファイル:** `Core/Audio/AudioService.swift`
* **概要:** 再生・停止・休憩切替時のフェードを導入。
* **実装:**

  * 60fpsタイマー（60ステップ）で滑らかに音量を補間
  * 停止時はフェード終了後に `engine.stop()` を呼ぶ（即停止禁止）
  * 再開時は直前の音量を `targetVolume` として復元

💡 **課題と解決:**
即停止するとクリックノイズが発生 → `DispatchQueue.asyncAfter` で遅延停止。
→ 完全に無音で自然なフェードアウトを実現。

---

### 4. AudioSettingsView（設定UI）

* **ファイル:** `Features/Settings/Views/AudioSettingsView.swift`
* **概要:** フェーズ2機能をGUIで操作可能に。
* **項目:**

  * Quiet Break 有効/無効
  * 再生時間 / 休憩時間
  * 出力上限（dBスライダー）
  * 次の休憩予定表示

🔄 `AudioService` の `updateSettings()` と連携してリアルタイム反映。

---

## 🧠 技術的発見と問題解決

| 課題                                   | 原因                          | 解決策                                   |
| ------------------------------------ | --------------------------- | ------------------------------------- |
| AVAudioUnitDynamicsProcessor がiOS非対応 | macOS専用クラスだった               | AVAudioUnitDistortion に置き換え           |
| 再生後のフェード停止がノイズを発生                    | `engine.stop()` の呼び出しタイミング  | `DispatchQueue.asyncAfter` で遅延実行      |
| QuietBreak のタイマーずれ                   | スリープ復帰で `uptime` ベースが停止     | `wallDeadline` ＋ Date再計算方式へ変更         |
| TimerからMainActorアクセスで警告              | Swift 6のSendable制約          | `Task { @MainActor }` で安全に呼び出し        |
| 設定値が反映されない                           | `breakScheduler` を再構築してなかった | `AudioService.updateSettings()` で同期実装 |

---

## ✅ 動作確認結果

* [x] QuietBreak動作（5min/1minモードで検証）
* [x] Break中にフェードアウト、再開時フェードイン
* [x] 音量上限（-6dB, -12dB）で適切に制御
* [x] 画面遷移・ロック中も継続再生
* [x] 設定UIの即時反映
* [x] 実機テスト（iPhone 13）で安定稼働2時間

---

## 📈 成果と学び

* **音の安全設計**をアプリレベルで実現できた。
* **「ユーザーが気づかない快適さ」**（自動休憩や滑らかフェード）が形になった。
* システムの“生命”がアプリ全体で持続する感覚を得た。

🪄 フェーズ1では「生きる音」、
フェーズ2では「優しい音」。
Phase3では「伝わる音」へ進化させていく。

---

## 🔗 関連ドキュメント

* `architect/2025-11-10_audio_architecture_redesign.md`
* `Docs/changelog/changelog-audio.md`
* `Docs/architecture/adrs/_adr-0002-safe-volume-ios-alt.md`
* `Docs/implementation/_guide-audio-system-impl.md`
* `Docs/runbook/_runbook-audio-ops-and-tests.md`

---

## 🧭 次のフェーズへ

**Phase 3: Advanced Integration（次期計画）**

* Live Activity / Lock Screen コントロール
* TrackPlayer（音源クロスフェード再生）
* PiPサポート（検証ベース）
* AudioActivityWidgetの実装

---
