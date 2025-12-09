#!/usr/bin/env python3
"""
Generate Music Box (オルゴール) audio for TsukiSound

Generates a gentle, dreamy music box melody with:
- Bell-like metallic tones with quick decay
- Simple lullaby-style melody (based on Brahms' Lullaby)
- Soft reverb for dreamy atmosphere
- 60 BPM, 3/4 time signature

Output: WAV file (to be converted to CAF for iOS)
"""

import numpy as np
from scipy.io import wavfile
import os

from audio_utils import apply_silence_padding

# Constants
SAMPLE_RATE = 48000
OUTPUT_DIR = "../TsukiSound/Resources/Audio"

# Timing Constants (60 BPM - slower, dreamy)
BPM = 60
BEAT = 60.0 / BPM  # 1 beat = 1.0 second
BAR_DURATION = BEAT * 3  # 3/4 time
TOTAL_BARS = 32  # ~96 seconds total
CYCLE_DURATION = TOTAL_BARS * BAR_DURATION

# ============================================================================
# Frequency Constants (F Major - warm, lullaby-like)
# ============================================================================

# Octave 4 (middle)
C4 = 261.63
D4 = 293.66
E4 = 329.63
F4 = 349.23
G4 = 392.00
A4 = 440.00
Bb4 = 466.16  # B-flat
B4 = 493.88

# Octave 5 (higher, bell-like)
C5 = 523.25
D5 = 587.33
E5 = 659.25
F5 = 698.46
G5 = 783.99
A5 = 880.00
Bb5 = 932.33
B5 = 987.77

# Octave 6 (sparkle)
C6 = 1046.50
D6 = 1174.66
E6 = 1318.51
F6 = 1396.91

# ============================================================================
# Music Box Sound Parameters
# ============================================================================

# Music box characteristics: quick attack, medium decay, bell-like harmonics
MELODY_ATTACK = 0.005  # Very quick attack (metallic strike)
MELODY_DECAY = 2.5     # Medium decay
MELODY_GAIN = 0.35

# Accompaniment (lower register, softer)
ACC_ATTACK = 0.008
ACC_DECAY = 1.8
ACC_GAIN = 0.15

# ============================================================================
# Music Box Tone Synthesis
# ============================================================================

def music_box_tone(freq, t, brightness=1.0):
    """
    Generate music box bell-like tone.

    Music box characteristics:
    - Strong fundamental
    - Prominent 2nd and 3rd harmonics
    - Subtle inharmonic partials (gives metallic quality)
    - Quick high-frequency decay (shimmer fades faster)
    """
    signal = np.zeros_like(t)

    # Harmonic series with music box character
    harmonics = [
        (1.0, 1.00),      # Fundamental
        (2.0, 0.60),      # Octave
        (3.0, 0.35),      # Fifth above octave
        (4.0, 0.20),      # 2 octaves
        (5.0, 0.10),      # Major 3rd above 2 octaves
        (6.0, 0.05),      #
    ]

    # Slightly inharmonic partials for metallic quality
    inharmonics = [
        (2.756, 0.08 * brightness),  # Slightly detuned
        (4.112, 0.04 * brightness),  # Bell-like partial
    ]

    for harmonic, amp in harmonics:
        # Higher harmonics decay faster (simulate real music box)
        decay_mult = 1.0 / (1.0 + (harmonic - 1) * 0.3)
        decay_env = np.exp(-t * (1.0 / MELODY_DECAY) * (1.0 + (harmonic - 1) * 0.5))
        signal += amp * decay_mult * np.sin(2 * np.pi * freq * harmonic * t) * decay_env

    # Add inharmonic partials (subtle)
    for partial, amp in inharmonics:
        decay_env = np.exp(-t * (1.0 / MELODY_DECAY) * 2.0)  # Faster decay
        signal += amp * np.sin(2 * np.pi * freq * partial * t) * decay_env

    # Normalize
    return signal / 1.5

# ============================================================================
# Envelope Functions
# ============================================================================

def music_box_envelope(t, duration, attack=MELODY_ATTACK, decay=MELODY_DECAY):
    """
    Music box envelope: instant attack, exponential decay.
    """
    env = np.ones_like(t)

    # Very quick attack (strike)
    attack_mask = t < attack
    if np.any(attack_mask):
        env[attack_mask] = t[attack_mask] / attack

    # Exponential decay
    decay_mask = t >= attack
    if np.any(decay_mask):
        decay_t = t[decay_mask] - attack
        env[decay_mask] = np.exp(-decay_t / decay)

    # Ensure clean end
    end_fade = 0.05
    end_mask = t >= duration - end_fade
    if np.any(end_mask):
        fade_t = t[end_mask] - (duration - end_fade)
        env[end_mask] *= 1.0 - (fade_t / end_fade)

    return env

# ============================================================================
# Melody Note Data
# ============================================================================

class Note:
    def __init__(self, freq, bar, beat, dur_beats, gain=None):
        self.freq = freq
        self.bar = bar      # 1-indexed
        self.beat = beat    # 0, 1, 2 (for 3/4)
        self.dur_beats = dur_beats
        self.gain = gain

def get_melody_notes():
    """
    Simple lullaby melody inspired by Brahms' Lullaby.
    Adapted to F Major for a warm, gentle feel.
    """
    notes = []

    # Section A - Bars 1-8 (Theme)
    # Bar 1: pickup
    notes.append(Note(A5, 1, 2, 1))
    # Bar 2
    notes.append(Note(A5, 2, 0, 1))
    notes.append(Note(C6, 2, 1, 2))
    # Bar 3
    notes.append(Note(A5, 3, 0, 1))
    notes.append(Note(C6, 3, 1, 1))
    notes.append(Note(F6, 3, 2, 1))
    # Bar 4
    notes.append(Note(E6, 4, 0, 3))
    # Bar 5
    notes.append(Note(G5, 5, 2, 1))
    # Bar 6
    notes.append(Note(G5, 6, 0, 1))
    notes.append(Note(Bb5, 6, 1, 2))
    # Bar 7
    notes.append(Note(G5, 7, 0, 1))
    notes.append(Note(Bb5, 7, 1, 1))
    notes.append(Note(E6, 7, 2, 1))
    # Bar 8
    notes.append(Note(F6, 8, 0, 3))

    # Section A' - Bars 9-16 (Theme repeat with variation)
    # Bar 9
    notes.append(Note(A5, 9, 2, 1))
    # Bar 10
    notes.append(Note(A5, 10, 0, 1))
    notes.append(Note(C6, 10, 1, 2))
    # Bar 11
    notes.append(Note(A5, 11, 0, 1))
    notes.append(Note(C6, 11, 1, 1))
    notes.append(Note(F6, 11, 2, 1))
    # Bar 12
    notes.append(Note(E6, 12, 0, 2))
    notes.append(Note(D6, 12, 2, 1))
    # Bar 13
    notes.append(Note(C6, 13, 0, 1))
    notes.append(Note(D6, 13, 1, 1))
    notes.append(Note(E6, 13, 2, 1))
    # Bar 14
    notes.append(Note(F6, 14, 0, 2))
    notes.append(Note(E6, 14, 2, 1))
    # Bar 15
    notes.append(Note(D6, 15, 0, 1))
    notes.append(Note(C6, 15, 1, 1))
    notes.append(Note(Bb5, 15, 2, 1))
    # Bar 16
    notes.append(Note(A5, 16, 0, 3))

    # Section B - Bars 17-24 (Contrasting section)
    # Bar 17
    notes.append(Note(D6, 17, 1, 1))
    notes.append(Note(D6, 17, 2, 1))
    # Bar 18
    notes.append(Note(D6, 18, 0, 1))
    notes.append(Note(E6, 18, 1, 2))
    # Bar 19
    notes.append(Note(C6, 19, 0, 1))
    notes.append(Note(C6, 19, 1, 1))
    notes.append(Note(C6, 19, 2, 1))
    # Bar 20
    notes.append(Note(C6, 20, 0, 1))
    notes.append(Note(D6, 20, 1, 2))
    # Bar 21
    notes.append(Note(Bb5, 21, 0, 1))
    notes.append(Note(Bb5, 21, 1, 1))
    notes.append(Note(Bb5, 21, 2, 1))
    # Bar 22
    notes.append(Note(Bb5, 22, 0, 1))
    notes.append(Note(C6, 22, 1, 1))
    notes.append(Note(D6, 22, 2, 1))
    # Bar 23
    notes.append(Note(C6, 23, 0, 2))
    notes.append(Note(Bb5, 23, 2, 1))
    # Bar 24
    notes.append(Note(A5, 24, 0, 3))

    # Section A'' - Bars 25-32 (Final theme, gentle ending)
    # Bar 25
    notes.append(Note(A5, 25, 2, 1))
    # Bar 26
    notes.append(Note(A5, 26, 0, 1))
    notes.append(Note(C6, 26, 1, 2))
    # Bar 27
    notes.append(Note(A5, 27, 0, 1))
    notes.append(Note(C6, 27, 1, 1))
    notes.append(Note(F6, 27, 2, 1))
    # Bar 28
    notes.append(Note(E6, 28, 0, 3))
    # Bar 29
    notes.append(Note(D6, 29, 0, 1))
    notes.append(Note(C6, 29, 1, 1))
    notes.append(Note(Bb5, 29, 2, 1))
    # Bar 30
    notes.append(Note(A5, 30, 0, 2))
    notes.append(Note(G5, 30, 2, 1))
    # Bar 31
    notes.append(Note(F5, 31, 0, 3))
    # Bar 32 (final, very soft)
    notes.append(Note(F5, 32, 0, 3, gain=0.2))

    return notes

def get_accompaniment_notes():
    """
    Simple accompaniment: bass notes on beat 1, chord tones on beats 2-3.
    F Major tonality.
    """
    notes = []

    # Pattern: Bass (beat 1), then two chord tones (beats 2, 3)
    patterns = [
        # Bars 1-4: F major
        {'bars': [1, 2, 3, 4], 'bass': F4, 'chord': [A4, C5]},
        # Bars 5-8: Bb major, then F
        {'bars': [5, 6], 'bass': Bb4, 'chord': [D5, F5]},
        {'bars': [7, 8], 'bass': F4, 'chord': [A4, C5]},
        # Bars 9-12: F major
        {'bars': [9, 10, 11, 12], 'bass': F4, 'chord': [A4, C5]},
        # Bars 13-16: C7 -> F
        {'bars': [13, 14], 'bass': C4, 'chord': [E4, Bb4]},
        {'bars': [15, 16], 'bass': F4, 'chord': [A4, C5]},
        # Bars 17-20: Bb -> C
        {'bars': [17, 18], 'bass': Bb4, 'chord': [D5, F5]},
        {'bars': [19, 20], 'bass': C4, 'chord': [E4, G4]},
        # Bars 21-24: Bb -> F
        {'bars': [21, 22], 'bass': Bb4, 'chord': [D5, F5]},
        {'bars': [23, 24], 'bass': F4, 'chord': [A4, C5]},
        # Bars 25-32: F major (gentle ending)
        {'bars': [25, 26, 27, 28], 'bass': F4, 'chord': [A4, C5]},
        {'bars': [29, 30], 'bass': Bb4, 'chord': [D5, F5]},
        {'bars': [31, 32], 'bass': F4, 'chord': [A4, C5]},
    ]

    for pattern in patterns:
        for bar in pattern['bars']:
            # Bass on beat 1
            notes.append(Note(pattern['bass'], bar, 0, 1))
            # Chord tones on beats 2 and 3
            notes.append(Note(pattern['chord'][0], bar, 1, 0.8))
            notes.append(Note(pattern['chord'][1], bar, 2, 0.8))

    return notes

# ============================================================================
# Schroeder Reverb (simplified for music box)
# ============================================================================

class MusicBoxReverb:
    """Lighter reverb for music box - more sparkle, less mud."""

    def __init__(self, room_size=1.5, damping=0.6, decay=0.5, mix=0.25, predelay=0.015):
        self.room_size = room_size
        self.damping = damping
        self.decay = decay
        self.mix = mix
        self.predelay = predelay

        # Shorter delays for smaller room feel
        base_delays = [1116, 1188, 1277, 1356]
        self.comb_delays = [int(d * room_size) for d in base_delays]
        self.allpass_delays = [225, 556, 441, 341]

    def process(self, signal):
        predelay_samples = int(self.predelay * SAMPLE_RATE)
        delayed = np.concatenate([np.zeros(predelay_samples), signal])

        # Comb filters
        comb_out = np.zeros(len(delayed))
        for delay in self.comb_delays:
            comb_out += self._comb_filter(delayed, delay)
        comb_out /= len(self.comb_delays)

        # Allpass filters
        allpass_out = comb_out
        for delay in self.allpass_delays:
            allpass_out = self._allpass_filter(allpass_out, delay)

        wet = allpass_out[:len(signal)]
        return signal * (1 - self.mix) + wet * self.mix

    def _comb_filter(self, signal, delay):
        output = np.zeros(len(signal))
        feedback = self.decay
        damp = self.damping
        prev = 0

        for i in range(len(signal)):
            if i >= delay:
                prev = output[i - delay] * (1 - damp) + prev * damp
                output[i] = signal[i] + prev * feedback
            else:
                output[i] = signal[i]

        return output

    def _allpass_filter(self, signal, delay):
        output = np.zeros(len(signal))
        g = 0.5

        for i in range(len(signal)):
            if i >= delay:
                output[i] = -g * signal[i] + signal[i - delay] + g * output[i - delay]
            else:
                output[i] = signal[i] * (1 - g)

        return output

# ============================================================================
# Signal Generation
# ============================================================================

def generate_melody(duration):
    """Generate melody layer."""
    num_samples = int(duration * SAMPLE_RATE)
    signal = np.zeros(num_samples, dtype=np.float64)
    t_global = np.linspace(0, duration, num_samples, endpoint=False)

    melody_notes = get_melody_notes()

    for note in melody_notes:
        note_start = (note.bar - 1) * BAR_DURATION + note.beat * BEAT
        note_dur = note.dur_beats * BEAT
        note_end = note_start + note_dur

        mask = (t_global >= note_start) & (t_global < note_end)
        if not np.any(mask):
            continue

        t_local = t_global[mask] - note_start

        # Music box tone
        tone = music_box_tone(note.freq, t_local)

        # Envelope
        env = music_box_envelope(t_local, note_dur)

        # Gain
        gain = note.gain if note.gain else MELODY_GAIN

        signal[mask] += tone * env * gain

    return signal

def generate_accompaniment(duration):
    """Generate accompaniment layer (softer, lower register)."""
    num_samples = int(duration * SAMPLE_RATE)
    signal = np.zeros(num_samples, dtype=np.float64)
    t_global = np.linspace(0, duration, num_samples, endpoint=False)

    acc_notes = get_accompaniment_notes()

    for note in acc_notes:
        note_start = (note.bar - 1) * BAR_DURATION + note.beat * BEAT
        note_dur = note.dur_beats * BEAT
        note_end = note_start + note_dur

        mask = (t_global >= note_start) & (t_global < note_end)
        if not np.any(mask):
            continue

        t_local = t_global[mask] - note_start

        # Music box tone (less bright for accompaniment)
        tone = music_box_tone(note.freq, t_local, brightness=0.5)

        # Envelope (shorter decay for accompaniment)
        env = music_box_envelope(t_local, note_dur, attack=ACC_ATTACK, decay=ACC_DECAY)

        signal[mask] += tone * env * ACC_GAIN

    return signal

def soft_clip(signal, threshold=0.9):
    """Soft clip to prevent harsh distortion."""
    return np.tanh(signal / threshold) * threshold

def generate_music_box():
    """Generate complete music box audio."""
    duration = CYCLE_DURATION

    print("  Generating melody layer...")
    melody = generate_melody(duration)

    print("  Generating accompaniment layer...")
    accompaniment = generate_accompaniment(duration)

    print("  Mixing layers...")
    mixed = melody + accompaniment
    mixed = soft_clip(mixed)

    print("  Applying reverb...")
    reverb = MusicBoxReverb(
        room_size=1.5,
        damping=0.55,
        decay=0.45,
        mix=0.22,
        predelay=0.012
    )
    processed = reverb.process(mixed)

    # Final soft limiting
    processed = soft_clip(processed * 1.05, threshold=0.95)

    # Apply silence padding for seamless looping
    print("  Applying silence padding (fade-in: 0.5s, fade-out: 2.5s)...")
    padded = apply_silence_padding(processed, fade_in_duration=0.5, fade_out_duration=2.5)

    # Normalize
    max_val = np.max(np.abs(padded))
    if max_val > 0:
        padded = padded / max_val * 0.9

    return padded.astype(np.float32)

# ============================================================================
# File Output
# ============================================================================

def save_wav(signal, filename, sample_rate=SAMPLE_RATE):
    """Save signal as WAV file."""
    signal_int16 = (signal * 32767).astype(np.int16)
    wavfile.write(filename, sample_rate, signal_int16)

def main():
    print("=" * 60)
    print("Music Box Audio Generator for TsukiSound")
    print("=" * 60)
    print(f"Sample rate: {SAMPLE_RATE} Hz")
    print(f"BPM: {BPM}")
    print(f"Duration: {CYCLE_DURATION:.1f}s ({TOTAL_BARS} bars)")
    print(f"Output directory: {OUTPUT_DIR}")
    print()

    # Ensure output directory exists
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_DIR)
    os.makedirs(output_path, exist_ok=True)

    # Generate audio
    print("Generating Music Box melody...")
    signal = generate_music_box()

    # Save WAV
    wav_path = os.path.join(output_path, "music_box.wav")
    save_wav(signal, wav_path)
    print(f"Saved: music_box.wav")

    print()
    print("=" * 60)
    print("WAV file generated successfully!")
    print()
    print("Next step: Convert to CAF format using:")
    print()
    print(f"  cd {output_path}")
    print("  afconvert -f caff -d LEF32@48000 -c 1 music_box.wav music_box.caf")
    print("=" * 60)

if __name__ == "__main__":
    main()
