# zip を使った安全な配列イテレーション

## 概要

関連する2つの配列を同時にループする際、インデックスベースのループは要素数の不一致でクラッシュする危険がある。`zip` を使うことで安全かつ可読性の高いコードになる。

---

## 問題：インデックスベースのループ

```swift
let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]  // 6要素
let harmonicAmps: [Float] = [1.0, 0.45, 0.25, 0.12, 0.03]  // 5要素（足りない！）

// ❌ 危険：harmonics.count でループすると harmonicAmps[5] でクラッシュ
for i in 0..<harmonics.count {
    let freq = baseFreq * harmonics[i]
    let amp = harmonicAmps[i]  // 💥 Index out of range
    signal += sin(freq * t) * amp
}
```

**問題点**：
- 片方の配列を変更すると、もう片方も変更が必要
- 変更を忘れるとクラッシュ
- インデックス `i` が複数の配列に依存している

---

## 解決策：zip を使う

```swift
// ✅ 安全：zip は短い方の配列に合わせてループを終了
for (harmonicRatio, harmonicAmp) in zip(harmonics, harmonicAmps) {
    let freq = baseFreq * harmonicRatio
    signal += sin(freq * t) * harmonicAmp
}
```

**利点**：
- 要素数が異なっても**クラッシュしない**（短い方で停止）
- インデックスを使わないので**可読性が高い**
- 変数名が意味を持つ（`i` より `harmonicRatio` の方が明確）

---

## zip の動作

```swift
let a = [1, 2, 3, 4]
let b = ["A", "B"]

for (num, letter) in zip(a, b) {
    print("\(num): \(letter)")
}
// 出力:
// 1: A
// 2: B
// （3, 4 は b に対応する要素がないのでスキップ）
```

---

## 適用場面

### 1. 倍音と振幅

```swift
let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
let harmonicAmps: [Float] = [1.0, 0.45, 0.25, 0.12, 0.07, 0.03]

for (ratio, amp) in zip(harmonics, harmonicAmps) {
    signal += sin(baseFreq * ratio * t) * amp
}
```

### 2. 音符と開始時間

```swift
let notes: [Note] = [...]
let startTimes: [Float] = [...]

for (note, startTime) in zip(notes, startTimes) {
    if currentTime >= startTime && currentTime < startTime + note.duration {
        // play note
    }
}
```

### 3. キーと値のペア（配列から辞書的に処理）

```swift
let keys = ["name", "age", "city"]
let values = ["Alice", "30", "Tokyo"]

for (key, value) in zip(keys, values) {
    print("\(key): \(value)")
}
```

---

## 注意点

### 要素数の不一致を検出したい場合

`zip` は黙って短い方に合わせるため、不一致を**エラーとして検出したい**場合は事前チェックが必要：

```swift
// 開発時に不一致を検出
assert(harmonics.count == harmonicAmps.count,
       "harmonics and harmonicAmps must have same count")

for (ratio, amp) in zip(harmonics, harmonicAmps) {
    // ...
}
```

### 3つ以上の配列

`zip` は2つの配列専用。3つ以上の場合は入れ子にする：

```swift
let a = [1, 2, 3]
let b = ["A", "B", "C"]
let c = [true, false, true]

for ((num, letter), flag) in zip(zip(a, b), c) {
    print("\(num), \(letter), \(flag)")
}
```

または、構造体にまとめることを検討：

```swift
struct Harmonic {
    let ratio: Float
    let amplitude: Float
}

let harmonics: [Harmonic] = [
    Harmonic(ratio: 1.0, amplitude: 1.0),
    Harmonic(ratio: 2.0, amplitude: 0.45),
    // ...
]

for h in harmonics {
    signal += sin(baseFreq * h.ratio * t) * h.amplitude
}
```

---

## 参考：JupiterMelodySignal での適用

- ファイル: `TsukiSound/Core/Audio/Synthesis/PureTone/JupiterMelodySignal.swift`
- 関数: `generateSingleVoice(freq:t:)`
- 変更: `for i in 0..<harmonics.count` → `for (harmonicRatio, harmonicAmp) in zip(harmonics, harmonicAmps)`
