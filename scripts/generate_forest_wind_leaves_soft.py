import numpy as np
from scipy.io import wavfile
import soundfile as sf
import os
import random

SAMPLE_RATE = 48000
DURATION_SEC = 30
OUTPUT_DIR = "clock-tsukiusagi/Resources/Audio"
OUT_FILE = "forest_wind_leaves_soft.wav"

# ===== 共通ユーティリティ =====

def white_noise(n: int) -> np.ndarray:
    return np.random.normal(0.0, 1.0, n)

def make_pinkish(noise: np.ndarray) -> np.ndarray:
    """白色ノイズをちょっとピンク寄りにして、耳に優しくする"""
    n = len(noise)
    fft = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(n, 1 / SAMPLE_RATE)

    # f が高くなるほど少しずつ減衰させる（1 / sqrt(f) ぽい感じ）
    for i, f in enumerate(freqs):
        if f <= 0:
            continue
        fft[i] /= np.sqrt(f)

    pink = np.fft.irfft(fft, n=n)
    pink /= np.max(np.abs(pink) + 1e-9)
    return pink

def stereo_from_mono(mono: np.ndarray) -> np.ndarray:
    """モノラル → ステレオ（L=R）"""
    return np.stack([mono, mono], axis=1).astype(np.float32)

def pan_stereo(mono: np.ndarray, pan: float) -> np.ndarray:
    """
    pan: -1.0 = left, 0.0 = center, 1.0 = right
    """
    # -1〜1 → 0〜1 に正規化
    p = (pan + 1.0) / 2.0
    # シンプルな左右ゲイン
    left_gain = np.cos(p * np.pi / 2)
    right_gain = np.sin(p * np.pi / 2)

    stereo = np.zeros((len(mono), 2), dtype=np.float32)
    stereo[:, 0] = mono * left_gain
    stereo[:, 1] = mono * right_gain
    return stereo

# ===== そよ風レイヤー =====

def make_soft_wind_layer(total_samples: int) -> np.ndarray:
    # 白色ノイズ → ピンク寄りにして柔らかく
    base_noise = white_noise(total_samples)
    pink = make_pinkish(base_noise)

    # ゆるいローパス的な感じにする（超高域を抑える）
    fft = np.fft.rfft(pink)
    freqs = np.fft.rfftfreq(total_samples, 1 / SAMPLE_RATE)

    for i, f in enumerate(freqs):
        # 2kHz 以上はだんだん減衰
        if f > 2000:
            fft[i] *= max(0.0, 1.5 - (f / 4000.0))
        # 5kHzより上はほぼ消す
        if f > 5000:
            fft[i] *= 0.1

    wind = np.fft.irfft(fft, n=total_samples)

    # ゆっくりしたLFOで“そよそよ”強弱
    t = np.linspace(0, DURATION_SEC, total_samples, endpoint=False)
    lfo = 1.0 + 0.2 * np.sin(2 * np.pi * 0.05 * t)  # 0.05Hz = 20秒周期くらい
    wind *= lfo

    wind /= np.max(np.abs(wind) + 1e-9)
    wind *= 0.22  # 音量かなり控えめ

    return wind.astype(np.float32)

# ===== 葉っぱレイヤー（サラサラ系） =====

def make_soft_leaves_layer(total_samples: int) -> np.ndarray:
    leaves = np.zeros((total_samples, 2), dtype=np.float32)

    # “パチパチ”ではなく “ふわサラ” を意識して少なめ・長めに
    events = 40
    for _ in range(events):
        dur = random.uniform(0.5, 1.2)  # ロングめに
        n = int(dur * SAMPLE_RATE)
        if n <= 0 or n >= total_samples:
            continue

        start = random.randint(0, total_samples - n)
        end = start + n

        noise = white_noise(n)

        # 葉っぱ用：中〜高域（2kHz〜8kHz）中心、超高域は抑える
        fft = np.fft.rfft(noise)
        freqs = np.fft.rfftfreq(n, 1 / SAMPLE_RATE)

        for i, f in enumerate(freqs):
            if f < 2000:
                fft[i] *= 0.1
            elif f > 8000:
                fft[i] *= 0.3

        chunk = np.fft.irfft(fft, n=n)

        # スムーズなフェードイン・フェードアウト（ハン窓っぽく）
        w = np.hanning(n)
        chunk *= w

        # 全体音量はかなり小さめ
        chunk /= np.max(np.abs(chunk) + 1e-9)
        chunk *= random.uniform(0.08, 0.18)

        # ランダムパンで “森のあちこち” から鳴る感じに
        pan = random.uniform(-0.8, 0.8)
        stereo_chunk = pan_stereo(chunk.astype(np.float32), pan)

        leaves[start:end, :] += stereo_chunk

    # クリップ防止
    max_val = np.max(np.abs(leaves))
    if max_val > 0:
        leaves /= (max_val * 1.1)

    return leaves.astype(np.float32)

# ===== メイン =====

def main():
    total_samples = SAMPLE_RATE * DURATION_SEC

    # 風（モノ）→ステレオへ
    wind_mono = make_soft_wind_layer(total_samples)
    wind = stereo_from_mono(wind_mono)

    # 葉っぱ（ステレオ）
    leaves = make_soft_leaves_layer(total_samples)

    mix = wind + leaves

    max_val = np.max(np.abs(mix))
    if max_val > 0:
        mix /= (max_val * 1.05)

    # ファイル名から拡張子を除去
    basename = OUT_FILE.replace('.wav', '')
    wav_path = os.path.join(OUTPUT_DIR, f"{basename}.wav")
    caf_path = os.path.join(OUTPUT_DIR, f"{basename}.caf")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # WAV: 16bit PCM
    audio_int16 = np.int16(mix * 32767)
    wavfile.write(wav_path, SAMPLE_RATE, audio_int16)

    # CAF: Float32
    sf.write(caf_path, mix, SAMPLE_RATE, format='CAF', subtype='FLOAT')

    print(f"✓ Exported: {basename}.wav / {basename}.caf")

if __name__ == "__main__":
    main()
