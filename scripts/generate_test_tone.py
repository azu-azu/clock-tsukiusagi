#!/usr/bin/env python3
"""
Generate audio assets for Clock Tsukiusagi app
Includes natural ambiences (Pink Noise, Ocean Waves, Rain, Forest)
and short effect sounds (Seagull chirp)
Exports both WAV and CAF for iOS-native playback
"""

import numpy as np
import scipy.signal as signal
from scipy.io import wavfile
import soundfile as sf
import os

# ------------------------------------------------------------
# Global Parameters
# ------------------------------------------------------------
SAMPLE_RATE = 48000  # Hz (recommended for iOS playback)
DURATION = 60        # seconds (loop length)
OUTPUT_DIR = "clock-tsukiusagi/Resources/Audio"

# ------------------------------------------------------------
# Utility
# ------------------------------------------------------------
def normalize(audio):
    return audio / np.max(np.abs(audio) + 1e-9)

def save_audio(audio_data, filename, sample_rate):
    """Save both WAV and CAF (16-bit PCM)"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    audio_16 = np.int16(audio_data * 32767)

    wav_path = os.path.join(OUTPUT_DIR, f"{filename}.wav")
    caf_path = os.path.join(OUTPUT_DIR, f"{filename}.caf")

    wavfile.write(wav_path, sample_rate, audio_16)
    sf.write(caf_path, audio_data, sample_rate, format='CAF', subtype='PCM_16')

    print(f"✓ Exported: {filename}.wav / {filename}.caf")

# ------------------------------------------------------------
# Generators
# ------------------------------------------------------------
def generate_pink_noise(duration, sample_rate):
    """Generate looping pink noise (Voss-McCartney)"""
    num_samples = int(duration * sample_rate)
    num_sources = 16
    np.random.seed(999)
    sources = np.random.randn(num_sources, num_samples)
    pink = np.zeros(num_samples)
    for i in range(num_sources):
        factor = 2 ** i
        down = sources[i, ::factor]
        up = np.repeat(down, factor)[:num_samples]
        pink += up
    return normalize(pink)

def generate_ocean_waves(duration, sample_rate):
    """Ocean waves: filtered noise + slow modulation"""
    num_samples = int(duration * sample_rate)
    t = np.linspace(0, duration, num_samples, endpoint=False)
    np.random.seed(42)
    noise = np.random.randn(num_samples)
    f1, f2, f3 = 3/duration, 2/duration, 5/duration
    env = (0.6
           + 0.3*np.sin(2*np.pi*f1*t)
           + 0.2*np.sin(2*np.pi*f2*t)
           + 0.1*np.sin(2*np.pi*f3*t))
    env = np.clip(env, 0, 1)
    wave = signal.sosfilt(signal.butter(4, 2000, "lowpass", fs=sample_rate, output="sos"), noise * env)
    return normalize(wave)

def generate_rain_sound(duration, sample_rate):
    """Layered rain ambience"""
    num_samples = int(duration * sample_rate)
    t = np.linspace(0, duration, num_samples, endpoint=False)
    np.random.seed(123)

    drops = signal.sosfilt(signal.butter(2, 800, "lowpass", fs=sample_rate, output="sos"), np.random.randn(num_samples)*0.3)
    mid = signal.sosfilt(signal.butter(2, [1000,4000], "bandpass", fs=sample_rate, output="sos"), np.random.randn(num_samples)*0.4)
    hiss = signal.sosfilt(signal.butter(2, 3000, "highpass", fs=sample_rate, output="sos"), np.random.randn(num_samples)*0.2)
    mod = 0.8 + 0.2*np.sin(2*np.pi*(1/duration)*t)
    rain = (drops+mid+hiss)*mod
    return normalize(rain)

def generate_forest_ambience(duration, sample_rate):
    """Forest ambience: wind, leaves, birds"""
    num_samples = int(duration * sample_rate)
    t = np.linspace(0, duration, num_samples, endpoint=False)
    np.random.seed(456)

    wind = signal.sosfilt(signal.butter(2, 1000, "lowpass", fs=sample_rate, output="sos"), np.random.randn(num_samples))
    wind *= 0.6 + 0.4*np.sin(2*np.pi*(2/duration)*t)

    leaves = signal.sosfilt(signal.butter(2, 3000, "highpass", fs=sample_rate, output="sos"), np.random.randn(num_samples))
    leaves *= 0.3 + 0.2*np.sin(2*np.pi*(6/duration)*t)

    birds = np.zeros(num_samples)
    np.random.seed(789)
    for _ in range(int(duration/3)):
        start = np.random.randint(0, num_samples - int(sample_rate*0.2))
        length = np.random.randint(int(sample_rate*0.1), int(sample_rate*0.25))
        freq = np.random.uniform(2000, 4000)
        chirp_t = np.linspace(0, length/sample_rate, length)
        chirp = 0.5*np.sin(2*np.pi*freq*chirp_t)*np.hanning(length)
        birds[start:start+length] += chirp

    forest = (0.5*wind + 0.3*leaves + 0.2*birds)
    return normalize(forest)

def generate_seagull_chirp(sample_rate):
    """Single seagull chirp ~0.8s"""
    duration = 0.8
    t = np.linspace(0, duration, int(sample_rate*duration), endpoint=False)
    base_freq, swing = 1500, 1200
    pitch = base_freq + swing*np.sin(np.pi*t/duration)
    phase = 2*np.pi*np.cumsum(pitch)/sample_rate
    tone = np.sin(phase)
    noise = np.random.randn(len(t))*0.15
    harm = 0.5*np.sin(phase*2)+0.25*np.sin(phase*3)
    sig = (tone*0.6 + harm*0.4 + noise)*0.8
    env = np.sin(np.linspace(0, np.pi, len(t)))**1.5
    sig *= env
    return normalize(sig)

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
def main():
    print("🎵 Generating ambient audio for Clock Tsukiusagi...\n")

    ambients = {
        "pink_noise_60s": generate_pink_noise,
        "ocean_waves_60s": generate_ocean_waves,
        "rain_60s": generate_rain_sound,
        "forest_ambience_60s": generate_forest_ambience,
    }

    for i, (name, func) in enumerate(ambients.items(), start=1):
        print(f"{i}/{len(ambients)} Generating {name}...")
        audio = func(DURATION, SAMPLE_RATE)
        save_audio(audio, name, SAMPLE_RATE)

    print("\n🐦 Generating seagull chirp...")
    seagull = generate_seagull_chirp(SAMPLE_RATE)
    save_audio(seagull, "seagull", SAMPLE_RATE)

    print("\n✅ All sounds generated successfully!\n")

if __name__ == "__main__":
    main()
