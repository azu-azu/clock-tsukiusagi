import numpy as np
from scipy.io import wavfile
import soundfile as sf
import os
import random

SAMPLE_RATE = 48000
DURATION_SEC = 30
OUTPUT_DIR = "clock-tsukiusagi/Resources/Audio"
OUT_FILE = "forest_birds_soft.wav"

NUM_CALLS = 90  # 鳴き声の数（増やすとにぎやか）

def make_single_chirp(fs: int) -> np.ndarray:
    # 1つの鳥のさえずり（0.12〜0.4秒くらい）
    dur = random.uniform(0.12, 0.4)
    n_samples = int(dur * fs)
    t = np.linspace(0, dur, n_samples, endpoint=False)

    # 基本ピッチ（2〜5kHzあたりの高め）
    f_start = random.uniform(2000.0, 3500.0)
    f_end   = f_start * random.uniform(0.7, 1.3)  # 少し上下にスライド

    # 周波数スイープ（線形）
    freqs = np.linspace(f_start, f_end, n_samples)
    phase = 2 * np.pi * np.cumsum(freqs) / fs
    carrier = np.sin(phase)

    # エンベロープ（アタック＋減衰）
    attack_ratio = random.uniform(0.05, 0.15)
    attack_len = int(n_samples * attack_ratio)
    env = np.ones(n_samples)

    if attack_len > 0:
        env[:attack_len] = np.linspace(0.0, 1.0, attack_len)

    decay_speed = random.uniform(2.5, 4.5)
    decay = np.exp(-decay_speed * (t / dur))
    env *= decay

    # ちょっとだけランダムさを足す（自然な揺れ）
    vibrato_freq = random.uniform(4.0, 8.0)
    vibrato_depth = random.uniform(0.01, 0.03)
    vibrato = np.sin(2 * np.pi * vibrato_freq * t) * vibrato_depth

    chirp = carrier * env * (1.0 + vibrato)

    # 音量調整（あとでたくさん足すので抑えめ）
    chirp *= random.uniform(0.2, 0.5)

    # ステレオ化 + ランダムパン
    pan = random.uniform(-0.9, 0.9)  # 左右の位置
    left_gain  = np.cos((pan + 1) * np.pi / 4)
    right_gain = np.sin((pan + 1) * np.pi / 4)

    stereo = np.zeros((n_samples, 2), dtype=np.float32)
    stereo[:, 0] = chirp * left_gain
    stereo[:, 1] = chirp * right_gain

    return stereo

def generate_forest_birds():
    total_samples = int(DURATION_SEC * SAMPLE_RATE)
    audio = np.zeros((total_samples, 2), dtype=np.float32)

    for i in range(NUM_CALLS):
        chirp = make_single_chirp(SAMPLE_RATE)
        n_samples = chirp.shape[0]

        # 森の中でたまに鳴くイメージで、ランダム配置
        start = random.randint(0, max(0, total_samples - n_samples - 1))
        end = start + n_samples

        audio[start:end, :] += chirp

    # 全体を少しだけ正規化（マージン確保）
    max_val = np.max(np.abs(audio))
    if max_val > 0:
        audio /= (max_val * 1.1)

    return audio

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    audio = generate_forest_birds()

    # ファイル名から拡張子を除去
    basename = OUT_FILE.replace('.wav', '')
    wav_path = os.path.join(OUTPUT_DIR, f"{basename}.wav")
    caf_path = os.path.join(OUTPUT_DIR, f"{basename}.caf")

    # WAV: 16bit PCM
    audio_int16 = np.int16(audio * 32767)
    wavfile.write(wav_path, SAMPLE_RATE, audio_int16)

    # CAF: Float32
    sf.write(caf_path, audio, SAMPLE_RATE, format='CAF', subtype='FLOAT')

    print(f"✓ Exported: {basename}.wav / {basename}.caf")

if __name__ == "__main__":
    main()
