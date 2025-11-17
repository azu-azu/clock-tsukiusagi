import numpy as np
from scipy.io import wavfile
import soundfile as sf
import os
import random
import math

SAMPLE_RATE = 48000
DURATION_SEC = 30
OUTPUT_DIR = "clock-tsukiusagi/Resources/Audio"
OUT_FILE = "forest_wind_leaves.wav"

# ===== 基本の白色ノイズ生成 =====
def white_noise(n):
    return np.random.normal(0, 1, n)

# ===== LFO（風の強弱） =====
def lfo(n, freq, depth):
    t = np.linspace(0, 1, n)
    return 1.0 + depth * np.sin(2 * np.pi * freq * t)

# ===== 風のレイヤー =====
def make_wind_layer(total_samples):
    noise = white_noise(total_samples)

    # 風は低〜中域（200〜1500Hz）
    # → 簡易バンドパスとしてFFTで削る
    fft = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(total_samples, 1/SAMPLE_RATE)

    for i, f in enumerate(freqs):
        if f < 200 or f > 1500:
            fft[i] *= 0.1  # ほぼ消す

    wind = np.fft.irfft(fft)

    # LFOで風の強弱（ゆったり）
    wind *= lfo(total_samples, freq=0.1, depth=0.4)

    wind /= np.max(np.abs(wind) + 1e-9)
    wind *= 0.3  # 音量控えめに

    return wind

# ===== 葉っぱのレイヤー =====
def make_leaves_layer(total_samples):
    leaves = np.zeros(total_samples)

    # ランダムな“サラ…”イベントを重ねる
    events = 120
    for _ in range(events):
        dur = random.uniform(0.15, 0.35)
        n = int(dur * SAMPLE_RATE)
        start = random.randint(0, total_samples - n)

        noise = white_noise(n)

        # 葉っぱは高周波（3000〜9000Hz）
        fft = np.fft.rfft(noise)
        freqs = np.fft.rfftfreq(n, 1/SAMPLE_RATE)

        for i, f in enumerate(freqs):
            if f < 3000 or f > 9000:
                fft[i] *= 0.0

        chunk = np.fft.irfft(fft, n)

        # エンベロープで「サラ…サラ…」
        t = np.linspace(0, 1, n)
        env = np.exp(-6 * t)
        chunk *= env

        # パン
        pan = random.uniform(-0.5, 0.5)
        p = 0.5 + pan
        chunk *= p

        leaves[start:start+n] += chunk

    leaves /= (np.max(np.abs(leaves)) + 1e-9)
    leaves *= 0.2

    return leaves

def main():
    total_samples = SAMPLE_RATE * DURATION_SEC

    wind = make_wind_layer(total_samples)
    leaves = make_leaves_layer(total_samples)

    # 合成
    mix = wind + leaves
    mix /= (np.max(np.abs(mix)) + 1e-9)

    # ファイル名から拡張子を除去
    basename = OUT_FILE.replace('.wav', '')
    wav_path = os.path.join(OUTPUT_DIR, f"{basename}.wav")
    caf_path = os.path.join(OUTPUT_DIR, f"{basename}.caf")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # WAV: 16bit PCM (ステレオ化: モノラル → ステレオ)
    mix_stereo = np.stack([mix, mix], axis=1)
    audio_int16 = np.int16(mix_stereo * 32767)
    wavfile.write(wav_path, SAMPLE_RATE, audio_int16)

    # CAF: Float32 (ステレオ化)
    mix_stereo_float = np.stack([mix, mix], axis=1).astype(np.float32)
    sf.write(caf_path, mix_stereo_float, SAMPLE_RATE, format='CAF', subtype='FLOAT')

    print(f"✓ Exported: {basename}.wav / {basename}.caf")

if __name__ == "__main__":
    main()
