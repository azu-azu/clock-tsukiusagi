# RCA Report: Audio System No Sound Issue

**日付**: 2025-11-09
**報告者**: Claude Code
**ステータス**: ✅ Resolved

---

## 📋 Executive Summary

オーディオシステムが正常に起動しているにもかかわらず、実機で音が出ない問題が発生。根本原因はAVAudioSessionのカテゴリ選択とデバイスのサイレントスイッチの相互作用。

**解決策**: `.ambient` → `.playback` カテゴリに変更

---

## 🔍 Problem Statement

### 症状
- AudioPlaybackView（旧AudioTestView）で再生ボタンを押しても音が出ない
- UIは「再生中」状態を表示
- エラーメッセージなし
- コンソールに異常なログなし

### 環境
- **デバイス**: iPhone実機
- **iOS**: （バージョン不明）
- **Xcode**: デバッグモード
- **音源**: Oscillator（220Hz サイン波）

---

## 🕵️ Investigation Timeline

### Phase 1: 初期エラー（OSStatus -50）
**症状**: `AVAudioSessionClient_Common.mm:600 Failed to set properties, error: -50`

**調査結果**:
- AVAudioSession の設定パラメータエラー
- Background Modes設定との不一致

**対策**:
1. AudioSessionManager にエラーハンドリング追加
2. セッション設定前に既存セッションを非アクティブ化
3. カテゴリを `.ambient` に簡素化（Background Modes不要）

**結果**: ✅ エラー解消、セッションは正常にアクティベート

---

### Phase 2: 音が出ない問題
**症状**: エラーなし、再生中表示、しかし無音

**調査内容**:
```
✅ AudioSessionManager: Session activated successfully
✅ LocalAudioEngine: AVAudioEngine started
✅ LocalAudioEngine: All audio sources started
✅ Oscillator: Rendering 1024 frames, amplitude: 0.3
✅ AudioPlaybackView: Device volume: 1.0
✅ AudioPlaybackView: Master volume: 1.0
```

**重要な発見**:
- レンダーブロックは**正常に動作**（1024フレームごとにコールバック）
- 振幅は0.3（適切な音量）
- デバイス音量は1.0（最大）
- マスター音量は1.0（最大）

**仮説**:
1. ~~音源の接続問題~~ → ログから否定
2. ~~音量がゼロ~~ → ログから否定
3. ~~レンダーブロックが動いていない~~ → ログから否定
4. **サイレントスイッチの影響** ← これが正解

---

## 🎯 Root Cause Analysis

### 根本原因
**AVAudioSession カテゴリ `.ambient` がサイレントスイッチを尊重する**

### 技術的詳細

#### AVAudioSession カテゴリの挙動

| カテゴリ | サイレントスイッチ | 他アプリと混在 | バックグラウンド再生 | Background Modes必須 |
|---------|-------------------|---------------|----------|---------------------|
| `.ambient` | ✅ **尊重する** | ✅ 可能 | ✅ 可能 | ❌ 不要 |
| `.soloAmbient` | ✅ 尊重する | ❌ 不可 | ❌ 不可 | ❌ 不要 |
| `.playback` | ❌ **無視する** | 設定次第 | ✅ 可能 | ✅ 必要 |

#### 問題の流れ

```
1. 実機のサイレントスイッチ = ON（オレンジ色が見える）
   ↓
2. AVAudioSession カテゴリ = .ambient
   ↓
3. .ambient はサイレントスイッチを尊重
   ↓
4. オーディオ出力がミュート
   ↓
5. レンダーブロックは動作するが、ハードウェア出力が無効化
   ↓
6. 結果: 音が出ない
```

### なぜログに異常が出なかったか

- AVAudioEngine は正常に動作している
- レンダーブロックも正常にコールバックされている
- システムレベルでハードウェア出力がミュートされているだけ
- **アプリケーションレベルではエラーではない**

---

## ✅ Solution

### 実施した対策

**LocalAudioEngine.swift の修正**:

```swift
// Before (問題のあるコード)
try sessionManager.activate(
    category: .ambient,
    options: [],
    background: false
)

// After (修正後)
try sessionManager.activate(
    category: .playback,        // サイレントスイッチを無視
    options: [.mixWithOthers],  // 他アプリと共存
    background: false
)
```

### 変更の影響

#### ✅ メリット
- **サイレントスイッチがONでも音が出る**
- ユーザー体験の向上（意図した通りに音が鳴る）
- 他のアプリの音楽と共存可能（`.mixWithOthers`）

#### ⚠️ デメリット / 考慮点
- 公共の場で意図せず音が出る可能性
  - **対策**: UIで明確に「再生中」を表示
- Background Modes 設定が必要になる可能性
  - 現状は `background: false` なので不要

---

## 📊 Verification

### テスト結果

**Before (`.ambient`)**:
```
✅ エンジン起動
✅ レンダーブロック動作
❌ 音が出ない（サイレントスイッチON時）
```

**After (`.playback`)**:
```
✅ エンジン起動
✅ レンダーブロック動作
✅ 音が出る（サイレントスイッチの状態に関わらず）
```

### コンソールログ（成功時）
```
LocalAudioEngine: Trying .playback category (ignores silent switch)...
AudioSessionManager: Category: AVAudioSessionCategoryPlayback
AudioSessionManager: Session activated successfully
LocalAudioEngine: Audio session activated successfully with .playback
Oscillator: Rendering 1024 frames, amplitude: 0.3
```

**結果**: 220Hz サイン波が正常に出力

---

## 🎓 Lessons Learned

### 技術的教訓

1. **AVAudioSession カテゴリの理解が重要**
   - 各カテゴリの挙動（特にサイレントスイッチとの関係）を正確に把握する
   - ドキュメントだけでなく、実機での動作確認が必須

2. **ログの解釈**
   - 「エラーなし」≠「正常動作」
   - システムレベルの制約はアプリケーションログに現れない

3. **デバイスハードウェア状態の確認**
   - サイレントスイッチ
   - 音量ボタン
   - Bluetooth接続状態

### デバッグ手法

**効果的だった方法**:
- レンダーブロック内での詳細ログ出力
- 各処理ステップでの `fflush(stdout)`
- デバイス音量の明示的な確認

**改善できる点**:
- 最初からサイレントスイッチの状態を確認すべきだった
- AVAudioSession カテゴリの挙動表を事前に作成すべきだった

---

## 🔄 Preventive Measures

### 今後の対策

1. **ドキュメント化**
   - AVAudioSession カテゴリの選択ガイドを作成
   - 各カテゴリの use case を明記

2. **コード改善**
   - サイレントスイッチの状態をログ出力
   ```swift
   // TODO: Add to AudioSessionManager
   let isSilentSwitchOn = // 検出方法を調査
   print("Silent switch: \(isSilentSwitchOn ? "ON" : "OFF")")
   ```

3. **テストプロセス**
   - 実機テストのチェックリストに追加
     - [ ] サイレントスイッチOFFで音が出るか
     - [ ] サイレントスイッチONで音が出るか（.playbackの場合）
     - [ ] 音量ボタンで音量が変わるか

4. **UI改善**
   - 設定画面でカテゴリを選択可能に
   - 「サイレントスイッチを無視する」トグルの追加

---

## 📝 Related Issues

### 未解決の問題

1. **焚き火の音が出ない**
   - BandpassNoise の接続に問題がある可能性
   - 次回調査予定

2. **Background Modes 設定**
   - 現在は `background: false`
   - 将来的にバックグラウンド再生を有効にする場合、Info.plistの設定が必要

---

## 📚 References

- [Apple Documentation: AVAudioSession](https://developer.apple.com/documentation/avfoundation/avaudiosession)
- [Audio Session Programming Guide](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html)
- [Working with Audio in iOS](https://developer.apple.com/documentation/avfoundation/audio_playback_recording_and_processing)

---

## 🔗 関連コミット

- Commit: `198756c` - "WIP: Add audio system with debugging - audio session works but no sound output"
- Commit: `e6946bd` - "Fix audio playback issue - change category from .ambient to .playback"

---

## ✍️ Conclusion

**根本原因**: AVAudioSession カテゴリ `.ambient` がデバイスのサイレントスイッチを尊重するため、スイッチON時は音が出力されない

**解決方法**: カテゴリを `.playback` に変更し、サイレントスイッチを無視する設定に変更

**教訓**: オーディオ関連の問題はソフトウェアだけでなく、ハードウェア状態も考慮する必要がある

---

**Status**: ✅ Closed
**Resolution**: Fixed by changing AVAudioSession category from `.ambient` to `.playback`

---

**Ask the essential questions. Design the meaning.**
問いを立てよ。意味を設計せよ。
