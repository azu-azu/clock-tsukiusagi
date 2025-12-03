#!/usr/bin/env python3
"""
Generate Moonlit Gymnopédie audio for TsukiSound

Generates Satie - Gymnopédie No.1 (Public Domain) with:
- 3-layer structure: Bass + Chord + Melody
- 88 BPM, 3/4 time signature, D Major
- Pure sine waves with subtle detuning for depth
- Schroeder reverb for spacious, moonlit atmosphere

Based on Swift implementation: GymnopedieSignal.swift + GymnopedieMelodyData.swift

Output: WAV file (to be converted to CAF for iOS)
"""

import numpy as np
from scipy.io import wavfile
import os

# Constants
SAMPLE_RATE = 48000
OUTPUT_DIR = "../TsukiSound/Resources/Audio"

# Timing Constants (88 BPM)
BEAT = 0.682  # 1 beat = 0.682 seconds
BAR_DURATION = BEAT * 3  # 1 bar = 3 beats (3/4 time)
TOTAL_BARS = 41  # Bar 39 + 2 bars for reverb tail
CYCLE_DURATION = TOTAL_BARS * BAR_DURATION

# Structure Constants
CLIMAX_BAR = 39
DETUNE_HZ = 0.2

# ============================================================================
# Frequency Constants (D Major: F#, C#)
# ============================================================================

# Bass
D3 = 146.83
E3 = 164.81
G3 = 196.00

# Chord
A3 = 220.00
B3 = 246.94
Cs4 = 277.18   # C#4
D4 = 293.66

# Melody (wide range)
E4 = 329.63
Fs4 = 369.99   # F#4
G4 = 392.00
A4 = 440.00
B4 = 493.88
C5 = 523.25    # C5 (natural)
Cs5 = 554.37   # C#5
D5 = 587.33
E5 = 659.25
F5 = 698.46    # F5 (natural)
Fs5 = 739.99   # F#5
G5 = 783.99
A5 = 880.00
B5 = 987.77
C6 = 1046.50
D6 = 1174.66
E6 = 1318.51

# ============================================================================
# Sound Parameters
# ============================================================================

MELODY_ATTACK = 0.15
MELODY_DECAY = 4.5
MELODY_GAIN = 0.28

BASS_ATTACK = 0.20
BASS_DECAY = 3.5
BASS_GAIN = 0.16

CHORD_ATTACK = 0.08
CHORD_DECAY = 2.5
CHORD_GAIN = 0.06

# ============================================================================
# Melody Note Data Structure
# ============================================================================

class MelodyNote:
    def __init__(self, freq, start_bar, start_beat, dur_beats, custom_gain=None, fade_out=False):
        self.freq = freq
        self.start_bar = start_bar  # 1-indexed
        self.start_beat = start_beat  # 0, 1, 2
        self.dur_beats = dur_beats
        self.custom_gain = custom_gain
        self.fade_out = fade_out

# ============================================================================
# Melody Data (from GymnopedieMelodyData.swift)
# ============================================================================

def get_melody_notes():
    """All melody notes for Gymnopédie No.1"""
    notes = []

    # Section G1 - Bars 1-12 (Intro + Theme A)
    # Bar 1-4: Intro (No Melody)
    # Bar 5 (Melody Enters)
    notes.append(MelodyNote(Fs5, 5, 1, 1))
    notes.append(MelodyNote(A5, 5, 2, 1))
    # Bar 6
    notes.append(MelodyNote(G5, 6, 0, 1))
    notes.append(MelodyNote(Fs5, 6, 1, 1))
    notes.append(MelodyNote(Cs5, 6, 2, 1))
    # Bar 7
    notes.append(MelodyNote(B4, 7, 0, 1))
    notes.append(MelodyNote(Cs5, 7, 1, 1))
    notes.append(MelodyNote(D5, 7, 2, 1))
    # Bar 8
    notes.append(MelodyNote(A4, 8, 0, 3))
    # Bar 9-12: F#4 sustain with fade out
    notes.append(MelodyNote(Fs4, 9, 0, 12, fade_out=True))

    # Section G2 - Bars 13-21 (Theme repeat + Development)
    # Bar 13
    notes.append(MelodyNote(Fs5, 13, 1, 1))
    notes.append(MelodyNote(A5, 13, 2, 1))
    # Bar 14
    notes.append(MelodyNote(G5, 14, 0, 1))
    notes.append(MelodyNote(Fs5, 14, 1, 1))
    notes.append(MelodyNote(Cs5, 14, 2, 1))
    # Bar 15
    notes.append(MelodyNote(B4, 15, 0, 1))
    notes.append(MelodyNote(Cs5, 15, 1, 1))
    notes.append(MelodyNote(D5, 15, 2, 1))
    # Bar 16
    notes.append(MelodyNote(A4, 16, 0, 3))
    # Bar 17
    notes.append(MelodyNote(Cs5, 17, 0, 3))
    # Bar 18
    notes.append(MelodyNote(Fs5, 18, 0, 3))
    # Bar 19-21: E5 sustain with fade out
    notes.append(MelodyNote(E5, 19, 0, 9, fade_out=True))

    # Section G3 - Bars 22-26 (Development)
    # Bar 22
    notes.append(MelodyNote(A4, 22, 0, 1))
    notes.append(MelodyNote(B4, 22, 1, 1))
    notes.append(MelodyNote(C5, 22, 2, 1))  # C natural
    # Bar 23
    notes.append(MelodyNote(E5, 23, 0, 1))
    notes.append(MelodyNote(D5, 23, 1, 1))
    notes.append(MelodyNote(B4, 23, 2, 1))
    # Bar 24
    notes.append(MelodyNote(D5, 24, 0, 1))
    notes.append(MelodyNote(C5, 24, 1, 1))  # C natural
    notes.append(MelodyNote(B4, 24, 2, 1))
    notes.append(MelodyNote(E4, 24, 1, 2))  # Alto
    # Bar 25-26
    notes.append(MelodyNote(D5, 25, 0, 5))
    notes.append(MelodyNote(D4, 25, 1, 2))  # Alto
    notes.append(MelodyNote(D5, 26, 2, 1))
    notes.append(MelodyNote(D4, 26, 1, 2))  # Alto

    # Section G4 - Bars 27-31 (Ascending passage)
    # Bar 27
    notes.append(MelodyNote(E5, 27, 0, 1))
    notes.append(MelodyNote(F5, 27, 1, 1))  # F natural
    notes.append(MelodyNote(G5, 27, 2, 1))
    # Bar 28
    notes.append(MelodyNote(A5, 28, 0, 1))
    notes.append(MelodyNote(C5, 28, 1, 1))  # C natural
    notes.append(MelodyNote(D5, 28, 2, 1))
    # Bar 29
    notes.append(MelodyNote(E5, 29, 0, 1))
    notes.append(MelodyNote(D5, 29, 1, 1))
    notes.append(MelodyNote(B4, 29, 2, 1))
    notes.append(MelodyNote(E4, 29, 1, 2))  # Alto
    # Bar 30-31
    notes.append(MelodyNote(D5, 30, 0, 5))
    notes.append(MelodyNote(D4, 30, 1, 2))  # Alto
    notes.append(MelodyNote(D5, 31, 2, 1))
    notes.append(MelodyNote(D4, 31, 1, 2))  # Alto

    # Section G5 - Bars 32-39 (Final section + Climax)
    # Bar 32
    notes.append(MelodyNote(G5, 32, 0, 3))
    # Bar 33
    notes.append(MelodyNote(Fs5, 33, 0, 3))
    # Bar 34
    notes.append(MelodyNote(B4, 34, 0, 1))
    notes.append(MelodyNote(A4, 34, 1, 1))
    notes.append(MelodyNote(B4, 34, 2, 1))
    # Bar 35
    notes.append(MelodyNote(Cs5, 35, 0, 1))
    notes.append(MelodyNote(D5, 35, 1, 1))
    notes.append(MelodyNote(E5, 35, 2, 1))
    # Bar 36
    notes.append(MelodyNote(Cs5, 36, 0, 1))
    notes.append(MelodyNote(D5, 36, 1, 1))
    notes.append(MelodyNote(E5, 36, 2, 1))
    # Bar 37
    notes.append(MelodyNote(Fs4, 37, 0, 3))
    notes.append(MelodyNote(D4, 37, 1, 1))  # Alto
    notes.append(MelodyNote(G4, 37, 2, 1))  # Alto

    # Bar 38: Am context - quiet preparation (staggered layers)
    notes.append(MelodyNote(A3, 38, 0.00, 3.5, custom_gain=0.14))
    notes.append(MelodyNote(E4, 38, 0.12, 3.3, custom_gain=0.10))
    notes.append(MelodyNote(A4, 38, 0.24, 3.1, custom_gain=0.09))

    # Bar 39: D Major - final climax (staggered layers)
    notes.append(MelodyNote(D3, 39, 0.00, 6.0, custom_gain=0.16))
    notes.append(MelodyNote(D4, 39, 0.12, 5.8, custom_gain=0.10))
    notes.append(MelodyNote(A4, 39, 0.21, 5.5, custom_gain=0.12))
    notes.append(MelodyNote(D5, 39, 0.30, 5.2, custom_gain=0.08))

    return notes

# ============================================================================
# Bass & Chord Data (per bar)
# ============================================================================

def get_bass_chord_data():
    """
    Bass & Chord patterns:
    - Default odd bars: Bass=G3, Chord=B3+D4
    - Default even bars: Bass=D3, Chord=A3+C#4
    - E minor context (bars 9-12, 19-21): Bass=E3, Chord=B3+D4
    """
    data = []

    for bar in range(1, TOTAL_BARS + 1):
        if bar in [9, 10, 11, 12, 19, 20, 21]:
            # E minor context
            bass_freq = E3
            chord_freqs = [B3, D4]
        elif bar % 2 == 1:
            # Default odd
            bass_freq = G3
            chord_freqs = [B3, D4]
        else:
            # Default even
            bass_freq = D3
            chord_freqs = [A3, Cs4]

        data.append({
            'bar': bar,
            'bass_freq': bass_freq,
            'chord_freqs': chord_freqs
        })

    return data

# ============================================================================
# Envelope & Synthesis Utilities
# ============================================================================

def smooth_envelope(t, duration, attack, decay):
    """
    Smooth attack-decay envelope using cosine curves.
    """
    env = np.ones_like(t)

    # Attack phase (cosine fade in)
    attack_mask = t < attack
    if np.any(attack_mask):
        env[attack_mask] = 0.5 * (1.0 - np.cos(np.pi * t[attack_mask] / attack))

    # Decay phase (exponential decay starting after attack)
    decay_start = attack
    decay_mask = t >= decay_start
    if np.any(decay_mask):
        decay_t = t[decay_mask] - decay_start
        env[decay_mask] *= np.exp(-decay_t / decay)

    # Ensure envelope reaches zero at note end
    end_mask = t >= duration - 0.05
    if np.any(end_mask):
        fade_t = t[end_mask] - (duration - 0.05)
        fade_factor = 1.0 - (fade_t / 0.05)
        fade_factor = np.clip(fade_factor, 0, 1)
        env[end_mask] *= fade_factor

    return env

def pure_sine(freq, t, phase=0):
    """Generate pure sine wave."""
    return np.sin(2 * np.pi * freq * t + phase)

def soft_clip(signal, threshold=0.9):
    """Soft clip to prevent harsh distortion."""
    return np.tanh(signal / threshold) * threshold

# ============================================================================
# Schroeder Reverb (from generate_cathedral_stillness.py)
# ============================================================================

class SchroederReverb:
    """Schroeder reverb implementation matching Swift version."""

    def __init__(self, room_size=2.2, damping=0.40, decay=0.85, mix=0.45, predelay=0.030):
        self.room_size = room_size
        self.damping = damping
        self.decay = decay
        self.mix = mix
        self.predelay = predelay

        # Comb filter delays (in samples)
        base_delays = [1557, 1617, 1491, 1422]
        self.comb_delays = [int(d * room_size) for d in base_delays]

        # Allpass filter delays
        self.allpass_delays = [225, 556, 441, 341]

    def process(self, signal):
        """Process signal through reverb."""
        # Pre-delay
        predelay_samples = int(self.predelay * SAMPLE_RATE)
        delayed = np.concatenate([np.zeros(predelay_samples), signal])

        # Comb filters (parallel)
        comb_out = np.zeros(len(delayed))
        for delay in self.comb_delays:
            comb_out += self._comb_filter(delayed, delay)
        comb_out /= len(self.comb_delays)

        # Allpass filters (series)
        allpass_out = comb_out
        for delay in self.allpass_delays:
            allpass_out = self._allpass_filter(allpass_out, delay)

        # Trim to original length and mix
        wet = allpass_out[:len(signal)]
        return signal * (1 - self.mix) + wet * self.mix

    def _comb_filter(self, signal, delay):
        """Comb filter with feedback and damping."""
        output = np.zeros(len(signal))
        feedback = self.decay
        damp = self.damping
        prev = 0

        for i in range(len(signal)):
            if i >= delay:
                # Low-pass filtered feedback
                prev = output[i - delay] * (1 - damp) + prev * damp
                output[i] = signal[i] + prev * feedback
            else:
                output[i] = signal[i]

        return output

    def _allpass_filter(self, signal, delay):
        """Allpass filter."""
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
        note_start = (note.start_bar - 1) * BAR_DURATION + note.start_beat * BEAT
        note_dur = note.dur_beats * BEAT
        note_end = note_start + note_dur

        # Find samples in this note's range
        mask = (t_global >= note_start) & (t_global < note_end)
        if not np.any(mask):
            continue

        # Local time relative to note start
        t_local = t_global[mask] - note_start

        # Determine effective decay (climax extends decay)
        is_climax = note.start_bar >= CLIMAX_BAR
        effective_decay = MELODY_DECAY * 2.0 if is_climax else MELODY_DECAY

        # Determine gain
        if note.custom_gain is not None:
            effective_gain = note.custom_gain
        else:
            effective_gain = MELODY_GAIN
            # High frequency reduction (600Hz+)
            if note.freq >= 600.0:
                max_freq = E6
                min_freq = 600.0
                reduction_ratio = min(1.0, (note.freq - min_freq) / (max_freq - min_freq))
                high_freq_reduction = 1.0 - reduction_ratio * 0.35
                effective_gain *= high_freq_reduction

        # Generate envelope
        env = smooth_envelope(t_local, note_dur, MELODY_ATTACK, effective_decay)

        # Fade out for long sustain notes
        if note.fade_out:
            progress = t_local / note_dur
            fade_mask = progress > 0.5
            if np.any(fade_mask):
                fade_progress = (progress[fade_mask] - 0.5) * 2.0
                fade_multiplier = 0.3 + 0.7 * (1.0 + np.cos(fade_progress * np.pi)) / 2.0
                env[fade_mask] *= fade_multiplier

        # Detuned sine layers
        t_note = t_global[mask]
        v1 = pure_sine(note.freq, t_note)
        v2 = pure_sine(note.freq + DETUNE_HZ, t_note)
        v3 = pure_sine(note.freq - DETUNE_HZ, t_note)
        layered = (v1 + v2 + v3) / 3.0

        signal[mask] += layered * env * effective_gain

    return signal

def generate_bass(duration):
    """Generate bass layer."""
    num_samples = int(duration * SAMPLE_RATE)
    signal = np.zeros(num_samples, dtype=np.float64)
    t_global = np.linspace(0, duration, num_samples, endpoint=False)

    bass_chord_data = get_bass_chord_data()

    for data in bass_chord_data:
        note_start = (data['bar'] - 1) * BAR_DURATION
        note_dur = BAR_DURATION
        note_end = note_start + note_dur

        mask = (t_global >= note_start) & (t_global < note_end)
        if not np.any(mask):
            continue

        t_local = t_global[mask] - note_start
        env = smooth_envelope(t_local, note_dur, BASS_ATTACK, BASS_DECAY)

        t_note = t_global[mask]
        v = pure_sine(data['bass_freq'], t_note)
        signal[mask] += v * env * BASS_GAIN

    return signal

def generate_chords(duration):
    """Generate chord layer."""
    num_samples = int(duration * SAMPLE_RATE)
    signal = np.zeros(num_samples, dtype=np.float64)
    t_global = np.linspace(0, duration, num_samples, endpoint=False)

    bass_chord_data = get_bass_chord_data()

    for data in bass_chord_data:
        # Chords start on beat 2 (after bass on beat 1)
        chord_start = (data['bar'] - 1) * BAR_DURATION + BEAT
        chord_dur = 2 * BEAT  # Beats 2 and 3
        chord_end = chord_start + chord_dur

        mask = (t_global >= chord_start) & (t_global < chord_end)
        if not np.any(mask):
            continue

        t_local = t_global[mask] - chord_start
        env = smooth_envelope(t_local, chord_dur, CHORD_ATTACK, CHORD_DECAY)

        # Detuned chord layers
        t_note = t_global[mask]
        chord_val = np.zeros(len(t_note))
        for freq in data['chord_freqs']:
            v1 = pure_sine(freq, t_note)
            v2 = pure_sine(freq + DETUNE_HZ, t_note)
            v3 = pure_sine(freq - DETUNE_HZ, t_note)
            chord_val += (v1 + v2 + v3) / 3.0
        chord_val /= len(data['chord_freqs'])

        signal[mask] += chord_val * env * CHORD_GAIN

    return signal

def generate_gymnopedie():
    """Generate complete Gymnopédie audio."""
    duration = CYCLE_DURATION

    print(f"  Generating melody layer...")
    melody = generate_melody(duration)

    print(f"  Generating bass layer...")
    bass = generate_bass(duration)

    print(f"  Generating chord layer...")
    chords = generate_chords(duration)

    # Mix all layers
    print(f"  Mixing layers...")
    mixed = melody + bass + chords
    mixed = soft_clip(mixed)

    # Apply reverb
    print(f"  Applying Schroeder reverb...")
    reverb = SchroederReverb(
        room_size=2.2,      # Large, open space
        damping=0.40,       # Moderate damping for clarity
        decay=0.85,         # Long tail for depth
        mix=0.45,           # Rich reverb
        predelay=0.030      # Spacious predelay
    )
    processed = reverb.process(mixed)

    # Final soft limiting
    processed = soft_clip(processed * 1.05, threshold=0.95)

    # Apply crossfade for seamless looping (100ms)
    crossfaded = apply_loop_crossfade(processed, crossfade_duration=0.1)

    # Normalize
    max_val = np.max(np.abs(crossfaded))
    if max_val > 0:
        crossfaded = crossfaded / max_val * 0.9

    return crossfaded.astype(np.float32)

# ============================================================================
# File Output
# ============================================================================

def apply_loop_crossfade(signal, crossfade_duration=0.1, sample_rate=SAMPLE_RATE):
    """
    Apply crossfade between end and start of audio for seamless looping.
    """
    crossfade_samples = int(crossfade_duration * sample_rate)

    if crossfade_samples * 2 >= len(signal):
        return signal

    result = signal.copy()

    # Equal-power crossfade curves
    t = np.linspace(0, np.pi / 2, crossfade_samples)
    fade_out = np.cos(t) ** 2
    fade_in = np.sin(t) ** 2

    end_section = signal[-crossfade_samples:]
    start_section = signal[:crossfade_samples]

    result[-crossfade_samples:] = end_section * fade_out + start_section * fade_in

    return result


def save_wav(signal, filename, sample_rate=SAMPLE_RATE):
    """Save signal as WAV file."""
    signal_int16 = (signal * 32767).astype(np.int16)
    wavfile.write(filename, sample_rate, signal_int16)

def main():
    print("=" * 60)
    print("Moonlit Gymnopédie Audio Generator for TsukiSound")
    print("=" * 60)
    print(f"Sample rate: {SAMPLE_RATE} Hz")
    print(f"BPM: 88 (beat = {BEAT:.3f}s)")
    print(f"Duration: {CYCLE_DURATION:.1f}s ({TOTAL_BARS} bars)")
    print(f"Output directory: {OUTPUT_DIR}")
    print()

    # Ensure output directory exists
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_DIR)
    os.makedirs(output_path, exist_ok=True)

    # Generate audio
    print("Generating Gymnopédie No.1...")
    signal = generate_gymnopedie()

    # Save WAV
    wav_path = os.path.join(output_path, "moonlit_gymnopedie.wav")
    save_wav(signal, wav_path)
    print(f"Saved: moonlit_gymnopedie.wav")

    print()
    print("=" * 60)
    print("WAV file generated successfully!")
    print()
    print("Next step: Convert to CAF format using:")
    print()
    print(f"  cd {output_path}")
    print("  afconvert -f caff -d LEF32@48000 -c 1 moonlit_gymnopedie.wav moonlit_gymnopedie.caf")
    print("=" * 60)

if __name__ == "__main__":
    main()
