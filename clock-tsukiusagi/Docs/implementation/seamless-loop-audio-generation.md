# シームレスループ音声ファイル生成ガイド

## 概要

環境音ファイル（波の音、雨、森など）をループ再生時に途切れないシームレスループに対応させた実装記録。

**実施日**: 2025-11-14
**対象**: Python生成スクリプト、CAF形式への移行
**関連Issue**: ループ再生時の音の途切れ（ブツっと切れる問題）

---

## 問題の背景

### 発生していた問題

**症状**:
- 波の音などをループ再生すると、1周目から2周目への切り替わり時に「ブツっ」と音が途切れる
- ループポイントで不自然な音の断絶が発生

**原因**:
1. **位相の不連続**
   - LFO変調に使用している周波数が60秒で割り切れない値（0.15 Hz, 0.08 Hz など）
   - ループ終端と開始点で正弦波の位相が合わない
   - 例: `sin(2π × 0.15 × t)` は60秒後に中途半端な位相になる

2. **フェードイン/アウトの干渉**
   - ループポイントでフェードアウト（音量減少）
   - 次の周でフェードイン（音量増加）
   - この間に無音区間が発生してブツっと切れる

3. **endpoint=True による重複**
   - `np.linspace(0, duration, num_samples)` の endpoint=True（デフォルト）
   - 最初と最後のサンプルが同じ時刻（0秒と60秒）を指す
   - ループ時に同じサンプルが2回再生される

---

## 解決策

### 1. ループする周波数の使用

**原則**: すべての変調周波数を `n / duration` の形式にする

```python
# ❌ 悪い例: 60秒で割り切れない周波数
f1 = 0.15  # 60秒後: 9サイクル完了、位相は中途半端
f2 = 0.08  # 60秒後: 4.8サイクル、位相が合わない
f3 = 0.25  # 60秒後: 15サイクル完了だが、明示的でない

# ✅ 良い例: 60秒で完全にループする周波数
duration = 60.0
f1 = 3 / duration  # 3 cycles in 60s = 0.05 Hz
f2 = 2 / duration  # 2 cycles in 60s = 0.033 Hz
f3 = 5 / duration  # 5 cycles in 60s = 0.083 Hz
```

**理由**:
- `n / duration` の周波数は、duration秒後に必ず位相が0に戻る
- ループポイントで開始点と終端点の位相が完全に一致
- 自然なループが実現

### 2. endpoint=False の使用

```python
# ❌ 悪い例: endpoint=True（デフォルト）
t = np.linspace(0, duration, num_samples)
# 最初のサンプル: t=0
# 最後のサンプル: t=60.0
# ループ時に t=60.0 と t=0 が連続 → 同じ位相が2回

# ✅ 良い例: endpoint=False
t = np.linspace(0, duration, num_samples, endpoint=False)
# 最初のサンプル: t=0
# 最後のサンプル: t=59.999...
# ループ時に t=59.999... の次が t=0 → 自然に連続
```

### 3. フェードの削除

```python
# ❌ 悪い例: ループポイントでフェード
def apply_fade(audio, sample_rate, fade_ms=200):
    fade_samples = int((fade_ms / 1000.0) * sample_rate)
    fade_in = np.linspace(0, 1, fade_samples)
    fade_out = np.linspace(1, 0, fade_samples)
    audio[:fade_samples] *= fade_in
    audio[-fade_samples:] *= fade_out
    return audio

wave = generate_ocean_waves(...)
return apply_fade(wave, sample_rate, 200)  # ブツっと切れる

# ✅ 良い例: フェードなし（シームレスループ）
wave = generate_ocean_waves(...)
return wave  # No fade for seamless loop
```

**注意**: フェードイン/アウトは再生開始/停止時のみに使用し、ループポイントには不要。

### 4. ランダムシードの固定

```python
# ❌ 悪い例: シードなし（毎回違うノイズ）
noise = np.random.randn(num_samples)
# ループごとに異なるノイズパターンが生成され、継ぎ目が目立つ

# ✅ 良い例: シード固定（再現可能）
np.random.seed(42)
noise = np.random.randn(num_samples)
# 常に同じノイズパターンが生成され、自然にループ
```

---

## 実装内容

### 修正したスクリプト

**ファイル**: `scripts/generate_test_tone.py`

#### Ocean Waves (波の音)

```python
def generate_ocean_waves(duration, sample_rate):
    """Generate ocean waves with slow rhythmic modulation (seamless loop)"""
    num_samples = int(duration * sample_rate)
    t = np.linspace(0, duration, num_samples, endpoint=False)  # ← endpoint=False

    # Generate random seed for reproducible noise that loops
    np.random.seed(42)  # ← シード固定
    noise = np.random.randn(num_samples)

    # Multi-layer slow sine envelope with frequencies that divide evenly into duration
    # This ensures the envelope starts and ends at the same phase
    # Using frequencies that are multiples of 1/duration for perfect looping
    f1 = 3 / duration  # 3 cycles in 60s = 0.05 Hz  ← ループする周波数
    f2 = 2 / duration  # 2 cycles in 60s = 0.033 Hz
    f3 = 5 / duration  # 5 cycles in 60s = 0.083 Hz

    env = (0.6
           + 0.3 * np.sin(2 * np.pi * f1 * t)
           + 0.2 * np.sin(2 * np.pi * f2 * t)
           + 0.1 * np.sin(2 * np.pi * f3 * t))
    env = np.clip(env, 0, 1)

    wave = noise * env
    sos = signal.butter(4, 2000, "lowpass", fs=sample_rate, output="sos")
    wave = signal.sosfilt(sos, wave)
    wave = normalize(wave)

    # Remove fade for seamless looping
    return wave  # ← フェードなし
```

**変更点**:
- 周波数: `0.15, 0.08, 0.25 Hz` → `3/60, 2/60, 5/60 Hz`
- `endpoint=False` を追加
- `apply_fade()` を削除
- `np.random.seed(42)` を追加

#### Rain (雨の音)

```python
def generate_rain_sound(duration, sample_rate):
    """Generate rain ambience using filtered noise layers (seamless loop)"""
    num_samples = int(duration * sample_rate)
    rain = np.zeros(num_samples)
    t = np.linspace(0, duration, num_samples, endpoint=False)

    # Use seed for reproducible noise
    np.random.seed(123)

    # ... ノイズレイヤー生成 ...

    # Subtle intensity modulation with frequency that loops perfectly
    f_mod = 1 / duration  # 1 cycle in 60s
    intensity = 0.8 + 0.2 * np.sin(2 * np.pi * f_mod * t)
    rain *= intensity

    rain = normalize(rain)
    return rain  # No fade for seamless loop
```

**変更点**:
- 周波数: `0.05 Hz` → `1/60 Hz`
- その他は Ocean Waves と同様

#### Forest Ambience (森の音)

```python
def generate_forest_ambience(duration, sample_rate):
    """Generate forest ambience (wind + leaves + birds) (seamless loop)"""
    num_samples = int(duration * sample_rate)
    t = np.linspace(0, duration, num_samples, endpoint=False)

    # Use seed for reproducible noise
    np.random.seed(456)

    # ... 各レイヤー生成 ...

    # Use frequency that loops perfectly
    f_wind = 2 / duration    # 2 cycles in 60s for wind
    f_leaves = 6 / duration  # 6 cycles in 60s for leaves

    wind *= 0.6 + 0.4 * np.sin(2 * np.pi * f_wind * t)
    leaves *= 0.3 + 0.2 * np.sin(2 * np.pi * f_leaves * t)

    # ... 合成 ...

    return forest  # No fade for seamless loop
```

**変更点**:
- 風の周波数: `0.1 Hz` → `2/60 Hz`
- 葉擦れの周波数: `0.3 Hz` → `6/60 Hz`

#### Pink Noise (ピンクノイズ)

```python
def generate_pink_noise(duration, sample_rate):
    """Generate pink noise (Voss-McCartney algorithm) (seamless loop)"""
    num_samples = int(duration * sample_rate)
    num_sources = 16

    # Use seed for reproducible noise that loops
    np.random.seed(999)
    sources = np.random.randn(num_sources, num_samples)

    # ... Voss-McCartney アルゴリズム ...

    pink = normalize(pink)
    return pink  # No fade for seamless loop
```

**変更点**:
- `np.random.seed(999)` を追加
- `apply_fade()` を削除

---

## CAF形式への移行

### AudioFilePresets の変更

**ファイル**: `clock-tsukiusagi/Core/Audio/Presets/AudioFilePresets.swift`

#### 1. ファイル拡張子の変更

```swift
// ❌ 以前: WAV形式
public var fileExtension: String {
    return "wav"
}

// ✅ 現在: CAF形式
public var fileExtension: String {
    return "caf"  // Core Audio Format for optimal iOS playback
}
```

#### 2. ループ設定の最適化

```swift
public var loopSettings: LoopSettings {
    switch self {
    case .pinkNoise:
        return LoopSettings(
            shouldLoop: true,
            crossfadeDuration: 0.0,  // ← 2.0から0.0に変更
            fadeInDuration: 0.5,     // 開始時のフェードは維持
            fadeOutDuration: 1.0     // 停止時のフェードは維持
        )
    case .oceanWaves:
        return LoopSettings(
            shouldLoop: true,
            crossfadeDuration: 0.0,  // ← 3.0から0.0に変更
            fadeInDuration: 1.0,
            fadeOutDuration: 2.0
        )
    // ... 他のケースも同様
    }
}
```

**理由**:
- シームレスループなので、ループポイントでのクロスフェードは不要
- 開始時/停止時のフェードは自然な出入りのために維持

### CAF変換コマンド

```bash
cd clock-tsukiusagi/Resources/Audio

# WAV → CAF 変換（Float32形式）
for f in *.wav; do
  base="${f%.wav}"
  echo "Converting $f to ${base}.caf..."
  afconvert -f caff -d LEF32@48000 -c 1 "$f" "${base}.caf"
done
```

**パラメータ説明**:
- `-f caff`: CAF (Core Audio Format)
- `-d LEF32@48000`: Little Endian Float32, 48kHz
- `-c 1`: モノラル（1チャンネル）

---

## ファイル一覧

### 生成されるファイル

```
clock-tsukiusagi/Resources/Audio/
├── pink_noise_60s.wav          (中間ファイル)
├── pink_noise_60s.caf          (最終ファイル) ✓
├── ocean_waves_60s.wav         (中間ファイル)
├── ocean_waves_60s.caf         (最終ファイル) ✓
├── rain_60s.wav                (中間ファイル)
├── rain_60s.caf                (最終ファイル) ✓
├── forest_ambience_60s.wav     (中間ファイル)
└── forest_ambience_60s.caf     (最終ファイル) ✓
```

**使用ファイル**: `.caf` ファイルのみ（`.wav` は中間生成物）

---

## 生成手順

### 1. Python スクリプト実行

```bash
# プロジェクトルートから実行
python3 scripts/generate_test_tone.py
```

**出力**:
```
🎵 Generating ambient audio for Clock Tsukiusagi...
   Sample rate: 48000 Hz
   Duration: 60 sec

   Output: ../clock-tsukiusagi/Resources/Audio

1/4 Generating Pink Noise...
✓ Generated WAV: ../clock-tsukiusagi/Resources/Audio/pink_noise_60s.wav

2/4 Generating Ocean Waves...
✓ Generated WAV: ../clock-tsukiusagi/Resources/Audio/ocean_waves_60s.wav

3/4 Generating Rain Sound...
✓ Generated WAV: ../clock-tsukiusagi/Resources/Audio/rain_60s.wav

4/4 Generating Forest Ambience...
✓ Generated WAV: ../clock-tsukiusagi/Resources/Audio/forest_ambience_60s.wav

✅ All ambient sounds generated successfully!
```

### 2. CAF 変換

```bash
cd clock-tsukiusagi/Resources/Audio

for f in *.wav; do
  base="${f%.wav}"
  afconvert -f caff -d LEF32@48000 -c 1 "$f" "${base}.caf"
done
```

### 3. Xcode プロジェクトに追加

1. Xcode で `clock-tsukiusagi/Resources/Audio/` を開く
2. `.caf` ファイルを選択
3. "Target Membership" が `clock-tsukiusagi` になっていることを確認
4. "Copy Bundle Resources" に含まれていることを確認

---

## 検証方法

### 1. ループポイントの確認

**手順**:
1. アプリで波の音を再生
2. 59秒〜61秒（ループポイント付近）を注意深く聴く
3. 音が途切れずに自然に続くか確認

**期待される結果**:
- ✅ ループポイントで音の途切れなし
- ✅ 音量の急激な変化なし
- ✅ 位相の不連続なし

### 2. 周波数の検証（Python）

```python
import numpy as np

duration = 60.0
frequencies = [3/duration, 2/duration, 5/duration]

for i, f in enumerate(frequencies):
    cycles = f * duration
    print(f"Frequency {i+1}: {f:.6f} Hz")
    print(f"  Cycles in {duration}s: {cycles}")
    print(f"  Phase at end: {(2 * np.pi * f * duration) % (2 * np.pi):.6f} rad")
    print()
```

**期待される出力**:
```
Frequency 1: 0.050000 Hz
  Cycles in 60.0s: 3.0
  Phase at end: 0.000000 rad  ← 位相が0に戻る

Frequency 2: 0.033333 Hz
  Cycles in 60.0s: 2.0
  Phase at end: 0.000000 rad  ← 位相が0に戻る

Frequency 3: 0.083333 Hz
  Cycles in 60.0s: 5.0
  Phase at end: 0.000000 rad  ← 位相が0に戻る
```

### 3. エンドポイントの検証

```python
# endpoint=False の確認
t1 = np.linspace(0, 60, 100, endpoint=False)
print(f"First sample: {t1[0]:.6f}")
print(f"Last sample: {t1[-1]:.6f}")
print(f"Next would be: {t1[-1] + (t1[1] - t1[0]):.6f}")

# 期待される出力:
# First sample: 0.000000
# Last sample: 59.400000
# Next would be: 60.000000 (= t1[0] after loop)
```

---

## CAF形式の利点

### 1. iOS/macOS ネイティブフォーマット

- Apple純正フォーマット
- ハードウェアアクセラレーション対応
- 効率的なデコード

### 2. Float32 サポート

```
WAV:   16-bit PCM (整数)
       ダイナミックレンジ: 96 dB

CAF:   32-bit Float (浮動小数点)
       ダイナミックレンジ: 144 dB
       量子化ノイズ: ほぼゼロ
```

### 3. メタデータサポート

- チャンネル情報
- サンプルレート
- ループポイント（必要に応じて）
- カスタムメタデータ

### 4. ストリーミング再生

- 大容量ファイルでもメモリ効率的
- シークが高速
- バッファリングが最適化

---

## トラブルシューティング

### ループポイントでブツっと切れる

**症状**: ループ再生時に音が途切れる

**確認項目**:
1. ✓ 周波数が `n / duration` の形式か？
2. ✓ `endpoint=False` を使用しているか？
3. ✓ ループポイントでフェードを適用していないか？
4. ✓ `crossfadeDuration` が 0.0 になっているか？

**修正例**:
```python
# ❌ 問題のあるコード
f = 0.15  # 60秒で割り切れない
t = np.linspace(0, duration, num_samples)  # endpoint=True
return apply_fade(wave, sample_rate, 200)  # フェード適用

# ✅ 修正後
f = 3 / duration  # 60秒で完全にループ
t = np.linspace(0, duration, num_samples, endpoint=False)
return wave  # フェードなし
```

### ループごとに音が変わる

**症状**: 1周目と2周目で音のパターンが異なる

**原因**: ランダムシードが固定されていない

**修正**:
```python
# ❌ シードなし
noise = np.random.randn(num_samples)

# ✅ シード固定
np.random.seed(42)
noise = np.random.randn(num_samples)
```

### CAF ファイルが再生されない

**症状**: アプリでCAFファイルが見つからない

**確認項目**:
1. ✓ ファイルが Bundle に含まれているか？
   - Xcode で "Copy Bundle Resources" を確認
2. ✓ ファイル名が正しいか？
   - `ocean_waves_60s.caf` (拡張子 .caf)
3. ✓ Target Membership が設定されているか？
   - `clock-tsukiusagi` ターゲットにチェック

**デバッグログ**:
```
⚠️ [AudioFilePreset] File not found: ocean_waves_60s.caf
```
→ Bundle に含まれていない

### 音質が劣化している

**症状**: CAF変換後に音質が悪くなった

**確認項目**:
1. ✓ Float32 形式を使用しているか？
   ```bash
   afconvert -f caff -d LEF32@48000 -c 1 input.wav output.caf
   ```
2. ✓ サンプルレートが一致しているか？
   - 生成: 48000 Hz
   - 変換: 48000 Hz

**NG例**:
```bash
# ❌ 16-bit整数に変換（劣化）
afconvert -f caff -d LEI16@48000 -c 1 input.wav output.caf

# ✅ Float32を使用（高品質）
afconvert -f caff -d LEF32@48000 -c 1 input.wav output.caf
```

---

## ベストプラクティス

### 1. 周波数の選択

```python
# ✅ 良い例: 整数サイクル
f1 = 1 / duration   # 1 cycle
f2 = 2 / duration   # 2 cycles
f3 = 3 / duration   # 3 cycles
f4 = 5 / duration   # 5 cycles

# ✅ 良い例: 分数サイクルでも割り切れる
f5 = 0.5 / duration  # 0.5 cycles (30秒周期)

# ❌ 悪い例: 割り切れない
f_bad = 0.15  # 9 cycles だが明示的でない
```

### 2. エンベロープ設計

```python
# ✅ 良い例: 複数の周期を組み合わせる
env = (0.5
       + 0.3 * np.sin(2 * np.pi * (3/duration) * t)  # 20秒周期
       + 0.2 * np.sin(2 * np.pi * (2/duration) * t)  # 30秒周期
       + 0.1 * np.sin(2 * np.pi * (5/duration) * t)) # 12秒周期

# 複雑な変調パターンでも完全にループ
```

### 3. ノイズの扱い

```python
# ✅ シード固定で再現性を確保
np.random.seed(42)
noise = np.random.randn(num_samples)

# ✅ ただし音源ごとに異なるシードを使用
# Pink Noise:  seed=999
# Ocean Waves: seed=42
# Rain:        seed=123
# Forest:      seed=456
```

### 4. ループ検証

```python
# ✅ ループポイントの連続性を検証
def verify_seamless_loop(audio, tolerance=1e-6):
    """最初と最後の値が連続しているか確認"""
    diff = abs(audio[0] - audio[-1])
    if diff < tolerance:
        print(f"✓ Seamless loop verified (diff: {diff:.2e})")
    else:
        print(f"⚠️ Loop discontinuity detected (diff: {diff:.2e})")

verify_seamless_loop(ocean_waves)
```

---

## まとめ

### 達成されたこと

1. ✅ シームレスループの実装
   - ループポイントでの音の途切れを解消
   - 位相連続性を保証

2. ✅ CAF形式への移行
   - iOS/macOSネイティブフォーマット
   - Float32による高音質

3. ✅ クロスフェード設定の最適化
   - ループポイントでのクロスフェードを削除
   - 開始/停止時のフェードは維持

4. ✅ 再現可能な音源生成
   - ランダムシード固定
   - 一貫した音質

### 技術的ポイント

- **周波数**: `n / duration` の形式で完全にループ
- **エンドポイント**: `endpoint=False` で重複を回避
- **フェード**: ループポイントでは不要
- **ランダム**: シード固定で再現性確保
- **形式**: CAF (Float32) で高音質

### 今後の拡張

- [ ] 他の環境音の追加（焚き火、川のせせらぎ など）
- [ ] 長時間ループ（120秒、180秒 など）の検討
- [ ] バイノーラル録音への対応
- [ ] ダイナミックな音量変化の実装
