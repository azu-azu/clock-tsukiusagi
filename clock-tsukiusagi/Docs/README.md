# TsukiUsagi ドキュメント

このディレクトリには、TsukiUsagiプロジェクトの開発・運用に関するドキュメントが含まれています。

## 🗂️ TsukiUsagi Docs Naming Rules（Fujiko構造版）

## 🧭 **命名フォーマット**

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
| `report-`    | 報告層      | 作業記録・移行レポート・結果報告  | `report-task-terminology-migration.md`              |
| `trouble-`   | 対応層      | 不具合・検証・原因分析       | `trouble-cursor-swift.md`                           |
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
- [`_arch-guidelines.md`](./_arch-guidelines.md) - アーキテクチャガイドライン・設計原則

### 🎯 アーキテクチャ決定記録（ADR）
- `_adr-*.md` - 設計判断の背景・トレードオフ・決定理由を記録
- 例：`_adr-audio-service-singleton.md` - AudioService Singleton採用の決定記録

### 🔧 実装ガイド・手順書
- [`_guide-error-resolution.md`](./_guide-error-resolution.md) - エラー解決ガイド（汎用チェックリスト）
- [`_guide-font.md`](./_guide-font.md) - フォント使用ガイドライン
- [`_guide-font-installation.md`](./_guide-font-installation.md) - Nunitoフォントのインストール手順
- [`_guide-keyboard.md`](./_guide-keyboard.md) - キーボード操作ガイドライン
- [`_guide-notifications-fg-bg.md`](./_guide-notifications-fg-bg.md) - フォアグラウンド・バックグラウンド通知ガイド
- [`_guide-quiet-moon-animation.md`](./_guide-quiet-moon-animation.md) - Quiet Moon状態からのSTART時アニメーション不発火問題の修正ガイド

### 📖 運用・テスト手順書（Runbook）
- `_runbook-*.md` - 運用手順、テスト手順、デバッグ手順を記録
- 例：`_runbook-audio-ops-and-tests.md` - オーディオシステムの運用・テスト手順

### 🏗️ 構造・設計ルール
- [`structure-directory.md`](./structure-directory.md) - プロジェクトディレクトリ構造
- [`structure-guidelines.md`](./structure-guidelines.md) - コード構造ガイドライン

### 📜 変更履歴（Changelog）
- `changelog-*.md` - 機能別・モジュール別の変更履歴を記録
- 例：`changelog-audio.md` - オーディオシステムの変更履歴

### ⚙️ 設定・例外・ルール
- [`lint-exceptions.md`](./lint-exceptions.md) - SwiftLint例外設定

### 📊 報告・記録
- [`report-task-terminology-migration.md`](./report-task-terminology-migration.md) - Task用語移行レポート

### 🔧 トラブルシューティング
- [`trouble-audio-distortion-noise.md`](./trouble-audio-distortion-noise.md) - AVAudioUnitDistortion雑音問題RCA（最重要）
- [`trouble-audio-no-sound-silent-switch.md`](./trouble-audio-no-sound-silent-switch.md) - オーディオ無音問題（サイレントスイッチ）RCA
- [`trouble-cursor-swift.md`](./trouble-cursor-swift.md) - Cursor Swift拡張のトラブルシューティング

## 📝 ドキュメント作成・更新ルール

### **ファイル命名規則（Fujiko構造版 + 運用拡張）**
- `_arch-*.md` - 設計思想・アーキテクチャガイドライン
- `_adr-*.md` - アーキテクチャ決定記録（ADR: Architecture Decision Records）
- `_guide-*.md` - 実装手順・操作ガイド
- `_runbook-*.md` - 運用・テスト・デバッグ手順書
- `structure-*.md` - 構造・設計ルール
- `changelog-*.md` - 機能別・モジュール別の変更履歴
- `lint-*.md` - コード規約・例外設定
- `report-*.md` - 作業記録・移行レポート
- `trouble-*.md` - トラブルシューティング
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