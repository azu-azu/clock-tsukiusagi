#!/usr/bin/env python3
"""
Generate audio files for clock-tsukiusagi app
Creates pink noise and natural sound loops in CAF format (Apple's preferred format)
"""

import numpy as np
import scipy.signal as signal
from scipy.io import wavfile
import subprocess
import os

# Audio parameters
SAMPLE_RATE = 48000  # Hz
DURATION = 60  # seconds (1 minute loops)
OUTPUT_DIR = "../clock-tsukiusagi/Resources/Audio"

def generate_pink_noise(duration, sample_rate):
    """Generate pink noise using the Voss-McCartney algorithm"""
    num_samples = int(duration * sample_rate)

    # Number of random sources (more sources = smoother pink noise)
    num_sources = 16

    # Initialize random sources
    sources = np.random.randn(num_sources, num_samples)

    # Create pink noise by summing sources with exponentially decreasing sample rates
    pink = np.zeros(num_samples)
    for i in range(num_sources):
        # Downsample and upsample each source
        factor = 2 ** i
        downsampled = sources[i, ::factor]
        upsampled = np.repeat(downsampled, factor)[:num_samples]
        pink += upsampled

    # Normalize to -1 to 1 range
    pink = pink / np.max(np.abs(pink))

    # Apply gentle fade in/out for seamless looping
    fade_samples = int(0.1 * sample_rate)  # 100ms fade
    fade_in = np.linspace(0, 1, fade_samples)
    fade_out = np.linspace(1, 0, fade_samples)

    pink[:fade_samples] *= fade_in
    pink[-fade_samples:] *= fade_out

    return pink

def generate_wave_sound(duration, sample_rate):
    """Generate ocean wave sound using filtered noise"""
    num_samples = int(duration * sample_rate)

    # Start with white noise
    noise = np.random.randn(num_samples)

    # Apply bandpass filter to simulate wave frequencies (0.1 - 2 Hz modulation)
    # Use low-frequency oscillation to create wave-like rhythm
    t = np.linspace(0, duration, num_samples)

    # Multiple overlapping waves with different periods
    wave1 = 0.3 * np.sin(2 * np.pi * 0.15 * t)  # 6.7 second period
    wave2 = 0.2 * np.sin(2 * np.pi * 0.08 * t)  # 12.5 second period
    wave3 = 0.15 * np.sin(2 * np.pi * 0.25 * t)  # 4 second period

    envelope = 0.5 + wave1 + wave2 + wave3
    envelope = np.clip(envelope, 0, 1)

    # Apply envelope to noise
    wave = noise * envelope

    # Apply low-pass filter for muffled ocean sound
    sos = signal.butter(4, 2000, 'lowpass', fs=sample_rate, output='sos')
    wave = signal.sosfilt(sos, wave)

    # Normalize
    wave = wave / np.max(np.abs(wave))

    # Seamless loop fades
    fade_samples = int(0.2 * sample_rate)  # 200ms fade
    fade_in = np.linspace(0, 1, fade_samples)
    fade_out = np.linspace(1, 0, fade_samples)

    wave[:fade_samples] *= fade_in
    wave[-fade_samples:] *= fade_out

    return wave

def generate_rain_sound(duration, sample_rate):
    """Generate rain sound using multiple layers of filtered noise"""
    num_samples = int(duration * sample_rate)

    # Multiple layers of rain
    rain = np.zeros(num_samples)

    # Heavy drops (low frequency)
    drops = np.random.randn(num_samples) * 0.3
    sos = signal.butter(2, 800, 'lowpass', fs=sample_rate, output='sos')
    rain += signal.sosfilt(sos, drops)

    # Light rain (mid frequency)
    light = np.random.randn(num_samples) * 0.4
    sos = signal.butter(2, [1000, 4000], 'bandpass', fs=sample_rate, output='sos')
    rain += signal.sosfilt(sos, light)

    # Ambient hiss (high frequency)
    hiss = np.random.randn(num_samples) * 0.2
    sos = signal.butter(2, 3000, 'highpass', fs=sample_rate, output='sos')
    rain += signal.sosfilt(sos, hiss)

    # Add subtle intensity variation
    t = np.linspace(0, duration, num_samples)
    intensity = 0.8 + 0.2 * np.sin(2 * np.pi * 0.05 * t)  # 20 second cycle
    rain *= intensity

    # Normalize
    rain = rain / np.max(np.abs(rain))

    # Seamless loop fades
    fade_samples = int(0.2 * sample_rate)
    fade_in = np.linspace(0, 1, fade_samples)
    fade_out = np.linspace(1, 0, fade_samples)

    rain[:fade_samples] *= fade_in
    rain[-fade_samples:] *= fade_out

    return rain

def save_as_wav_and_convert_to_caf(audio_data, filename, sample_rate):
    """Save audio as WAV then convert to CAF format"""
    # Ensure output directory exists
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Convert to 16-bit PCM
    audio_16bit = np.int16(audio_data * 32767)

    # Save as WAV first
    wav_path = os.path.join(OUTPUT_DIR, f"{filename}.wav")
    wavfile.write(wav_path, sample_rate, audio_16bit)
    print(f"✓ Generated: {wav_path}")

    # Convert to CAF using afconvert (macOS tool)
    caf_path = os.path.join(OUTPUT_DIR, f"{filename}.caf")
    try:
        subprocess.run([
            'afconvert',
            '-f', 'caff',  # CAF format
            '-d', 'LEI16',  # 16-bit little-endian integer
            wav_path,
            caf_path
        ], check=True, capture_output=True)
        print(f"✓ Converted to CAF: {caf_path}")

        # Keep both WAV and CAF
        # WAV is more portable, CAF is Apple's preferred format
    except subprocess.CalledProcessError as e:
        print(f"⚠️  CAF conversion failed: {e}")
        print(f"   Using WAV file instead")
    except FileNotFoundError:
        print(f"⚠️  afconvert not found (not on macOS?)")
        print(f"   Using WAV file instead")

def main():
    print("🎵 Generating audio files for clock-tsukiusagi...")
    print(f"   Sample rate: {SAMPLE_RATE} Hz")
    print(f"   Duration: {DURATION} seconds")
    print(f"   Output: {OUTPUT_DIR}/")
    print()

    # Generate pink noise (for click suppression base)
    print("1/3 Generating pink noise...")
    pink = generate_pink_noise(DURATION, SAMPLE_RATE)
    save_as_wav_and_convert_to_caf(pink, "pink_noise_60s", SAMPLE_RATE)
    print()

    # Generate ocean wave sound
    print("2/3 Generating ocean waves...")
    waves = generate_wave_sound(DURATION, SAMPLE_RATE)
    save_as_wav_and_convert_to_caf(waves, "ocean_waves_60s", SAMPLE_RATE)
    print()

    # Generate rain sound
    print("3/3 Generating rain sound...")
    rain = generate_rain_sound(DURATION, SAMPLE_RATE)
    save_as_wav_and_convert_to_caf(rain, "rain_60s", SAMPLE_RATE)
    print()

    print("✅ All audio files generated successfully!")
    print(f"   Location: {OUTPUT_DIR}/")
    print()
    print("📝 Next steps:")
    print("   1. Add audio files to Xcode project")
    print("   2. Set Target Membership to 'clock-tsukiusagi'")
    print("   3. Verify files appear in Copy Bundle Resources build phase")

if __name__ == "__main__":
    main()
