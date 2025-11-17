import numpy as np
from scipy.io import wavfile
import soundfile as sf
import os
import random

# ===== 基本設定 =====
SAMPLE_RATE = 48000        # TsukiUsagiに合わせて 48kHz
DURATION_SEC = 30          # 30秒ループ
NUM_BUBBLES = 6          # 泡の数（広い間隔を確保するため減らす）
OUTPUT_DIR = "clock-tsukiusagi/Resources/Audio"
OUT_FILE = "bubbles_soft.wav"


# ===== 泡1つ分の波形を作る（トーンベースのポコ音） =====
def make_single_bubble(fs: int) -> np.ndarray:
    # --- 基本の1ポコ（内部関数：バリエーション生成用） ---
    def base_poko():
        dur = random.uniform(0.04, 0.09)   # 1発は短め
        n = int(dur * fs)
        t = np.linspace(0.0, dur, n, endpoint=False)

        # ピッチ（泡らしい低め＋上昇）
        f_start = random.uniform(120.0, 220.0)
        f_end   = f_start * random.uniform(1.3, 1.8)

        freqs = np.linspace(f_start, f_end, n)
        phase = 2*np.pi * np.cumsum(freqs) / fs
        tone = np.sin(phase)

        # 微量ノイズ
        noise = np.random.normal(0, 1, n) * 0.12
        x = tone * 0.85 + noise

        # エンベロープ（柔らかいアタック＋減衰）
        attack_len = max(1, int(n * 0.07))
        env = np.ones(n, dtype=np.float32)
        env[:attack_len] = np.linspace(0, 1, attack_len)
        env *= np.exp(-2.8 * (t / dur))
        x = x * env

        return x.astype(np.float32)

    # --- ここから3連ポコ生成 ---
    poko1 = base_poko()
    poko2 = base_poko() * random.uniform(0.9, 1.0)
    poko3 = base_poko() * random.uniform(0.45, 0.7)

    # 数ミリ秒ずつずらして「ポコ...ポコ...ポコッ」（ゆっくり＆毎回異なる間隔）
    offsets_ms = [
        0,
        random.uniform(0.120, 0.250),   # 120〜250ms（1つ目と2つ目の間隔）
        random.uniform(0.300, 0.500),   # 300〜500ms（2つ目と3つ目の間隔）
    ]

    pokos = [poko1, poko2, poko3]
    offsets_samples = [int(o * fs) for o in offsets_ms]

    max_len = max(o + len(p) for o, p in zip(offsets_samples, pokos))
    mono = np.zeros(max_len, dtype=np.float32)

    # 合体
    for poko, offset in zip(pokos, offsets_samples):
        o = offset
        mono[o:o+len(poko)] += poko

    # 正規化（控えめ）
    mono /= (np.max(np.abs(mono)) + 1e-9)
    mono *= random.uniform(0.18, 0.32)

    # --- ステレオ化（ランダムパン） ---
    pan = random.uniform(-0.7, 0.7)
    p = (pan + 1)/2
    L = np.cos(p * np.pi/2)
    R = np.sin(p * np.pi/2)

    stereo = np.zeros((max_len, 2), dtype=np.float32)
    stereo[:,0] = mono * L
    stereo[:,1] = mono * R

    return stereo

# ===== 全体ループ生成 =====
def generate_bubble_ambience():
    total_samples = int(DURATION_SEC * SAMPLE_RATE)
    audio = np.zeros((total_samples, 2), dtype=np.float32)

    MIN_GAP_SEC = 2.5   # ← ← ★ここが「イベント同士の間隔」（広めに設定）
    MIN_GAP = int(MIN_GAP_SEC * SAMPLE_RATE)

    event_starts = []

    for i in range(NUM_BUBBLES):
        # --- 開始地点を見つける ---
        while True:
            start = random.randint(0, total_samples - 1)

            # 他イベントとの距離チェック（最小間隔）
            if all(abs(start - s) > MIN_GAP for s in event_starts):
                event_starts.append(start)
                break

        # --- 3連ポコを置く ---
        bubble = make_single_bubble(SAMPLE_RATE)
        end = start + bubble.shape[0]

        if end < total_samples:
            audio[start:end, :] += bubble

    # 全体正規化
    max_val = np.max(np.abs(audio))
    if max_val > 0:
        audio /= (max_val * 1.2)

    return audio

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    audio = generate_bubble_ambience()

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
