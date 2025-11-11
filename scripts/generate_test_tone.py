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
SAMPLE_RATE = 44100
DURATION = 5  # 5 seconds test tone

def generate_sine_wave(frequency, duration, sample_rate, amplitude=0.3):
    """Generate sine wave samples"""
    num_samples = int(duration * sample_rate)
    samples = []

    for i in range(num_samples):
        # Calculate sine wave value
        t = i / sample_rate
        value = amplitude * math.sin(2 * math.pi * frequency * t)

        # Apply fade in/out for seamless loop
        fade_samples = int(0.1 * sample_rate)  # 100ms fade

        if i < fade_samples:
            # Fade in
            fade_factor = i / fade_samples
            value *= fade_factor
        elif i > num_samples - fade_samples:
            # Fade out
            fade_factor = (num_samples - i) / fade_samples
            value *= fade_factor

        # Convert to 16-bit PCM
        sample = int(value * 32767)
        sample = max(-32768, min(32767, sample))  # Clamp
        samples.append(sample)

    return samples

def save_wav(samples, filename, sample_rate):
    """Save samples as WAV file"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filepath = os.path.join(OUTPUT_DIR, filename)

    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)

        # Pack samples as little-endian 16-bit integers
        packed_samples = struct.pack('<' + 'h' * len(samples), *samples)
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
