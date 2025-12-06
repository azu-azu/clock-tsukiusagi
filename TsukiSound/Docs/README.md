# TsukiSound ドキュメント

このディレクトリには、TsukiSoundプロジェクトの開発・運用に関するドキュメントが含まれています。

---

## あなたは今どれを知りたい？

| 目的 | ドキュメント |
|------|-------------|
| 🧠 なぜこの設計なのか | [`_arch-philosophy.md`](./_arch-philosophy.md) |
| 🏛 設計判断の理由を知りたい | [`_adr-*.md`](./architecture/adrs/) |
| 🛠 実装方法を知りたい | [`_guide-*.md`](./implementation/) |
| 🧪 トラブル対応・運用 | [`_runbook-*.md`](./runbook/) |

### ドキュメント階層

```
思想 (_arch-philosophy)
      ↓
意思決定 (_adr-)
      ↓
実装 (_guide-)
      ↓
運用 (_runbook-)
```

---

## 🗂️ Docs Naming Rules（Fujiko構造版）

### 🧭 命名フォーマット

```
[_prefix]-[main-topic].md
```

### ✅ Prefix一覧（カテゴリ別）

| Prefix       | レイヤー     | 意味・役割             | 例                                                   |
| ------------ | -------- | ----------------- | --------------------------------------------------- |
| `_arch-`     | 思想層（最上位） | 設計思想・原則・全体方針      | `_arch-guidelines.md`                               |
| `_adr-`      | 意思決定層    | アーキテクチャ決定記録（ADR）  | `_adr-audio-service-singleton.md`                   |
| `_guide-`    | 実行層（2番目） | 操作手順・実装ガイド・実務ノウハウ | `_guide-keyboard.md`, `_guide-font-installation.md` |
| `_runbook-`  | 運用手順層    | 運用・テスト・デバッグ手順     | `_runbook-audio-ops-and-tests.md`                   |
| `structure-` | 設計構造層    | フォルダ構成・設計ルール・命名体系 | `structure-directory.md`, `structure-guidelines.md` |
| `changelog-` | 変更履歴層    | 機能別・モジュール別の変更履歴   | `changelog-audio.md`                                |
| `lint-`      | 例外・ルール層  | コード規約や例外設定        | `lint-exceptions.md`                                |
| `report-`    | 報告層      | 作業記録・移行レポート・不具合分析  | `report-audio-distortion-noise.md`              |
| `README.md`  | 説明層（特例）  | フォルダ全体の概要         | `README.md`（プレフィックスなし）                              |

---

## 📚 **ファイル命名スタイル共通ルール**

| ルール                                    | 内容                                                          |
| -------------------------------------- | ----------------------------------------------------------- |
| 区切りは **ハイフン（-）**                       | 例：`_guide-keyboard.md` ✅ ／ `guide_keyboard.md` ❌            |
| すべて **小文字**                            | 例：`structure-guidelines.md` ✅ ／ `Structure-Guidelines.md` ❌ |
| 意味の中心は **英単語2〜3個以内**                   | 冗長な説明語は避け、簡潔に                                               |
| 英単語順は「カテゴリ → 対象」                       | `guide-keyboard`（ガイド／キーボード）                                 |
| 1ファイル名の語数は **最大4トークン**                 | 例：`_guide-audio-fade-impl.md` まで                            |
| 文字種は `[a-z0-9-_.]` のみ                  | 全角文字・スペース禁止、連続ハイフン（`--`）禁止                                  |
| 日付・バージョンは **必要時のみ末尾に**                 | 日付：`-20251110`（YYYYMMDD）、バージョン：`-v1-1`（ピリオド避け、ハイフンで）       |
| 分野接頭辞の使用を推奨                            | 例：`audio-`、`clock-`、`moon-` など機能領域を明示                      |
| 特殊優先順序：`_arch-` → `_adr-` → `_guide-` | 上に並ぶ順で意味的階層を表現する                                            |

---

## 📚 ドキュメント一覧

### 🏛️ 設計思想・アーキテクチャ
- [`_arch-philosophy.md`](./_arch-philosophy.md) - **設計思想の核（Philosophy）** ★まずここを読む
- [`_arch-guidelines.md`](./_arch-guidelines.md) - アーキテクチャガイドライン・設計原則
- [`architecture/_arch-audio-parameter-safety-rules.md`](./architecture/_arch-audio-parameter-safety-rules.md) - オーディオパラメータ安全性ルール（3層アーキテクチャ）
- [`architecture/_arch-audio-system-spec.md`](./architecture/_arch-audio-system-spec.md) - オーディオシステム仕様書（Phase 2完了 + 3層アーキテクチャ）

### 🎯 アーキテクチャ決定記録（ADR）
- `_adr-*.md` - 設計判断の背景・トレードオフ・決定理由を記録
- [`architecture/adrs/_adr-0001-audio-service-singleton.md`](./architecture/adrs/_adr-0001-audio-service-singleton.md) - AudioService Singleton採用の決定記録
- [`architecture/adrs/_adr-0002-safe-volume-ios-alt.md`](./architecture/adrs/_adr-0002-safe-volume-ios-alt.md) - iOS互換ボリュームリミッター実装の決定記録

### 🔧 実装ガイド・手順書
- [`_guide-error-resolution.md`](./_guide-error-resolution.md) - エラー解決ガイド（汎用チェックリスト）
- [`_guide-font.md`](./_guide-font.md) - フォント使用ガイドライン
- [`_guide-font-installation.md`](./_guide-font-installation.md) - Nunitoフォントのインストール手順
- [`_guide-keyboard.md`](./_guide-keyboard.md) - キーボード操作ガイドライン
- [`_guide-notifications-fg-bg.md`](./_guide-notifications-fg-bg.md) - フォアグラウンド・バックグラウンド通知ガイド
- [`_guide-quiet-moon-animation.md`](./_guide-quiet-moon-animation.md) - Quiet Moon状態からのSTART時アニメーション不発火問題の修正ガイド
- [`implementation/_guide-audio-system-impl.md`](./implementation/_guide-audio-system-impl.md) - オーディオシステム実装ガイド（Phase 2 + 3層アーキテクチャ）★主要リファレンス
- [`implementation/_guide-audio-seamless-loop-generation.md`](./implementation/_guide-audio-seamless-loop-generation.md) - シームレスループ音声ファイル生成ガイド
- [`implementation/_guide-audio-presets-restoration.md`](./implementation/_guide-audio-presets-restoration.md) - ナチュラルサウンドプリセット復元ガイド（⚠️ 一部非推奨：3層アーキテクチャ移行済み）
- [`implementation/_guide-organ-envelope-asr.md`](./implementation/_guide-organ-envelope-asr.md) - オルガン音色のASRエンベロープ設計ガイド（ASR vs AD、Legato Crossfade）
- [`implementation/_guide-navigation-back-gesture.md`](./implementation/_guide-navigation-back-gesture.md) - カスタム戻る操作実装ガイド
- [`implementation/_guide-design-tokens.md`](./implementation/_guide-design-tokens.md) - デザイントークン統一ガイド
- [`implementation/_guide-navigation-design.md`](./implementation/_guide-navigation-design.md) - ナビゲーションバー・タブ統合設計

### 📖 運用・テスト手順書（Runbook）
- `_runbook-*.md` - 運用手順、テスト手順、デバッグ手順を記録
- [`runbook/_runbook-audio-ops-and-tests.md`](./runbook/_runbook-audio-ops-and-tests.md) - オーディオシステムの運用・テスト手順（Phase 2）

### 🏗️ 構造・設計ルール
- [`structure-directory.md`](./structure-directory.md) - プロジェクトディレクトリ構造
- [`structure-guidelines.md`](./structure-guidelines.md) - コード構造ガイドライン

### 📜 変更履歴（Changelog）
- `changelog-*.md` - 機能別・モジュール別の変更履歴を記録
- [`changelog/changelog-audio.md`](./changelog/changelog-audio.md) - オーディオシステムの変更履歴（Phase 2完了 + 3層アーキテクチャ + Air Layer実験）

### ⚙️ 設定・例外・ルール
- [`lint-exceptions.md`](./lint-exceptions.md) - SwiftLint例外設定

### 📊 報告・記録
- [`report-task-terminology-migration.md`](./report-task-terminology-migration.md) - Task用語移行レポート
- [`report/report-audio-phase1-foundation.md`](./report/report-audio-phase1-foundation.md) - オーディオシステム Phase 1実装報告（基盤構築）
- [`report/report-audio-phase2-safety.md`](./report/report-audio-phase2-safety.md) - オーディオシステム Phase 2実装報告（安全機能・スケジューリング）
- [`report/report-audio-phase3-integration.md`](./report/report-audio-phase3-integration.md) - オーディオシステム Phase 3実装報告（統合・UI連携）
- [`report/report-signal-engine-tpt-svf-fix.md`](./report/report-signal-engine-tpt-svf-fix.md) - Signal Engine TPT-SVFフィルタ置き換え修正レポート（2025-11-18）
- [`report/report-legacy-code-removal-stateful-signal-fix.md`](./report/report-legacy-code-removal-stateful-signal-fix.md) - レガシーコード削除・Stateful Signal修正レポート（2025-11-19）

### 🎧 リファレンス音声
- [`reference-audio/_guide-reference-audio.md`](./reference-audio/_guide-reference-audio.md) - 解析専用の音声ファイル置き場（アプリには同梱しない）

### 🔧 トラブルシューティング・問題分析
- [`report/report-audio-distortion-noise.md`](./report/report-audio-distortion-noise.md) - AVAudioUnitDistortion雑音問題RCA（最重要）★CRITICAL
- [`report/report-audio-interruption-rca.md`](./report/report-audio-interruption-rca.md) - オーディオ中断時の音声バグRCA（3レイヤー設計）
- [`report/report-audio-no-sound-silent-switch.md`](./report/report-audio-no-sound-silent-switch.md) - オーディオ無音問題（サイレントスイッチ）RCA
- [`report/report-audio-sample-rate-mismatch.md`](./report/report-audio-sample-rate-mismatch.md) - サンプルレート不一致によるノイズ問題RCA（パチパチ音）
- [`report/report-jupiter-melody-optimization.md`](./report/report-jupiter-melody-optimization.md) - Jupiter Melody パフォーマンス最適化
- [`report/report-jupiter-harp-interference-fix.md`](./report/report-jupiter-harp-interference-fix.md) - Jupiter-Harp 周波数干渉問題の修正
- [`report/report-jupiter-breath-implementation.md`](./report/report-jupiter-breath-implementation.md) - Jupiter Breath（息継ぎ）実装の試行錯誤と最終方式
- [`report/report-clock-landscape-layout-fix.md`](./report/report-clock-landscape-layout-fix.md) - Clock横向きレイアウト修正（SevenSeg高さ統一、HStack配置）

## 📝 ドキュメント作成・更新ルール

### **ファイル命名規則（Fujiko構造版 + 運用拡張）**
- `_arch-*.md` - 設計思想・アーキテクチャガイドライン
- `_adr-*.md` - アーキテクチャ決定記録（ADR: Architecture Decision Records）
- `_guide-*.md` - 実装手順・操作ガイド
- `_runbook-*.md` - 運用・テスト・デバッグ手順書
- `structure-*.md` - 構造・設計ルール
- `changelog-*.md` - 機能別・モジュール別の変更履歴
- `lint-*.md` - コード規約・例外設定
- `report-*.md` - 作業記録・移行レポート・不具合分析
- `README.md` - フォルダ概要（プレフィックスなし）

### **更新時の注意**
1. 各ドキュメントの「更新履歴」セクションを必ず更新
2. このREADMEの「ドキュメント一覧」も併せて更新
3. 画像やコードサンプルは相対パスで参照
4. **Fujiko構造の命名ルール**に従ってファイル名を決定

### **コミット番号の記載方法**
ドキュメント内で関連するコミットを参照する際は、以下の形式を使用：

- **単一コミット**: ``Commit: `<hash>` - "<commit message>"``
  - 例: ``Commit: `ed3d217` - "Fix timer display issue: ensure initial value shows for full second"``
- **複数コミット**: リスト形式で記載
  - 例:
    ```markdown
    ## 🔗 関連コミット
    - Commit: `ed3d217` - "Fix timer display issue: ensure initial value shows for full second"
    - Commit: `a521704` - "Add report documenting timer initial display fix"
    ```
- **リリースノート**: コミット数を記載する場合
  - 例: `* **Commits:** 19`

**記載場所**:
- `report-*.md`: ドキュメント末尾の「関連コミット」セクションに主要なコミットを記載
- `releases/*.md`: 変更統計セクションにコミット数を記載
- `_guide-*.md`: 必要に応じて関連コミットを記載

## 🔗 関連リンク

### **プロジェクト情報**
- [メインリポジトリ](../) - プロジェクトルート
- [ソースコード](../TsukiUsagi/) - アプリケーションコード

### **外部リソース**
- [SwiftUI公式ドキュメント](https://developer.apple.com/documentation/swiftui/)
- [Cursor公式ドキュメント](https://docs.cursor.sh/)

---

**💡 ヒント**: 新しいドキュメントを追加した際は、このREADMEも忘れずに更新してください！
**🏗️ Fujiko構造**: ファイル名で意味的階層を表現し、「読む順序 = 理解の順序」を実現しています。
