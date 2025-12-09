# SwiftUI List ドラッグ時の黒背景問題と解決

## 日付
2025-12-09

## 概要
SwiftUI の `List` + `.onMove` でドラッグ並び替えを実装した際、行をドラッグ開始（リフト）する時にセルの周囲に黒背景が表示される問題が発生した。

本ドキュメントでは、試行錯誤の過程と最終的な解決策を記録する。

---

## 問題の現象

ドラッグでセルをリフトすると、セルのスナップショット画像が作成される。このとき、セルの周囲（特にカード間の隙間部分）に**黒背景**が表示された。

```
┌─────────────────────┐
│ [ドラッグ中のセル]    │ ← セル自体は見える
│                     │
└─────────────────────┘
 ↑ 黒背景がチラッと見える
```

---

## 原因

### なぜ黒が見えるのか

SwiftUI の `List` は、ドラッグでセルをリフトする際に**セル全体のスナップショット画像**を作成する。このスナップショットには `listRowBackground` で指定した背景が含まれる。

```swift
.listRowBackground(Color.clear)  // 透明を指定
```

透明を指定すると、スナップショットの背景も透明になる。その結果、**List 内部のデフォルト背景（黒）** が透けて見えていた。

### 思考の誤り

「黒背景を**消す**」ことに固執し、以下を試した：

1. `.listRowBackground(Color.clear)` → 透明にしても黒が透ける
2. `.scrollContentBackground(.hidden)` → List の背景は消えるが、ドラッグ中は別
3. `.listStyle(.plain)` → スタイル変更しても黒は残る

すべて「黒を消す」アプローチだったが、**黒は List の内部動作で発生するため消せない**。

正しいアプローチは「黒を**隠す**」ことだった。

---

## 試行1: カスタムジェスチャーによる実装（失敗）

黒背景問題を「SwiftUI の限界」と判断し、`List` を使わず `VStack` + カスタムジェスチャーで実装を試みた。

```swift
VStack(spacing: 8) {
    ForEach(presets, id: \.id) { preset in
        PlaylistRowView(...)
            .offset(y: isDragging ? dragOffset : 0)
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.15)
                    .sequenced(before: DragGesture())
                    .onChanged { ... }
                    .onEnded { ... }
            )
    }
}
```

### 発生した問題

#### 1. オーバーシュート（行き過ぎ）
- ドラッグ中に `move()` を毎フレーム呼ぶと、配列が連続して変更される
- インデックスが変わり続け、意図した位置を通り過ぎる
- **対策**: `onChanged` では見た目（offset）だけ動かし、`onEnded` で1回だけ `move()` する

#### 2. 複数セルのジェスチャー競合
- ドラッグ中に他のセルの `LongPressGesture` も反応してしまう
- 結果、ドラッグが途中で切れたり、応答しなくなる
- **対策**: `activeDragId` で現在ドラッグ中のセルIDを管理し、他セルのジェスチャーを無視

#### 3. ForEach の id 問題
- `enumerated()` を使うと、配列順序変更時に id が変わる
- id が変わるとビューが再生成され、ジェスチャー状態がリセットされる
- **対策**: `ForEach(presets, id: \.id)` で preset 自体の id を使う

#### 4. 方向依存の不具合
- 上→下のドラッグは動くが、下→上が動かない（またはその逆）
- `defer` の配置ミスでドラッグ状態が不正にリセットされていた

### カスタムジェスチャーの結論

標準の iOS ドラッグ操作と比べて、以下の点で劣っていた：

- 挙動が不安定（修正しても別のバグが発生）
- 触覚フィードバックのタイミングが不自然
- 「見慣れたドラッグ感」がない

**結果: カスタムジェスチャー案は破棄**

---

## 解決策: 不透明な背景で黒を隠す

### 発想の転換

「黒を消す」のではなく「黒を**隠す**」。

`listRowBackground` に**不透明なカード色**を指定すれば、スナップショットにもその色が含まれ、黒は見えなくなる。

### 最終的な実装

```swift
List {
    ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
        PlaylistRowView(
            preset: preset,
            isCurrentTrack: index == currentIndex,
            isPlaying: isPlaying
        )
        .listRowBackground(
            Rectangle()
                .fill(DesignTokens.CommonBackgroundColors.cardHighlight)  // 不透明なカード色
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)  // 境界線
                )
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .onTapGesture {
            playFromPreset(preset)
        }
    }
    .onMove { from, to in
        playlistState.move(from: from, to: to)
    }
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.environment(\.editMode, .constant(.active))  // 常にドラッグハンドル表示
```

### ポイント

| 設定 | 目的 |
|------|------|
| `.listRowBackground(不透明な色)` | スナップショットに色を含め、黒を隠す |
| `.scrollContentBackground(.hidden)` | List 自体の背景は透明にして親ビューの背景を見せる |
| `.listRowSeparator(.hidden)` | 標準の区切り線を非表示 |
| `.listRowInsets(...zero...)` | セル間の隙間をなくす |
| `Rectangle().stroke(...)` | 隙間がないため、境界線でカードを区別 |
| `.environment(\.editMode, .constant(.active))` | 常にドラッグハンドル（三本線）を表示 |

---

## 反省点

### 見落としていたヒント

`architect/todo.md` に解決策のヒントがあった：

> 行の中に**自前背景ビューをガッツリ敷く**
> → スナップショットが「PlaylistRowView 全体」を撮るので、
> その背景が見えるようになって**多少マシになる可能性はある**。

「多少マシ」という表現で軽視し、試さなかった。実際には**完全に解決できる方法**だった。

### 教訓

1. **「消す」と「隠す」は別のアプローチ** - 消せないなら隠せばいい
2. **標準UIの挙動を再実装するのは困難** - カスタムジェスチャーは沼
3. **ヒントを軽視しない** - 「多少マシ」でも試す価値がある

---

## 結論

| アプローチ | 結果 |
|-----------|------|
| `listRowBackground(Color.clear)` | ❌ 黒が透ける |
| カスタムジェスチャー | ❌ 不安定、複数のバグ |
| `listRowBackground(不透明な色)` | ✅ 黒が隠れる |

**最もシンプルな解決策が最も効果的だった。**
