# Live Activity 設定ガイド

## ⚠️ このガイドは廃止されました（2025-11-24）

> **Live Activity 実装は現在、無効化されています。**
>
> **廃止した理由：**
> - ロック画面で Live Activity と Now Playing UI が同時に表示され、ユーザーが混乱した
> - Live Activity には再生 / 一時停止ボタンがなく、"情報ビュー"に過ぎない
> - ロック画面での直接操作（再生/一時停止）は Now Playing の方が圧倒的に重要
>
> **現在の仕様：**
> - ロック画面の操作は **Now Playing controls（MPRemoteCommandCenter）** を使用
> - Dynamic Island 表示は必要性が下がったため廃止
> - 参照: [NowPlayingController.swift](../TsukiSound/Core/Services/NowPlaying/NowPlayingController.swift)
> - 参照: [AudioService.swift](../TsukiSound/Core/Audio/AudioService.swift) (setupNowPlayingCommands)
>
> **再び Live Activity を使うなら：**
> - Now Playing（操作）と Live Activity（状態表示）の役割を完全に分離して設計すること
> - このガイドは参考資料として活用できます

---

iOS 16.1以降で利用可能なLive Activityをアプリに実装する手順書です。ロック画面とDynamic Island（iPhone 14 Pro以降）に動的な情報を表示できます。

## 目次

1. [プロジェクト設定](#1-プロジェクト設定)
2. [Widget Extension作成](#2-widget-extension作成)
3. [Activity Attributes定義](#3-activity-attributes定義)
4. [Widget UI実装](#4-widget-ui実装)
5. [メインアプリ統合](#5-メインアプリ統合)
6. [トラブルシューティング](#6-トラブルシューティング)

---

## 1. プロジェクト設定

### 1.1 Info.plistの設定

**メインアプリターゲット**の`Info.plist`に以下のキーを追加：

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

⚠️ **重要**: このキーがないとLive Activityが一切動作しません。

### 1.2 Background Modes（既存の設定）

オーディオアプリの場合、すでに以下の設定があるはずです：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

---

## 2. Widget Extension作成

### 2.1 Xcodeでの作成手順

1. **File > New > Target...**
2. **Widget Extension** を選択
3. 設定項目：
   - **Product Name**: `AudioLiveActivity` （任意の名前）
   - **Include Live Activity**: ✅ チェックを入れる
   - **Include Configuration Intent**: ❌ チェックを外す

### 2.2 自動生成されるファイル

```
AudioLiveActivity/
├── AudioLiveActivityLiveActivity.swift  # Widget UI
├── AudioLiveActivityBundle.swift        # Bundle定義
├── Info.plist                           # Widget Extension設定
└── Assets.xcassets/                     # リソース
```

⚠️ **注意**: Xcodeがテンプレートコードを自動生成しますが、これは全て置き換えます。

---

## 3. Activity Attributes定義

### 3.1 共通定義ファイルの作成

Live Activityで表示するデータ構造を定義します。**メインアプリとWidget Extension両方で同じ定義が必要**です。

#### ファイル構成

```
TsukiSound/Core/Activity/AudioActivityAttributes.swift  # メインアプリ
AudioLiveActivity/AudioActivityAttributes.swift               # Widget Extension（コピー）
```

#### 実装例

```swift
import ActivityKit
import Foundation

/// Activity Attributes for Live Activity on Lock Screen and Dynamic Island
@available(iOS 16.1, *)
public struct AudioActivityAttributes: ActivityAttributes {
    /// Dynamic state that changes during activity lifetime
    public struct ContentState: Codable, Hashable {
        /// Current playback state
        public var isPlaying: Bool

        /// Scheduled break time (if quiet breaks enabled)
        public var nextBreakAt: Date?

        /// Current audio output route
        public var outputRoute: String  // "Headphones", "Bluetooth", "Speaker"

        /// Reason for pause (if not playing)
        public var pauseReason: String?

        /// Current preset name
        public var presetName: String?

        public init(
            isPlaying: Bool,
            nextBreakAt: Date? = nil,
            outputRoute: String,
            pauseReason: String? = nil,
            presetName: String? = nil
        ) {
            self.isPlaying = isPlaying
            self.nextBreakAt = nextBreakAt
            self.outputRoute = outputRoute
            self.pauseReason = pauseReason
            self.presetName = presetName
        }
    }

    public init() {}
}
```

### 3.2 重要なポイント

✅ **必須要件:**
- `ActivityAttributes` プロトコルに準拠
- `ContentState` は `Codable, Hashable` に準拠
- **すべてのプロパティとイニシャライザに`public`修飾子**を付ける
- `ContentState` に `public init()` を実装

❌ **よくある間違い:**
- `struct` に `public` を付け忘れる → Widget Extensionから見えない
- `init()` を実装しない → コンパイルエラー
- `var` を `public` にしない → Widget UIでアクセスできない

### 3.3 ファイルの配置方法

**方法1: ファイルをコピー（今回採用）**

```bash
cp TsukiSound/Core/Activity/AudioActivityAttributes.swift AudioLiveActivity/
```

**方法2: Xcodeでターゲットメンバーシップを追加**

1. ファイルを選択
2. File Inspector（右サイドバー）
3. Target Membership で両方のターゲットにチェック

⚠️ **注意**: 方法2の場合、変更が両ターゲットに自動反映されるが、ビルド設定に注意が必要。

---

## 4. Widget UI実装

### 4.1 Widget本体の実装

`AudioLiveActivity/AudioLiveActivityLiveActivity.swift` を以下のように実装：

```swift
import ActivityKit
import WidgetKit
import SwiftUI

struct AudioLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AudioActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: context.state.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                            .foregroundColor(context.state.isPlaying ? .green : .orange)
                        Text(context.state.presetName ?? "音声")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.outputRoute)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let nextBreak = context.state.nextBreakAt {
                            Text("次の休憩: \(nextBreak, style: .time)")
                                .font(.caption2)
                        } else if let reason = context.state.pauseReason {
                            Text("停止: \(reason)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .foregroundColor(context.state.isPlaying ? .green : .orange)
            } compactTrailing: {
                Image(systemName: audioOutputIcon(for: context.state.outputRoute))
                    .font(.caption2)
            } minimal: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
            }
            .keylineTint(Color.green)
        }
    }
}
```

### 4.2 Lock Screen View実装

```swift
struct LockScreenView: View {
    let state: AudioActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: state.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(state.isPlaying ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                // Preset name
                Text(state.presetName ?? "クリック音防止")
                    .font(.headline)
                    .foregroundColor(.white)

                // Output route
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                    Text(state.outputRoute)
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                // Next break or pause reason
                if let nextBreak = state.nextBreakAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("休憩: \(nextBreak, style: .time)")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                } else if let reason = state.pauseReason {
                    Text("停止理由: \(reason)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(16)
    }
}
```

### 4.3 ヘルパー関数

```swift
/// Get SF Symbol icon for audio output route
private func audioOutputIcon(for route: String) -> String {
    let lowercased = route.lowercased()
    if lowercased.contains("headphone") || lowercased.contains("ヘッドホン") {
        return "headphones"
    } else if lowercased.contains("bluetooth") || lowercased.contains("ブルートゥース") {
        return "antenna.radiowaves.left.and.right"
    } else if lowercased.contains("speaker") || lowercased.contains("スピーカー") {
        return "speaker.wave.2"
    } else {
        return "speaker.wave.1"
    }
}
```

### 4.4 Dynamic Islandのレイアウト

**Expanded（展開時）:**
```
┌─────────────────────────────────────┐
│ [▶️] プリセット名  │  ヘッドホン   │
│                                     │
│        次の休憩: 15:30              │
└─────────────────────────────────────┘
```

**Compact（通常時）:**
```
[🔊] ... [🎧]
```

**Minimal（最小時）:**
```
[🔊]
```

### 4.5 デザインガイドライン

| 要素 | 推奨 | 説明 |
|------|------|------|
| アイコンサイズ（ロック画面） | 40pt | 視認性を確保 |
| フォント（プリセット名） | `.headline` | 重要情報 |
| フォント（詳細情報） | `.caption` / `.caption2` | 補足情報 |
| 背景色 | `Color.black.opacity(0.8)` | 可読性 |
| テキスト色 | `.white` / `.secondary` | コントラスト |
| アクセント色 | 緑（再生）、オレンジ（停止） | 状態識別 |

⚠️ **Dynamic Island注意点:**
- コンパクトビューは非常に小さい（テキストより**アイコン推奨**）
- 最小ビューは1つのアイコンのみ
- 展開ビューも情報量を絞る（1-2行）

---

## 5. メインアプリ統合

### 5.1 Activity Controllerの実装

Live Activityのライフサイクルを管理するコントローラーを作成：

```swift
import ActivityKit
import Foundation

@available(iOS 16.1, *)
@MainActor
final class AudioActivityController: ObservableObject {
    private var currentActivity: Activity<AudioActivityAttributes>?

    @Published private(set) var isActivityActive: Bool = false

    /// Start a new Live Activity
    func startActivity(
        isPlaying: Bool,
        nextBreakAt: Date?,
        outputRoute: String,
        pauseReason: String?,
        presetName: String?
    ) {
        endActivity()  // 既存のActivityを終了

        let attributes = AudioActivityAttributes()
        let contentState = AudioActivityAttributes.ContentState(
            isPlaying: isPlaying,
            nextBreakAt: nextBreakAt,
            outputRoute: outputRoute,
            pauseReason: pauseReason,
            presetName: presetName
        )

        do {
            if #available(iOS 16.2, *) {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: nil),
                    pushType: nil
                )
            } else {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
            }
            isActivityActive = true
            print("[AudioActivityController] Live Activity started")
        } catch {
            print("[AudioActivityController] Failed to start: \(error)")
            isActivityActive = false
        }
    }

    /// Update existing Live Activity
    func updateActivity(
        isPlaying: Bool,
        nextBreakAt: Date?,
        outputRoute: String,
        pauseReason: String?,
        presetName: String?
    ) {
        guard let activity = currentActivity else { return }

        let contentState = AudioActivityAttributes.ContentState(
            isPlaying: isPlaying,
            nextBreakAt: nextBreakAt,
            outputRoute: outputRoute,
            pauseReason: pauseReason,
            presetName: presetName
        )

        Task {
            if #available(iOS 16.2, *) {
                await activity.update(.init(state: contentState, staleDate: nil))
            } else {
                await activity.update(using: contentState)
            }
        }
    }

    /// End the current Live Activity
    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
            currentActivity = nil
            isActivityActive = false
        }
    }
}
```

### 5.2 AudioServiceへの統合

```swift
@MainActor
public final class AudioService: ObservableObject {
    // Live Activity
    private var activityController: AudioActivityController?

    private init() {
        // 初期化
        if #available(iOS 16.1, *) {
            self.activityController = AudioActivityController()
        }
    }

    /// 再生開始時
    public func play(preset: NaturalSoundPreset) throws {
        // ... 再生処理 ...

        isPlaying = true
        currentPreset = preset

        // Live Activityを更新
        updateLiveActivity()
    }

    /// 停止時
    public func stop() {
        // ... 停止処理 ...

        isPlaying = false

        // Live Activityを終了
        endLiveActivity()
    }

    /// Live Activity更新
    private func updateLiveActivity() {
        guard #available(iOS 16.1, *), settings.liveActivityEnabled else { return }
        guard let controller = activityController else { return }

        let route = outputRoute.displayName
        let nextBreak = breakScheduler.nextBreakAt
        let presetName = currentPreset.map { "\($0)" }

        if isPlaying {
            if !controller.isActivityActive {
                controller.startActivity(
                    isPlaying: true,
                    nextBreakAt: nextBreak,
                    outputRoute: route,
                    pauseReason: nil,
                    presetName: presetName
                )
            } else {
                controller.updateActivity(
                    isPlaying: true,
                    nextBreakAt: nextBreak,
                    outputRoute: route,
                    pauseReason: nil,
                    presetName: presetName
                )
            }
        }
    }

    /// Live Activity終了
    private func endLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        activityController?.endActivity()
    }
}
```

### 5.3 設定の追加

```swift
public struct AudioSettings: Codable {
    /// Live Activityを有効化
    public var liveActivityEnabled: Bool = true  // デフォルトtrue

    public init(
        // ...
        liveActivityEnabled: Bool = true
    ) {
        // ...
        self.liveActivityEnabled = liveActivityEnabled
    }
}
```

⚠️ **重要**: デフォルトを`true`にしないと初回起動時に動作しません。

---

## 6. トラブルシューティング

### 6.1 Dynamic Islandに表示されない

**症状**: クリックはできるが何も表示されない

**原因と解決策**:

1. **Info.plistにキーがない**
   ```xml
   <key>NSSupportsLiveActivities</key>
   <true/>
   ```

2. **設定がOFFになっている**
   - `AudioSettings.liveActivityEnabled` が `false`
   - デフォルト値を `true` に変更

3. **Widget Extensionファイルが古い**
   - Xcodeのテンプレートコードが残っている
   - 本ガイドのUIコードで上書き

4. **`public` 修飾子がない**
   - `AudioActivityAttributes` が `struct` のまま
   - `public struct` に変更
   - すべてのプロパティに `public var`

### 6.2 ビルドエラー: "Cannot find type 'AudioActivityAttributes'"

**原因**: Widget ExtensionからAttributesファイルが見えていない

**解決策**:
```bash
cp TsukiSound/Core/Activity/AudioActivityAttributes.swift AudioLiveActivity/
```

または、Xcodeでターゲットメンバーシップを追加。

### 6.3 "s" などの1文字だけ表示される

**原因**: `Text(context.state.outputRoute.prefix(1))` を使用

**解決策**: アイコンに変更
```swift
Image(systemName: audioOutputIcon(for: context.state.outputRoute))
```

### 6.4 Live Activityが更新されない

**チェックリスト**:
- [ ] `updateLiveActivity()` が呼ばれているか？
- [ ] `settings.liveActivityEnabled` が `true` か？
- [ ] `activityController` が `nil` でないか？
- [ ] iOS 16.1以降のデバイスか？

### 6.5 シミュレータで動作しない

⚠️ **制限事項**: Live Activityはシミュレータでは**正常に動作しません**。

**必須**: 実機（iPhone）でテスト
- iOS 16.1以降
- Dynamic Islandは iPhone 14 Pro以降のみ

---

## 7. ベストプラクティス

### 7.1 更新タイミング

✅ **更新すべき時:**
- 再生状態変更（play/pause）
- 出力先変更（ヘッドホン抜き差し）
- 次の休憩時刻が変わった時

❌ **更新しすぎない:**
- 1秒ごとなどの高頻度更新は避ける
- バッテリー消費が増加
- システムがスロットリングする可能性

### 7.2 データ設計

**ContentStateには必要最小限の情報のみ:**
- 表示に必要なデータだけ
- 複雑なオブジェクトは避ける
- 文字列、数値、Date、Bool程度

**Attributesは固定情報:**
- アプリ名など、変わらない情報
- 今回は空（デフォルトイニシャライザのみ）

### 7.3 セキュリティ

⚠️ **注意**: Live Activityはロック画面に表示されます

- 個人情報を表示しない
- アカウント名、メールアドレスなどNG
- 一般的な状態情報のみ

---

## 8. チェックリスト

実装完了時の確認項目：

- [ ] メインアプリ `Info.plist` に `NSSupportsLiveActivities` 追加
- [ ] Widget Extension作成（Include Live Activity ON）
- [ ] `AudioActivityAttributes.swift` を両ターゲットに配置
- [ ] すべての型に `public` 修飾子
- [ ] `ContentState` に `public init()` 実装
- [ ] Widget UIにLockScreenView実装
- [ ] Dynamic Island（Expanded/Compact/Minimal）実装
- [ ] `AudioActivityController` 実装
- [ ] `AudioService` に統合
- [ ] `liveActivityEnabled` デフォルト `true`
- [ ] ビルド成功
- [ ] 実機でテスト（ロック画面 + Dynamic Island）

---

## 9. 参考情報

### 9.1 公式ドキュメント

- [ActivityKit | Apple Developer](https://developer.apple.com/documentation/activitykit)
- [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

### 9.2 iOS バージョン要件

| 機能 | iOS要件 |
|------|---------|
| Live Activity基本機能 | iOS 16.1+ |
| Dynamic Island | iOS 16.1+ & iPhone 14 Pro以降 |
| Push更新 | iOS 16.2+ |

### 9.3 デバイス要件

| デバイス | ロック画面 | Dynamic Island |
|---------|-----------|----------------|
| iPhone 14 Pro/Pro Max | ✅ | ✅ |
| iPhone 15 Pro/Pro Max | ✅ | ✅ |
| iPhone 14/Plus | ✅ | ❌ |
| iPhone 15 | ✅ | ❌ |
| iPhone 13以前 | ✅ | ❌ |

---

## まとめ

Live Activityの実装で最も重要なポイント：

1. **Info.plistに `NSSupportsLiveActivities` 必須**
2. **`public` 修飾子を忘れない**（Widget Extensionから見えない）
3. **AttributesファイルをWidget Extensionにコピー**
4. **Dynamic Islandはアイコン中心のデザイン**（スペースが狭い）
5. **実機でテスト**（シミュレータは不完全）

このガイドに従えば、次回も同じようにLive Activityを実装できます。
