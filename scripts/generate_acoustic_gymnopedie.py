#!/usr/bin/env python3
"""
Generate Acoustic Guitar Gymnopédie audio for TsukiSound

Generates Gymnopédie No.1 with acoustic guitar timbre:
- Warm, resonant plucked string sound
- Natural harmonics and body resonance
- 88 BPM, 3/4 time signature, D Major

Based on generate_moonlit_gymnopedie.py melody/chord data

Output: WAV file (to be converted to CAF for iOS)
"""

import numpy as np
from scipy.io import wavfile
import os

from audio_utils import apply_silence_padding

# Constants
SAMPLE_RATE = 48000
OUTPUT_DIR = "../TsukiSound/Resources/Audio"

# Timing Constants (88 BPM - same as original Gymnopédie)
BEAT = 0.682  # 1 beat = 0.682 seconds
BAR_DURATION = BEAT * 3  # 1 bar = 3 beats (3/4 time)
TOTAL_BARS = 41  # Bar 39 + 2 bars for reverb tail
CYCLE_DURATION = TOTAL_BARS * BAR_DURATION

# Structure Constants
CLIMAX_BAR = 39

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
# Acoustic Guitar Sound Parameters
# ============================================================================

MELODY_ATTACK = 0.008   # Quick pluck attack
MELODY_DECAY = 3.0      # Resonant sustain
MELODY_GAIN = 0.30

BASS_ATTACK = 0.012     # Slightly softer bass attack
BASS_DECAY = 2.5
BASS_GAIN = 0.22

CHORD_ATTACK = 0.006    # Quick strum
CHORD_DECAY = 2.0
CHORD_GAIN = 0.08

# ============================================================================
# Acoustic Guitar Tone Synthesis
# ============================================================================

def acoustic_guitar_tone(freq, t, brightness=1.0):
    """
    Generate acoustic guitar plucked string tone.

    Acoustic guitar characteristics:
    - Strong fundamental with rich harmonics
    - Odd and even harmonics (unlike clarinet)
    - Higher harmonics decay faster (string damping)
    - Slight inharmonicity in higher partials
    - Body resonance warmth
    """
    signal = np.zeros_like(t)

    # Karplus-Strong inspired harmonic series for plucked string
    # Guitar has rich harmonic content that decays naturally
    harmonics = [
        (1.0, 1.00),      # Fundamental
        (2.0, 0.50),      # Octave (strong on guitar)
        (3.0, 0.35),      # Fifth above octave
        (4.0, 0.25),      # 2 octaves
        (5.0, 0.15),      # Major 3rd
        (6.0, 0.10),      #
        (7.0, 0.06),      #
        (8.0, 0.03),      # High shimmer
    ]

    for harmonic, amp in harmonics:
        # Higher harmonics decay much faster (string physics)
        decay_rate = 1.0 + (harmonic - 1) * 0.4
        decay_env = np.exp(-t * decay_rate * 0.8)

        # Slight inharmonicity for realism (strings aren't perfect)
        inharmonicity = 1.0 + 0.0003 * (harmonic ** 2)
        actual_freq = freq * harmonic * inharmonicity

        signal += amp * brightness * np.sin(2 * np.pi * actual_freq * t) * decay_env

    # Add body resonance (low frequency warmth)
    body_freq = min(freq * 0.5, 150)  # Body resonates at low frequencies
    body_amp = 0.08 * brightness
    body_decay = np.exp(-t * 1.5)
    signal += body_amp * np.sin(2 * np.pi * body_freq * t) * body_decay

    # Add initial pluck transient (finger/pick noise)
    pluck_noise = np.random.randn(len(t)) * 0.03 * brightness
    pluck_env = np.exp(-t * 50)  # Very fast decay
    signal += pluck_noise * pluck_env

    # Normalize
    return signal / 1.8

def acoustic_guitar_envelope(t, duration, attack=MELODY_ATTACK, decay=MELODY_DECAY):
    """
    Acoustic guitar envelope: quick pluck, natural decay.
    """
    env = np.ones_like(t)

    # Quick attack (pluck)
    attack_mask = t < attack
    if np.any(attack_mask):
        # Slightly curved attack
        env[attack_mask] = (t[attack_mask] / attack) ** 0.7

    # Natural exponential decay
    decay_mask = t >= attack
    if np.any(decay_mask):
        decay_t = t[decay_mask] - attack
        env[decay_mask] = np.exp(-decay_t / decay)

    # Smooth end
    end_fade = 0.06
    end_mask = t >= duration - end_fade
    if np.any(end_mask):
        fade_t = t[end_mask] - (duration - end_fade)
        fade_curve = 0.5 * (1.0 + np.cos(np.pi * fade_t / end_fade))
        env[end_mask] *= fade_curve

    return env

# ============================================================================
# Melody Note Data (from GymnopedieMelodyData)
# ============================================================================

class MelodyNote:
    def __init__(self, freq, start_bar, start_beat, dur_beats, custom_gain=None, fade_out=False):
        self.freq = freq
        self.start_bar = start_bar
        self.start_beat = start_beat
        self.dur_beats = dur_beats
        self.custom_gain = custom_gain
        self.fade_out = fade_out

def get_melody_notes():
    """All melody notes for Gymnopédie No.1"""
    notes = []

    # Section G1 - Bars 1-12 (Intro + Theme A)
    notes.append(MelodyNote(Fs5, 5, 1, 1))
    notes.append(MelodyNote(A5, 5, 2, 1))
    notes.append(MelodyNote(G5, 6, 0, 1))
    notes.append(MelodyNote(Fs5, 6, 1, 1))
    notes.append(MelodyNote(Cs5, 6, 2, 1))
    notes.append(MelodyNote(B4, 7, 0, 1))
    notes.append(MelodyNote(Cs5, 7, 1, 1))
    notes.append(MelodyNote(D5, 7, 2, 1))
    notes.append(MelodyNote(A4, 8, 0, 3))
    notes.append(MelodyNote(Fs4, 9, 0, 12, fade_out=True))

    # Section G2 - Bars 13-21
    notes.append(MelodyNote(Fs5, 13, 1, 1))
    notes.append(MelodyNote(A5, 13, 2, 1))
    notes.append(MelodyNote(G5, 14, 0, 1))
    notes.append(MelodyNote(Fs5, 14, 1, 1))
    notes.append(MelodyNote(Cs5, 14, 2, 1))
    notes.append(MelodyNote(B4, 15, 0, 1))
    notes.append(MelodyNote(Cs5, 15, 1, 1))
    notes.append(MelodyNote(D5, 15, 2, 1))
    notes.append(MelodyNote(A4, 16, 0, 3))
    notes.append(MelodyNote(Cs5, 17, 0, 3))
    notes.append(MelodyNote(Fs5, 18, 0, 3))
    notes.append(MelodyNote(E5, 19, 0, 9, fade_out=True))

    # Section G3 - Bars 22-26
    notes.append(MelodyNote(A4, 22, 0, 1))
    notes.append(MelodyNote(B4, 22, 1, 1))
    notes.append(MelodyNote(C5, 22, 2, 1))
    notes.append(MelodyNote(E5, 23, 0, 1))
    notes.append(MelodyNote(D5, 23, 1, 1))
    notes.append(MelodyNote(B4, 23, 2, 1))
    notes.append(MelodyNote(D5, 24, 0, 1))
    notes.append(MelodyNote(C5, 24, 1, 1))
    notes.append(MelodyNote(B4, 24, 2, 1))
    notes.append(MelodyNote(E4, 24, 1, 2))
    notes.append(MelodyNote(D5, 25, 0, 5))
    notes.append(MelodyNote(D4, 25, 1, 2))
    notes.append(MelodyNote(D5, 26, 2, 1))
    notes.append(MelodyNote(D4, 26, 1, 2))

    # Section G4 - Bars 27-31
    notes.append(MelodyNote(E5, 27, 0, 1))
    notes.append(MelodyNote(F5, 27, 1, 1))
    notes.append(MelodyNote(G5, 27, 2, 1))
    notes.append(MelodyNote(A5, 28, 0, 1))
    notes.append(MelodyNote(C5, 28, 1, 1))
    notes.append(MelodyNote(D5, 28, 2, 1))
    notes.append(MelodyNote(E5, 29, 0, 1))
    notes.append(MelodyNote(D5, 29, 1, 1))
    notes.append(MelodyNote(B4, 29, 2, 1))
    notes.append(MelodyNote(E4, 29, 1, 2))
    notes.append(MelodyNote(D5, 30, 0, 5))
    notes.append(MelodyNote(D4, 30, 1, 2))
    notes.append(MelodyNote(D5, 31, 2, 1))
    notes.append(MelodyNote(D4, 31, 1, 2))

    # Section G5 - Bars 32-39
    notes.append(MelodyNote(G5, 32, 0, 3))
    notes.append(MelodyNote(Fs5, 33, 0, 3))
    notes.append(MelodyNote(B4, 34, 0, 1))
    notes.append(MelodyNote(A4, 34, 1, 1))
    notes.append(MelodyNote(B4, 34, 2, 1))
    notes.append(MelodyNote(Cs5, 35, 0, 1))
    notes.append(MelodyNote(D5, 35, 1, 1))
    notes.append(MelodyNote(E5, 35, 2, 1))
    notes.append(MelodyNote(Cs5, 36, 0, 1))
    notes.append(MelodyNote(D5, 36, 1, 1))
    notes.append(MelodyNote(E5, 36, 2, 1))
    notes.append(MelodyNote(Fs4, 37, 0, 3))
    notes.append(MelodyNote(D4, 37, 1, 1))
    notes.append(MelodyNote(G4, 37, 2, 1))

    # Bar 38-39: Final climax
    notes.append(MelodyNote(A3, 38, 0.00, 3.5, custom_gain=0.18))
    notes.append(MelodyNote(E4, 38, 0.12, 3.3, custom_gain=0.14))
    notes.append(MelodyNote(A4, 38, 0.24, 3.1, custom_gain=0.12))
    notes.append(MelodyNote(D3, 39, 0.00, 6.0, custom_gain=0.20))
    notes.append(MelodyNote(D4, 39, 0.12, 5.8, custom_gain=0.14))
    notes.append(MelodyNote(A4, 39, 0.21, 5.5, custom_gain=0.16))
    notes.append(MelodyNote(D5, 39, 0.30, 5.2, custom_gain=0.12))

    return notes

def get_bass_chord_data():
    """Bass & Chord patterns per bar."""
    data = []

    for bar in range(1, TOTAL_BARS + 1):
        if bar in [9, 10, 11, 12, 19, 20, 21]:
            bass_freq = E3
            chord_freqs = [B3, D4]
        elif bar % 2 == 1:
            bass_freq = G3
            chord_freqs = [B3, D4]
        else:
            bass_freq = D3
            chord_freqs = [A3, Cs4]

        data.append({
            'bar': bar,
            'bass_freq': bass_freq,
            'chord_freqs': chord_freqs
        })

    return data

# ============================================================================
# Reverb (warm room sound for acoustic guitar)
# ============================================================================

class WarmReverb:
    """Warm room reverb for acoustic guitar."""

    def __init__(self, room_size=1.8, damping=0.55, decay=0.60, mix=0.30, predelay=0.020):
        self.room_size = room_size
        self.damping = damping
        self.decay = decay
        self.mix = mix
        self.predelay = predelay

        base_delays = [1557, 1617, 1491, 1422]
        self.comb_delays = [int(d * room_size) for d in base_delays]
        self.allpass_delays = [225, 556, 441, 341]

    def process(self, signal):
        predelay_samples = int(self.predelay * SAMPLE_RATE)
        delayed = np.concatenate([np.zeros(predelay_samples), signal])

        comb_out = np.zeros(len(delayed))
        for delay in self.comb_delays:
            comb_out += self._comb_filter(delayed, delay)
        comb_out /= len(self.comb_delays)

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
    """Generate melody layer with acoustic guitar tone."""
    num_samples = int(duration * SAMPLE_RATE)
    signal = np.zeros(num_samples, dtype=np.float64)
    t_global = np.linspace(0, duration, num_samples, endpoint=False)

    melody_notes = get_melody_notes()

    for note in melody_notes:
        note_start = (note.start_bar - 1) * BAR_DURATION + note.start_beat * BEAT
        note_dur = note.dur_beats * BEAT
        note_end = note_start + note_dur

        mask = (t_global >= note_start) & (t_global < note_end)
        if not np.any(mask):
            continue

        t_local = t_global[mask] - note_start

        # Determine decay
        is_climax = note.start_bar >= CLIMAX_BAR
        effective_decay = MELODY_DECAY * 1.5 if is_climax else MELODY_DECAY

        # Determine gain
        if note.custom_gain is not None:
            effective_gain = note.custom_gain
        else:
            effective_gain = MELODY_GAIN
            if note.freq >= 600.0:
                reduction_ratio = min(1.0, (note.freq - 600.0) / (E6 - 600.0))
                effective_gain *= 1.0 - reduction_ratio * 0.25

        # Acoustic guitar tone
        tone = acoustic_guitar_tone(note.freq, t_local)

        # Envelope
        env = acoustic_guitar_envelope(t_local, note_dur, MELODY_ATTACK, effective_decay)

        # Fade out for long sustain notes
        if note.fade_out:
            progress = t_local / note_dur
            fade_mask = progress > 0.5
            if np.any(fade_mask):
                fade_progress = (progress[fade_mask] - 0.5) * 2.0
                fade_multiplier = 0.3 + 0.7 * (1.0 + np.cos(fade_progress * np.pi)) / 2.0
                env[fade_mask] *= fade_multiplier

        signal[mask] += tone * env * effective_gain

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

        mask = (t_global >= note_start) & (t_global < note_start + note_dur)
        if not np.any(mask):
            continue

        t_local = t_global[mask] - note_start

        # Acoustic guitar bass (warmer, less bright)
        tone = acoustic_guitar_tone(data['bass_freq'], t_local, brightness=0.7)
        env = acoustic_guitar_envelope(t_local, note_dur, BASS_ATTACK, BASS_DECAY)

        signal[mask] += tone * env * BASS_GAIN

    return signal

def generate_chords(duration):
    """Generate chord layer."""
    num_samples = int(duration * SAMPLE_RATE)
    signal = np.zeros(num_samples, dtype=np.float64)
    t_global = np.linspace(0, duration, num_samples, endpoint=False)

    bass_chord_data = get_bass_chord_data()

    for data in bass_chord_data:
        chord_start = (data['bar'] - 1) * BAR_DURATION + BEAT
        chord_dur = 2 * BEAT

        mask = (t_global >= chord_start) & (t_global < chord_start + chord_dur)
        if not np.any(mask):
            continue

        t_local = t_global[mask] - chord_start

        # Strummed chord (slight delay between notes for realism)
        chord_val = np.zeros(len(t_local))
        for i, freq in enumerate(data['chord_freqs']):
            # Slight strum delay
            strum_delay = i * 0.015
            t_strummed = np.maximum(t_local - strum_delay, 0)
            chord_val += acoustic_guitar_tone(freq, t_strummed, brightness=0.8)
        chord_val /= len(data['chord_freqs'])

        env = acoustic_guitar_envelope(t_local, chord_dur, CHORD_ATTACK, CHORD_DECAY)

        signal[mask] += chord_val * env * CHORD_GAIN

    return signal

def soft_clip(signal, threshold=0.9):
    """Soft clip to prevent harsh distortion."""
    return np.tanh(signal / threshold) * threshold

def generate_acoustic_gymnopedie():
    """Generate complete acoustic guitar Gymnopédie."""
    duration = CYCLE_DURATION

    print("  Generating melody layer...")
    melody = generate_melody(duration)

    print("  Generating bass layer...")
    bass = generate_bass(duration)

    print("  Generating chord layer...")
    chords = generate_chords(duration)

    print("  Mixing layers...")
    mixed = melody + bass + chords
    mixed = soft_clip(mixed)

    print("  Applying warm reverb...")
    reverb = WarmReverb(
        room_size=1.8,
        damping=0.50,
        decay=0.55,
        mix=0.28,
        predelay=0.018
    )
    processed = reverb.process(mixed)

    # Final soft limiting
    processed = soft_clip(processed * 1.05, threshold=0.95)

    # Apply silence padding for seamless looping
    print("  Applying silence padding (fade-in: 0.8s, fade-out: 3.0s)...")
    padded = apply_silence_padding(processed, fade_in_duration=0.8, fade_out_duration=3.0)

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
    print("Acoustic Guitar Gymnopédie Audio Generator for TsukiSound")
    print("=" * 60)
    print(f"Sample rate: {SAMPLE_RATE} Hz")
    print(f"BPM: 88 (beat = {BEAT:.3f}s)")
    print(f"Duration: {CYCLE_DURATION:.1f}s ({TOTAL_BARS} bars)")
    print(f"Output directory: {OUTPUT_DIR}")
    print()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_DIR)
    os.makedirs(output_path, exist_ok=True)

    print("Generating Acoustic Guitar Gymnopédie...")
    signal = generate_acoustic_gymnopedie()

    wav_path = os.path.join(output_path, "acoustic_gymnopedie.wav")
    save_wav(signal, wav_path)
    print(f"Saved: acoustic_gymnopedie.wav")

    print()
    print("=" * 60)
    print("WAV file generated successfully!")
    print()
    print("Next step: Convert to CAF format using:")
    print()
    print(f"  cd {output_path}")
    print("  afconvert -f caff -d LEF32@48000 -c 1 acoustic_gymnopedie.wav acoustic_gymnopedie.caf")
    print("=" * 60)

if __name__ == "__main__":
    main()
