#!/usr/bin/env python3
"""
Generate simple test tone without numpy/scipy dependencies
Creates a 440Hz test tone for TrackPlayer testing
"""

import math
import wave
import struct
import os
import subprocess

OUTPUT_DIR = "../clock-tsukiusagi/Resources/Audio"
SAMPLE_RATE = 48000
DURATION = 5  # 5 seconds test tone

def generate_sine_wave(freq, duration, sr, amplitude=0.2):
    # ループ周期=1200サンプル（48k/440=1200/11 → 基本周期は1200）
    base_period = 1200
    total_samples = int(round(duration * sr))
    # 念のため1200の倍数に丸める
    total_samples = (total_samples // base_period) * base_period
    samples = []

    fade_ms = 80  # 80ms 等電力フェード
    fade_samples = int(sr * (fade_ms / 1000.0))
    fade_samples = max(1, min(fade_samples, total_samples // 4))

    def cosine_fade(g):
        return 0.5 * (1 - math.cos(math.pi * g))  # 等電力フェード

    for i in range(total_samples):
        t = i / sr
        v = amplitude * math.sin(2.0 * math.pi * freq * t)

        if i < fade_samples:
            v *= cosine_fade(i / fade_samples)
        elif i > total_samples - fade_samples - 1:
            pos = total_samples - 1 - i
            v *= cosine_fade(pos / fade_samples)

        samples.append(v)
    return samples


def save_wav(samples, filename, sample_rate):
    """Save samples as WAV file"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filepath = os.path.join(OUTPUT_DIR, filename)

    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)

        # Convert float samples to 16-bit integers
        int_samples = [int(s * 32767) for s in samples]

        # Pack samples as little-endian 16-bit integers
        packed_samples = struct.pack('<' + 'h' * len(int_samples), *int_samples)
        wav_file.writeframes(packed_samples)

    print(f"✓ Generated: {filepath}")
    return filepath

def convert_to_caf(wav_path):
    """Convert WAV to CAF using afconvert"""
    caf_path = wav_path.replace('.wav', '.caf')

    try:
        subprocess.run([
            'afconvert',
            '-f', 'caff',  # CAF format
            '-d', 'LEI16',  # 16-bit little-endian integer
            wav_path,
            caf_path
        ], check=True, capture_output=True)
        print(f"✓ Converted to CAF: {caf_path}")
        return caf_path
    except subprocess.CalledProcessError as e:
        print(f"⚠️  CAF conversion failed: {e}")
        return None
    except FileNotFoundError:
        print(f"⚠️  afconvert not found (not on macOS?)")
        return None

def main():
    print("🎵 Generating test audio file...")
    print(f"   Frequency: 440 Hz (A4)")
    print(f"   Duration: {DURATION} seconds")
    print(f"   Sample rate: {SAMPLE_RATE} Hz")
    print(f"   Output: {OUTPUT_DIR}/")
    print()

    # Generate 440Hz sine wave
    samples = generate_sine_wave(440, DURATION, SAMPLE_RATE)

    # Save as WAV
    wav_path = save_wav(samples, "test_tone_440hz.wav", SAMPLE_RATE)

    # Convert to CAF
    caf_path = convert_to_caf(wav_path)

    print()
    print("✅ Test audio file generated!")
    print()
    print("📝 Next steps:")
    print("   1. Add audio files to Xcode project:")
    print("      - Drag files into Project Navigator")
    print("      - Check 'Copy items if needed'")
    print("      - Set Target Membership to 'clock-tsukiusagi'")
    print()
    print("   2. Test with TrackPlayer:")
    print("      let url = Bundle.main.url(forResource: \"test_tone_440hz\", withExtension: \"caf\")!")
    print("      try trackPlayer.load(url: url)")
    print("      trackPlayer.play(loop: true, crossfadeDuration: 0.5)")

if __name__ == "__main__":
    main()
