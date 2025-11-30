# Jupiter-Harp 周波数干渉問題の修正レポート

**Date**: 2025-11-30
**Issue**: JupiterメロディとMidnightDroplets（ハープ）の周波数干渉による音質劣化
**Status**: Resolved

---

## 問題の症状

CathedralStillnessプリセット再生時、特定の箇所で「グチャっと潰れる」「ボンとアクセントが入る」ような汚い音が発生。

**問題が発生した箇所:**
- Bar 3 beat 0.0 (C5)
- Bar 5 beat 0.0 (E4)

---

## 原因特定のプロセス

### 最初の誤った仮説

1. **Jupiterメロディ内のノート重複** → 誤り
   - ノート間のリリース重複を疑い、メロディデータの長さを調整
   - 効果なし

2. **CathedralStillness（オルガンドローン）との倍音干渉** → 部分的に正しいが主因ではない
   - C3の4倍音(523Hz)がC5と一致するため倍音を削減
   - 効果なし

### 正しい原因の特定方法

**レイヤーの切り分けテスト:**

```swift
// PureToneBuilder.swift で各レイヤーを個別にコメントアウト
mixer.add(organSignal, gain: 1.0)     // ← これを無効化 → 問題継続
mixer.add(harpSignal, gain: 0.6)      // ← これを無効化 → 問題解消！
mixer.add(jupiterSignal, gain: 0.7)
```

**結論: MidnightDroplets（ハープ）が原因だった**

---

## 根本原因

### 周波数の衝突

**MidnightDropletsのスケール（変更前）:**
```
C4 (261.63Hz), D4 (293.66Hz), E4 (329.63Hz), G4 (392.00Hz), A4 (440.00Hz)
```

**Jupiterメロディで使用される音:**
```
E4, G4, A4, B4, C5, D5, E5, G5, A5, B5, C6, D6, E6
```

**衝突:**
- MidnightDroplets E4 (329.63Hz) = Jupiter E4 と完全一致
- MidnightDroplets G4 (392.00Hz) = Jupiter G4 と完全一致
- MidnightDroplets A4 (440.00Hz) = Jupiter A4 と完全一致
- MidnightDroplets C4の2倍音 (523.26Hz) ≈ Jupiter C5 (523.25Hz)

### なぜランダムなタイミングで問題が起きたか

MidnightDropletsは「6〜15秒のランダム間隔」でアルペジオを発音する。
このランダムタイミングがたまたまJupiterメロディのBar 3やBar 5の頭と重なると、
**同じ周波数の音が同時に鳴り、位相干渉や音量スパイクが発生**した。

---

## 解決策

### 採用した方法: スケールを1オクターブ上へ移動

```swift
// Before: C4-A4（Jupiterと衝突）
let scale: [Float] = [261.63, 293.66, 329.63, 392.00, 440.00]

// After: C5-A5（Jupiterの上で透明感を保つ）
let scale: [Float] = [523.25, 587.33, 659.25, 783.99, 880.00]
```

### なぜ「上」が正解か

**下げる案（C3-A3）を試した結果:**
- ハープの良さ（高域の透明感）が消える
- CathedralStillness（C3/G3）と低域でぶつかる
- 「濁りの塊」になる

**上げる案（C5-A5）の利点:**
- Jupiterメロディ（E4〜E6）の上で分離
- ハープの「夜空の水滴」感が維持される
- 透明感が最大化

### 音量調整

スケールを上げたことで高域が目立ちすぎたため、音量を大幅に下げた:

```swift
// Before
return value * 0.22

// After
let masterGain: Float = 0.02
return value * masterGain
```

---

## 試して効果がなかったアプローチ

| アプローチ | 結果 | 理由 |
|-----------|------|------|
| Jupiterノートの長さを短縮 | 効果なし | 問題はJupiter内部ではなくHarpとの干渉 |
| CathedralStillnessの倍音削減 | 効果なし | 主因はHarpだった |
| Jupiterリリース中の倍音減衰 | 効果なし | 干渉の瞬間は減衰前 |
| Harpスケールを下げる(C3-A3) | 音質劣化 | 低域の濁り、ハープらしさ消失 |

---

## 学び

### 1. 問題の切り分けが最優先

複数レイヤーがミックスされている場合、**1つずつ無効化して原因を特定する**のが最速。
仮説に基づく修正を繰り返すより、切り分けテストを先にやるべき。

### 2. 「周波数帯の棲み分け」が重要

複数の音源をミックスする際、**周波数帯が重ならないよう設計**する:

```
CathedralStillness: C3-G3 (130-196Hz) - 低域ドローン
Jupiter Melody:     E4-E6 (330-1319Hz) - 中域メロディ
MidnightDroplets:   C5-A5 (523-880Hz) - 高域アクセント
```

### 3. ランダム要素と固定要素の干渉リスク

ランダムタイミングで発音する音源と、固定タイミングのメロディを組み合わせると、
**予測不能な衝突が起きる**。周波数帯を分離することで回避できる。

### 4. 「下げる」より「上げる」がハープの正解

ハープの魅力は高域の透明感。低域に逃がすと音色の本質が失われる。
**楽器の特性に合った周波数帯を選ぶ**ことが重要。

---

## 関連ファイル

- `TsukiSound/Core/Audio/Synthesis/PureTone/MidnightDropletsSignal.swift`
- `TsukiSound/Core/Audio/Synthesis/PureTone/CathedralStillnessSignal.swift`
- `TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter/JupiterSignal.swift`
- `TsukiSound/Core/Audio/Synthesis/PureTone/PureToneBuilder.swift`

---

## 関連コミット

- `c298116` - fix(audio): resolve Jupiter melody interference with MidnightDroplets
