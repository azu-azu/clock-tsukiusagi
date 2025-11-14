#!/usr/bin/env python3
"""
Generate audio files for Clock Tsukiusagi app
Creates natural ambient sounds (Pink Noise, Ocean Waves, Rain, Forest Ambience)
in WAV format (simple and reliable)
"""

import numpy as np
import scipy.signal as signal
from scipy.io import wavfile
import os

# ------------------------------------------------------------
# Global Audio Parameters
# ------------------------------------------------------------
SAMPLE_RATE = 48000  # Hz (recommended for iOS playback)
DURATION = 60        # seconds (1 minute loops)
OUTPUT_DIR = "../clock-tsukiusagi/Resources/Audio"


# ------------------------------------------------------------
# Utility
# ------------------------------------------------------------
def apply_fade(audio, sample_rate, fade_ms=200):
    """Apply fade in/out for seamless looping"""
    fade_samples = int((fade_ms / 1000.0) * sample_rate)
    fade_in = np.linspace(0, 1, fade_samples)
    fade_out = np.linspace(1, 0, fade_samples)
    audio[:fade_samples] *= fade_in
    audio[-fade_samples:] *= fade_out
    return audio


def normalize(audio):
    """Normalize audio to -1.0 ... 1.0"""
    return audio / np.max(np.abs(audio))


def save_as_wav(audio_data, filename, sample_rate):
    """Save audio as WAV file"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    wav_path = os.path.join(OUTPUT_DIR, f"{filename}.wav")

    # WAV保存（16-bit PCM）
    audio_16bit = np.int16(audio_data * 32767)
    wavfile.write(wav_path, sample_rate, audio_16bit)
    print(f"✓ Generated WAV: {wav_path}")


# ------------------------------------------------------------
# Generators
# ------------------------------------------------------------
def generate_pink_noise(duration, sample_rate):
    """Generate pink noise (Voss-McCartney algorithm) (seamless loop)"""
    num_samples = int(duration * sample_rate)
    num_sources = 16

    # Use seed for reproducible noise that loops
    np.random.seed(999)
    sources = np.random.randn(num_sources, num_samples)
    pink = np.zeros(num_samples)
    for i in range(num_sources):
        factor = 2 ** i
        down = sources[i, ::factor]
        up = np.repeat(down, factor)[:num_samples]
        pink += up
    pink = normalize(pink)
    return pink  # No fade for seamless loop


def generate_ocean_waves(duration, sample_rate):
    """Generate ocean waves with slow rhythmic modulation (seamless loop)"""
    num_samples = int(duration * sample_rate)
    t = np.linspace(0, duration, num_samples, endpoint=False)  # endpoint=False for seamless loop

    # Generate random seed for reproducible noise that loops
    np.random.seed(42)
    noise = np.random.randn(num_samples)

    # Multi-layer slow sine envelope with frequencies that divide evenly into duration
    # This ensures the envelope starts and ends at the same phase
    # Using frequencies that are multiples of 1/duration for perfect looping
    f1 = 3 / duration  # 3 cycles in 60s = 0.05 Hz
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

    # Remove fade for seamless looping (the envelope already creates natural variation)
    return wave


def generate_rain_sound(duration, sample_rate):
    """Generate rain ambience using filtered noise layers (seamless loop)"""
    num_samples = int(duration * sample_rate)
    rain = np.zeros(num_samples)
    t = np.linspace(0, duration, num_samples, endpoint=False)

    # Use seed for reproducible noise
    np.random.seed(123)

    # Heavy drops
    drops = np.random.randn(num_samples) * 0.3
    sos = signal.butter(2, 800, "lowpass", fs=sample_rate, output="sos")
    rain += signal.sosfilt(sos, drops)

    # Mid rain
    light = np.random.randn(num_samples) * 0.4
    sos = signal.butter(2, [1000, 4000], "bandpass", fs=sample_rate, output="sos")
    rain += signal.sosfilt(sos, light)

    # High hiss
    hiss = np.random.randn(num_samples) * 0.2
    sos = signal.butter(2, 3000, "highpass", fs=sample_rate, output="sos")
    rain += signal.sosfilt(sos, hiss)

    # Subtle intensity modulation with frequency that loops perfectly
    f_mod = 1 / duration  # 1 cycle in 60s
    intensity = 0.8 + 0.2 * np.sin(2 * np.pi * f_mod * t)
    rain *= intensity

    rain = normalize(rain)
    return rain  # No fade for seamless loop


def generate_forest_ambience(duration, sample_rate):
    """Generate forest ambience (wind + leaves + birds) (seamless loop)"""
    num_samples = int(duration * sample_rate)
    t = np.linspace(0, duration, num_samples, endpoint=False)

    # Use seed for reproducible noise
    np.random.seed(456)

    # 🌬️ Wind (low-frequency noise)
    wind = np.random.randn(num_samples)
    sos = signal.butter(2, 1000, "lowpass", fs=sample_rate, output="sos")
    wind = signal.sosfilt(sos, wind)
    # Use frequency that loops perfectly (2 cycles in 60s)
    f_wind = 2 / duration
    wind *= 0.6 + 0.4 * np.sin(2 * np.pi * f_wind * t)

    # 🍃 Leaves rustling (high-frequency whisper)
    leaves = np.random.randn(num_samples)
    sos = signal.butter(2, 3000, "highpass", fs=sample_rate, output="sos")
    leaves = signal.sosfilt(sos, leaves)
    # Use frequency that loops perfectly (6 cycles in 60s)
    f_leaves = 6 / duration
    leaves *= 0.3 + 0.2 * np.sin(2 * np.pi * f_leaves * t)

    # 🐦 Birds chirping (sporadic high tones)
    birds = np.zeros(num_samples)
    np.random.seed(789)  # Separate seed for bird positions
    for _ in range(int(duration / 3)):  # roughly 1 chirp every 3 seconds
        start = np.random.randint(0, num_samples - int(sample_rate * 0.2))
        length = np.random.randint(int(sample_rate * 0.1), int(sample_rate * 0.25))
        freq = np.random.uniform(2000, 4000)
        chirp_t = np.linspace(0, length / sample_rate, length)
        chirp = 0.5 * np.sin(2 * np.pi * freq * chirp_t) * np.hanning(length)
        birds[start:start + length] += chirp

    # Mix all components
    forest = (0.5 * wind) + (0.3 * leaves) + (0.2 * birds)
    forest = normalize(forest)
    return forest  # No fade for seamless loop


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
def main():
    print("🎵 Generating ambient audio for Clock Tsukiusagi...")
    print(f"   Sample rate: {SAMPLE_RATE} Hz")
    print(f"   Duration: {DURATION} sec\n")
    print(f"   Output: {OUTPUT_DIR}\n")

    print("1/4 Generating Pink Noise...")
    pink = generate_pink_noise(DURATION, SAMPLE_RATE)
    save_as_wav(pink, "pink_noise_60s", SAMPLE_RATE)

    print("\n2/4 Generating Ocean Waves...")
    waves = generate_ocean_waves(DURATION, SAMPLE_RATE)
    save_as_wav(waves, "ocean_waves_60s", SAMPLE_RATE)

    print("\n3/4 Generating Rain Sound...")
    rain = generate_rain_sound(DURATION, SAMPLE_RATE)
    save_as_wav(rain, "rain_60s", SAMPLE_RATE)

    print("\n4/4 Generating Forest Ambience...")
    forest = generate_forest_ambience(DURATION, SAMPLE_RATE)
    save_as_wav(forest, "forest_ambience_60s", SAMPLE_RATE)

    print("\n✅ All ambient sounds generated successfully!")
    print("📝 Next steps:")
    print("   1. Add audio files to Xcode project")
    print("   2. Ensure 'Target Membership' is set to clock-tsukiusagi")
    print("   3. Verify files are in 'Copy Bundle Resources'\n")


if __name__ == "__main__":
    main()
