# SwiftUI List ドラッグ時の黒背景問題

## 日付
2025-12-09

## 概要
SwiftUI の `List` + `.onMove` でドラッグ並び替えを実装した際、行をドラッグ開始（リフト）する時にカードの外側に黒背景が表示される問題が発生した。

## 試した実装

```swift
List {
    ForEach(audioService.playlistState.orderedPresets, id: \.id) { preset in
        PlaylistRowView(...)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }
    .onMove { from, to in
        audioService.playlistState.move(from: from, to: to)
    }
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.environment(\.editMode, $isEditMode)
```

## 試した対策（すべて効果なし）

1. `.listRowBackground(Color.clear)` - 通常時は透明になるが、ドラッグ中は黒
2. `.scrollContentBackground(.hidden)` - スクロール背景は消えるが、ドラッグ中は黒
3. `.listStyle(.plain)` - スタイル変更しても黒背景は残る

## 原因
SwiftUI の `List` は、行をドラッグでリフトする際に内部的にデフォルトの背景色（黒）を適用する。これは SwiftUI の内部動作であり、外部から制御できない。

## 最終的な解決策
`List` を使わず、`VStack` + カスタムジェスチャー（`LongPressGesture` + `DragGesture`）で実装した。

```swift
VStack(spacing: 8) {
    ForEach(presets, id: \.id) { preset in
        PlaylistRowView(...)
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture())
                    .onChanged { ... }
                    .onEnded { ... }
            )
    }
}
```

## カスタムジェスチャー実装時の注意点

### 1. ScrollView との競合
- `ScrollView` 内で `DragGesture` を使うと、スクロールと競合する
- `.highPriorityGesture` を使ってドラッグを優先させる

### 2. onChanged での配列変更は危険
- ドラッグ中に毎フレーム `move()` を呼ぶと、配列がグルグル並び替わる
- インデックスがコロコロ変わり、オーバーシュート・震え・壊れる
- **対策**: ドラッグ中は見た目（offset）だけ動かし、`onEnded` で1回だけ `move()` する

### 3. ForEach の id が変わるとジェスチャーが壊れる
- `enumerated()` を使うと、配列順序が変わった時に id が変わる
- id が変わるとビューが再生成され、ジェスチャー状態がリセットされる
- **対策**: `ForEach(presets, id: \.id)` で preset 自体の id を使う

### 4. ジェスチャーリセット用の id は逆効果
- `gestureResetID` を変更してビューを再生成する方法は、ジェスチャーを壊す
- 連続して `first(true)` が呼ばれるだけで `second` に進まなくなる

## 結論
SwiftUI の `List` でドラッグ時の黒背景を消す方法は見つからなかった。カスタムジェスチャーで実装する場合は、上記の注意点に気をつける必要がある。
