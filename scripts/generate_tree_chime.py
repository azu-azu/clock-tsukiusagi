#!/usr/bin/env python3
"""
Generate Tree Chime audio files for TsukiSound

Generates metallic shimmer "tree chime" sounds with:
- High-frequency metallic grains cascading (low → high glissando)
- Random phase offset for natural sound
- Exponential decay envelope
- Multiple variations for randomness in playback

Output: WAV files (to be converted to CAF for iOS)
"""

import numpy as np
from scipy.io import wavfile
import os

# Constants
SAMPLE_RATE = 48000
OUTPUT_DIR = "../TsukiSound/Resources/Audio"

def generate_single_chime(
    duration: float = 2.0,
    num_grains: int = 24,
    cascade_interval: float = 0.020,
    grain_duration: float = 1.2,
    base_freq: float = 6000.0,
    detune_range: float = 3.0,  # ±1.5Hz (small to prevent beat interference)
    seed: int = 42
) -> np.ndarray:
    """
    Generate a single tree chime sound.

    Args:
        duration: Total duration in seconds
        num_grains: Number of metallic grains
        cascade_interval: Time between each grain start (seconds)
        grain_duration: Decay time constant for each grain
        base_freq: Base frequency for the chime (Hz)
        detune_range: Total detune range in Hz (±half)
        seed: Random seed for reproducibility

    Returns:
        Audio signal as numpy array (float32, normalized)
    """
    np.random.seed(seed)

    num_samples = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, num_samples, endpoint=False)

    # Generate base frequencies for each grain (low → high glissando)
    base_freqs = [base_freq * (0.8 + (i / (num_grains - 1)) * 0.5)
                  for i in range(num_grains)]

    # Generate random values for each grain
    detunes = (np.random.random(num_grains) - 0.5) * detune_range
    phase_offsets = np.random.random(num_grains) * 2 * np.pi

    signal = np.zeros(num_samples, dtype=np.float64)

    for i in range(num_grains):
        grain_start_time = i * cascade_interval
        grain_start_sample = int(grain_start_time * SAMPLE_RATE)

        if grain_start_sample >= num_samples:
            break

        # Calculate grain signal
        grain_t = t[grain_start_sample:] - grain_start_time

        # Frequency with detune
        freq = base_freqs[i] + detunes[i]

        # Phase with random offset
        phase = 2 * np.pi * freq * grain_t + phase_offsets[i]

        # Exponential decay envelope
        envelope = np.exp(-grain_t / grain_duration)

        # Add to signal
        grain_signal = np.sin(phase) * envelope
        signal[grain_start_sample:] += grain_signal

    # Normalize
    max_val = np.max(np.abs(signal))
    if max_val > 0:
        signal = signal / max_val

    return signal.astype(np.float32)


def generate_chime_variations(
    num_variations: int = 5,
    duration: float = 2.0
) -> list:
    """
    Generate multiple chime variations for randomness.

    Args:
        num_variations: Number of variations to generate
        duration: Duration of each chime

    Returns:
        List of (name, signal) tuples
    """
    variations = []

    # Base parameters
    base_params = {
        'duration': duration,
        'num_grains': 24,
        'cascade_interval': 0.020,
        'grain_duration': 1.2,
        'base_freq': 6000.0,
        'detune_range': 3.0,
    }

    for i in range(num_variations):
        # Vary parameters slightly for each variation
        params = base_params.copy()

        # Different seed for each variation
        params['seed'] = 1000 + i * 137

        # Slight variations in brightness
        freq_variation = [5500, 5800, 6000, 6200, 6500][i % 5]
        params['base_freq'] = freq_variation

        signal = generate_single_chime(**params)
        name = f"tree_chime_{i+1}"
        variations.append((name, signal))

    return variations


def save_wav(signal: np.ndarray, filename: str, sample_rate: int = SAMPLE_RATE):
    """Save signal as WAV file."""
    # Convert to 16-bit PCM for WAV
    signal_int16 = (signal * 32767).astype(np.int16)
    wavfile.write(filename, sample_rate, signal_int16)


def main():
    print("=" * 60)
    print("Tree Chime Audio Generator for TsukiSound")
    print("=" * 60)
    print(f"Sample rate: {SAMPLE_RATE} Hz")
    print(f"Output directory: {OUTPUT_DIR}")
    print()

    # Ensure output directory exists
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_DIR)
    os.makedirs(output_path, exist_ok=True)

    # Generate variations
    print("Generating tree chime variations...")
    variations = generate_chime_variations(num_variations=5, duration=2.0)

    # Save each variation
    for name, signal in variations:
        wav_path = os.path.join(output_path, f"{name}.wav")
        save_wav(signal, wav_path)
        print(f"  Saved: {name}.wav")

    print()
    print("=" * 60)
    print("WAV files generated successfully!")
    print()
    print("Next step: Convert to CAF format using:")
    print()
    print("  cd TsukiSound/Resources/Audio")
    print("  for f in tree_chime_*.wav; do")
    print('    base="${f%.wav}"')
    print('    afconvert -f caff -d LEF32@48000 -c 1 "$f" "${base}.caf"')
    print("  done")
    print("=" * 60)


if __name__ == "__main__":
    main()
