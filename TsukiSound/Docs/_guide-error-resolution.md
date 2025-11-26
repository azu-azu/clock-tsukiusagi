# Error Resolution Guide

エラーが発生した時にまず確認すべき汎用的なチェックリスト

---

## 基本原則

エラー解決は**科学的なデバッグ**です：
1. 現象を観察する
2. 仮説を立てる
3. 検証する
4. 結果から学ぶ

個別の解決策を探す前に、まず**問題を正確に理解する**ことが重要です。

---

## チェックリスト

### 1. WHERE: どこで失敗しているか特定する

エラーが起きる場所を絞り込む：

```swift
// ❌ Bad: 失敗箇所がわからない
do {
    try setupEverything()
} catch {
    print("Failed: \(error)")
}

// ✅ Good: ステップごとにログ
do {
    print("→ Step 1: Session setup")
    try setupSession()

    print("→ Step 2: Engine config")
    try setupEngine()

    print("→ Step 3: Source registration")
    try registerSources()

} catch {
    print("❌ Failed at current step: \(error)")
}
```

**確認すべきこと**:
- [ ] エラーメッセージの直前に何が実行されたか
- [ ] どのファイル・行番号でクラッシュしたか
- [ ] スタックトレースで呼び出し元を確認

---

### 2. WHAT: 現在の状態を確認する

エラー発生時点での状態をログ出力：

```swift
// エラーが起きる前に状態を確認
print("📊 Current State:")
print("  Category: \(session.category)")
print("  Is active: \(session.isOtherAudioPlaying)")
print("  Variable X: \(x)")

try riskyOperation()
```

**確認すべきこと**:
- [ ] 変数の現在値（nil? 空配列? 予期しない値?）
- [ ] オブジェクトの状態（初期化済み? 破棄済み?）
- [ ] システムリソースの状態（メモリ、ファイル、ネットワーク）

---

### 3. WHO: 誰が触っているか確認する

複数の場所が同じリソースを操作していないか：

```
Component A → modifies shared resource
Component B → modifies shared resource  // 競合！
Component C → modifies shared resource  // 誰が責任者？
```

**確認すべきこと**:
- [ ] 責務が重複していないか（例: 複数のクラスが同じセッションを管理）
- [ ] Singletonリソースを複数箇所で初期化していないか
- [ ] 並行アクセスによる競合状態（race condition）はないか

**解決パターン**:
- 責任を1箇所に集約（Single Responsibility）
- 依存性注入で所有権を明確化
- 排他制御（DispatchQueue、Actor）

---

### 4. MINIMAL: 最小構成で動くか確認する

複雑な設定を削ぎ落として、最もシンプルな形で試す：

```swift
// ❌ 最初から全部入り
let config = ComplexConfig(
    option1: value1,
    option2: value2,
    option3: value3,
    option4: value4
)

// ✅ 動く最小構成
let config = ComplexConfig()  // デフォルト設定のみ

// → 動いたら1つずつ追加
config.option1 = value1  // OK
config.option2 = value2  // OK
config.option3 = value3  // ← ここでエラー（犯人特定！）
```

**確認すべきこと**:
- [ ] オプションをすべて外しても失敗するか
- [ ] テストデータを最小限にしても失敗するか
- [ ] 他の機能を無効化しても失敗するか

**手法**: 二分探索的アプローチ
1. 半分無効化 → 動く
2. 無効化した半分を再度半分に → 動かない
3. この半分が怪しい → さらに絞り込む

---

### 5. ISOLATION: 問題を隔離する

他の要素の影響を受けていないか確認：

```swift
// 本番コードから切り離してテスト
func testMinimalCase() {
    let session = AVAudioSession.sharedInstance()

    // 他の設定の影響を受けない状態で試す
    try? session.setActive(false)  // リセット

    try session.setCategory(.playback)  // 最小構成
    try session.setActive(true)
}
```

**確認すべきこと**:
- [ ] 別のViewControllerで試すと動くか
- [ ] 新規プロジェクトで同じコードは動くか
- [ ] 他のライブラリを無効化すると動くか

**目的**: 問題が「このコード」にあるのか、「環境」にあるのか切り分ける

---

### 6. INCREMENT: 一度に一つずつ変更する

複数の変更を同時に行わない：

```swift
// ❌ 一度に複数変更
- オプションAを追加
- オプションBを追加
- 関数Cをリファクタ
→ エラー（どれが原因？）

// ✅ 一つずつ変更
1. オプションAを追加 → テスト → OK
2. オプションBを追加 → テスト → エラー（Bが原因！）
```

**確認すべきこと**:
- [ ] 最後に変更したコードは何か
- [ ] 動いていた時点に戻せるか（git checkout）
- [ ] 変更差分は最小か（大きすぎる変更は分割）

---

### 7. VERIFY: ドキュメントと実機を疑う

公式ドキュメントやStack Overflowの情報が**常に正しいとは限らない**：

**確認すべきこと**:
- [ ] そのAPIは本当にこのiOSバージョンで動くか
- [ ] シミュレータと実機で挙動が違わないか
- [ ] ドキュメントの最終更新日は？（古い情報の可能性）
- [ ] 同じ症状の未解決issueがGitHubにないか

**優先順位**:
1. 実機での動作確認 > ドキュメント
2. 最新のコード例 > 古いStack Overflow回答
3. 公式リファレンス > ブログ記事

---

### 8. ERROR CODE: エラーコードの意味を理解する

エラーコードは「種類」を教えるだけ。「原因」は自分で探す：

```
OSStatus -50
→ 意味: 「パラメータが無効」
→ 教えてくれない: 「どのパラメータが無効か」
→ 自分で調べる: 段階的除去法
```

**確認すべきこと**:
- [ ] エラードメイン（NSOSStatusError, NSCocoaError, など）
- [ ] エラーコード番号の定数名（-50 = kAudioSessionInvalidPropertySize）
- [ ] エラーのuserInfo辞書（追加情報が含まれることがある）

**検索のコツ**:
- エラーコード番号で検索（例: "OSStatus -50 iOS"）
- エラーメッセージの**英語部分**で検索
- プラットフォーム+バージョンを含める（例: "iOS 17 AVAudioSession error"）

---

### 9. SCOPE: 問題の範囲を絞る

広範囲のバグは、小さく切り分ける：

```
「アプリがクラッシュする」
↓ 範囲を絞る
「特定の画面でクラッシュする」
↓ さらに絞る
「その画面の特定のボタンを押すとクラッシュする」
↓ もっと絞る
「そのボタンのネットワーク処理でクラッシュする」
```

**確認すべきこと**:
- [ ] 毎回同じ操作で再現するか（再現性）
- [ ] 特定の条件下でのみ起きるか（ネットワーク、バックグラウンド、低メモリ）
- [ ] 最小の再現手順は何か（10ステップ → 3ステップに削減）

---

### 10. RESOURCE: リソースの制約を確認する

システムリソースの問題かもしれない：

**確認すべきこと**:
- [ ] メモリ不足（Instruments - Allocations）
- [ ] ファイルディスクリプタ枯渇（開きすぎたファイル/接続）
- [ ] スレッド数制限
- [ ] ディスク容量不足
- [ ] ネットワーク接続状態

**デバッグツール**:
- Xcode Memory Graph（メモリリーク検出）
- Instruments（パフォーマンス計測）
- Console.app（システムログ全体）
- Network Link Conditioner（ネットワーク遅延シミュレート）

---

## デバッグの流れ（推奨手順）

```
1. WHERE: エラー箇所を特定（ステップごとログ）
   ↓
2. WHAT: 現在の状態を確認（変数の値を出力）
   ↓
3. MINIMAL: 最小構成で試す（オプションをすべて外す）
   ↓
4. INCREMENT: 一つずつ追加（犯人を特定）
   ↓
5. ISOLATION: 問題を隔離（新規プロジェクトで試す）
   ↓
6. WHO: 責務の重複を確認（複数箇所が同じリソースを触っていないか）
   ↓
7. VERIFY: 実機で確認（ドキュメントより実機が真実）
   ↓
8. 解決！
```

---

## よくある間違い

### ❌ やってはいけないこと

1. **エラーメッセージを読まずに解決策を探す**
   - エラーは重要なヒントを含んでいる

2. **複数箇所を同時に変更する**
   - どれが効いたかわからなくなる

3. **動かないコードをコピペで増やす**
   - 問題が広がるだけ

4. **ログを出さずに推測で直す**
   - 運任せのデバッグは再発する

5. **シミュレータだけでテストする**
   - 実機で動かない可能性がある

### ✅ やるべきこと

1. **エラーメッセージを精読する**
   - ファイル名、行番号、エラーコードをメモ

2. **動く最小構成を作る**
   - 確実に動く状態から始める

3. **変更を小さく保つ**
   - 1変更 → テスト → コミットのサイクル

4. **ログを積極的に使う**
   - print(), os_log(), Instruments

5. **実機で検証する**
   - 特にハードウェア関連（カメラ、マイク、センサー、オーディオ）

---

## 記録を残す

解決したエラーは**必ずドキュメント化**する：

```markdown
## Issue: OSStatus -50 on Audio Session

**Problem**: setCategory failed with -50
**Root Cause**: .allowBluetooth option incompatible
**Solution**: Remove .allowBluetooth option
**Date**: 2025-11-10
**Verified on**: iOS 17.x, iPhone 15 Pro
```

**理由**:
- 同じエラーに二度遭遇しない
- チームメンバーが同じ罠を避けられる
- 将来の自分が感謝する

---

## まとめ

エラー解決は**探偵の仕事**：

1. **観察**: 現象を正確に記録する
2. **仮説**: 原因を推測する
3. **実験**: 最小構成で検証する
4. **記録**: 結果を文書化する

焦らず、系統的に、一歩ずつ。

---

**最も重要なこと**:
**Make it work → Make it right → Make it fast**

まず動かす。次に正しく。最後に速く。
