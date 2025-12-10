#!/usr/bin/env python3
"""
Generate Acoustic Guitar Jupiter audio for TsukiSound

Generates Holst's Jupiter theme with acoustic guitar timbre:
- Warm, resonant plucked string sound
- Natural harmonics and body resonance
- Same tempo structure as original Jupiter

Based on generate_cathedral_stillness.py melody data

Output: WAV file (to be converted to CAF for iOS)
"""

import numpy as np
from scipy.io import wavfile
import os
from dataclasses import dataclass
from enum import Enum
from typing import List

from audio_utils import apply_silence_padding

# Constants
SAMPLE_RATE = 48000
OUTPUT_DIR = "../TsukiSound/Resources/Audio"

# =============================================================================
# Jupiter Timing (from JupiterTiming.swift)
# =============================================================================

BEAT_DURATION = 1.0  # 60 BPM = 1.0s per beat
BAR_DURATION = BEAT_DURATION * 3.0  # 3/4 time = 3 beats per bar
TOTAL_BARS = 25

# Tempo ratios per section
SECTION_0_TEMPO = 0.8
SECTION_1_TEMPO = 1.0
SECTION_2_TEMPO = 1.1
SECTION_3_4_TEMPO = 1.2
SECTION_5_TEMPO_START = 1.2
SECTION_5_TEMPO_END = 1.0
SECTION_5_TEMPO = (SECTION_5_TEMPO_START + SECTION_5_TEMPO_END) / 2

SECTION_BARS = [1, 5, 9, 13, 17, 21]
INTRO_REST_BEATS = 2.0
LEAD_IN_SILENCE = 0.5

# =============================================================================
# Timing Functions
# =============================================================================

def calculate_cycle_duration() -> float:
    sec0_musical = (SECTION_BARS[1] - SECTION_BARS[0]) * BAR_DURATION
    sec1_musical = (SECTION_BARS[2] - SECTION_BARS[1]) * BAR_DURATION
    sec2_musical = (SECTION_BARS[3] - SECTION_BARS[2]) * BAR_DURATION
    sec3_4_musical = (SECTION_BARS[5] - SECTION_BARS[3]) * BAR_DURATION
    sec5_musical = (TOTAL_BARS - SECTION_BARS[5] + 1) * BAR_DURATION

    sec0_real = sec0_musical / SECTION_0_TEMPO
    sec1_real = sec1_musical / SECTION_1_TEMPO
    sec2_real = sec2_musical / SECTION_2_TEMPO
    sec3_4_real = sec3_4_musical / SECTION_3_4_TEMPO
    sec5_real = sec5_musical / SECTION_5_TEMPO

    full_musical = TOTAL_BARS * BAR_DURATION
    tempo_extra = ((sec0_real - sec0_musical) + (sec2_real - sec2_musical) +
                   (sec3_4_real - sec3_4_musical) + (sec5_real - sec5_musical))

    intro_rest_real = (INTRO_REST_BEATS * BEAT_DURATION) / SECTION_0_TEMPO
    return full_musical + tempo_extra - intro_rest_real


def section5_real_to_musical(real_time_in_section: float, sec5_real_dur: float, sec5_musical_dur: float) -> float:
    if sec5_real_dur <= 0:
        return 0.0

    p = max(0.0, min(1.0, real_time_in_section / sec5_real_dur))
    t0, t1 = SECTION_5_TEMPO_START, SECTION_5_TEMPO_END
    avg_tempo = (t0 + t1) / 2
    unnormalized = t0 * p + (t1 - t0) * p * p / 2
    return (unnormalized / avg_tempo) * sec5_musical_dur


def convert_with_tempo_stretch(real_time: float) -> float:
    intro_rest_musical = INTRO_REST_BEATS * BEAT_DURATION

    sec0_start = intro_rest_musical
    sec0_end = (SECTION_BARS[1] - 1) * BAR_DURATION
    sec1_end = (SECTION_BARS[2] - 1) * BAR_DURATION
    sec2_end = (SECTION_BARS[3] - 1) * BAR_DURATION
    sec3_4_end = (SECTION_BARS[5] - 1) * BAR_DURATION
    sec5_end = TOTAL_BARS * BAR_DURATION

    sec0_musical_dur = sec0_end - sec0_start
    sec1_musical_dur = sec1_end - sec0_end
    sec2_musical_dur = sec2_end - sec1_end
    sec3_4_musical_dur = sec3_4_end - sec2_end
    sec5_musical_dur = sec5_end - sec3_4_end

    sec0_real_dur = sec0_musical_dur / SECTION_0_TEMPO
    sec1_real_dur = sec1_musical_dur / SECTION_1_TEMPO
    sec2_real_dur = sec2_musical_dur / SECTION_2_TEMPO
    sec3_4_real_dur = sec3_4_musical_dur / SECTION_3_4_TEMPO
    sec5_real_dur = sec5_musical_dur / SECTION_5_TEMPO

    sec0_real_end = sec0_real_dur
    sec1_real_end = sec0_real_end + sec1_real_dur
    sec2_real_end = sec1_real_end + sec2_real_dur
    sec3_4_real_end = sec2_real_end + sec3_4_real_dur

    if real_time < sec0_real_end:
        progress = real_time / sec0_real_dur if sec0_real_dur > 0 else 0
        return sec0_start + progress * sec0_musical_dur
    elif real_time < sec1_real_end:
        time_in_sec = real_time - sec0_real_end
        return sec0_end + time_in_sec
    elif real_time < sec2_real_end:
        time_in_sec = real_time - sec1_real_end
        progress = time_in_sec / sec2_real_dur if sec2_real_dur > 0 else 0
        return sec1_end + progress * sec2_musical_dur
    elif real_time < sec3_4_real_end:
        time_in_sec = real_time - sec2_real_end
        progress = time_in_sec / sec3_4_real_dur if sec3_4_real_dur > 0 else 0
        return sec2_end + progress * sec3_4_musical_dur
    else:
        time_in_sec = real_time - sec3_4_real_end
        musical_offset = section5_real_to_musical(time_in_sec, sec5_real_dur, sec5_musical_dur)
        return sec3_4_end + musical_offset


def real_to_musical_time(real_time: float, cycle_duration: float) -> float:
    adjusted_time = real_time - LEAD_IN_SILENCE
    if adjusted_time < 0:
        return INTRO_REST_BEATS * BEAT_DURATION + adjusted_time
    return convert_with_tempo_stretch(adjusted_time)


# =============================================================================
# Jupiter Melody Data
# =============================================================================

class JupiterBreath(Enum):
    NONE = 0.0
    SHORT = 0.08
    LONG = 0.15


class JupiterDuration(Enum):
    SIXTEENTH = 0.25
    EIGHTH = 0.5
    DOTTED_EIGHTH = 0.75
    QUARTER = 1.0
    HALF = 2.0
    DOTTED_HALF = 3.0


class JupiterPitch(Enum):
    C4 = 261.63
    D4 = 293.66
    E4 = 329.63
    F4 = 349.23
    G4 = 392.00
    A4 = 440.00
    B4 = 493.88
    C5 = 523.25
    D5 = 587.33
    E5 = 659.25
    F5 = 698.46
    G5 = 783.99
    A5 = 880.00
    B5 = 987.77
    C6 = 1046.50
    D6 = 1174.66
    E6 = 1318.51


@dataclass
class JupiterNote:
    freq: float
    bar: int
    beat: float
    dur_beats: float
    breath: JupiterBreath = JupiterBreath.NONE


def create_melody() -> List[JupiterNote]:
    return [
        JupiterNote(JupiterPitch.E4.value, 1, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G4.value, 1, 2.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.A4.value, 2, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.A4.value, 2, 1.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 2, 1.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B4.value, 2, 2.0, JupiterDuration.DOTTED_EIGHTH.value),
        JupiterNote(JupiterPitch.G4.value, 2, 2.75, JupiterDuration.SIXTEENTH.value),
        JupiterNote(JupiterPitch.C5.value, 3, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 3, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 3, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.B4.value, 3, 2.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.A4.value, 4, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B4.value, 4, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.A4.value, 4, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.G4.value, 4, 2.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.E4.value, 5, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.E4.value, 5, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G4.value, 5, 2.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.A4.value, 6, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.A4.value, 6, 1.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 6, 1.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B4.value, 6, 2.0, JupiterDuration.DOTTED_EIGHTH.value),
        JupiterNote(JupiterPitch.G4.value, 6, 2.75, JupiterDuration.SIXTEENTH.value),
        JupiterNote(JupiterPitch.C5.value, 7, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 7, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E5.value, 7, 1.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.E5.value, 7, 2.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.E5.value, 8, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 8, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 8, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.D5.value, 8, 2.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.C5.value, 9, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.G5.value, 9, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E5.value, 9, 2.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 10, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.D5.value, 10, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.C5.value, 10, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E5.value, 10, 2.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 11, 0.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.G4.value, 11, 1.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.G5.value, 11, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E5.value, 11, 2.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 12, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.D5.value, 12, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.E5.value, 12, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 12, 2.5, JupiterDuration.EIGHTH.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.A5.value, 13, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.A5.value, 13, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B5.value, 13, 2.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C6.value, 14, 0.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.B5.value, 14, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.A5.value, 14, 2.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.G5.value, 15, 0.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.C6.value, 15, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.E5.value, 15, 2.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.D5.value, 16, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 16, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 16, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.E5.value, 16, 2.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.G5.value, 17, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.E5.value, 17, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 17, 2.5, JupiterDuration.EIGHTH.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.A5.value, 18, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.A5.value, 18, 1.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C6.value, 18, 1.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B5.value, 18, 2.0, JupiterDuration.DOTTED_EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 18, 2.75, JupiterDuration.SIXTEENTH.value),
        JupiterNote(JupiterPitch.C6.value, 19, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D6.value, 19, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C6.value, 19, 1.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.B5.value, 19, 2.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.A5.value, 20, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B5.value, 20, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.A5.value, 20, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.G5.value, 20, 2.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.E5.value, 21, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.E5.value, 21, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 21, 2.5, JupiterDuration.EIGHTH.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.A5.value, 22, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.A5.value, 22, 1.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C6.value, 22, 1.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B5.value, 22, 2.0, JupiterDuration.DOTTED_EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 22, 2.75, JupiterDuration.SIXTEENTH.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.C6.value, 23, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D6.value, 23, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E6.value, 23, 1.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.E6.value, 23, 2.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.E6.value, 24, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D6.value, 24, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C6.value, 24, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.D6.value, 24, 2.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.C6.value, 25, 0.0, JupiterDuration.DOTTED_HALF.value),
    ]


# =============================================================================
# Acoustic Guitar Tone Synthesis
# =============================================================================

def acoustic_guitar_tone(freq, t, brightness=1.0):
    """Generate acoustic guitar plucked string tone."""
    signal = np.zeros_like(t)

    harmonics = [
        (1.0, 1.00),
        (2.0, 0.50),
        (3.0, 0.35),
        (4.0, 0.25),
        (5.0, 0.15),
        (6.0, 0.10),
        (7.0, 0.06),
        (8.0, 0.03),
    ]

    for harmonic, amp in harmonics:
        decay_rate = 1.0 + (harmonic - 1) * 0.4
        decay_env = np.exp(-t * decay_rate * 0.8)
        inharmonicity = 1.0 + 0.0003 * (harmonic ** 2)
        actual_freq = freq * harmonic * inharmonicity
        signal += amp * brightness * np.sin(2 * np.pi * actual_freq * t) * decay_env

    # Body resonance
    body_freq = min(freq * 0.5, 150)
    body_amp = 0.08 * brightness
    body_decay = np.exp(-t * 1.5)
    signal += body_amp * np.sin(2 * np.pi * body_freq * t) * body_decay

    # Pluck transient
    pluck_noise = np.random.randn(len(t)) * 0.025 * brightness
    pluck_env = np.exp(-t * 50)
    signal += pluck_noise * pluck_env

    return signal / 1.8


def acoustic_guitar_envelope(t, duration, attack=0.008, decay=2.5):
    """Acoustic guitar envelope: quick pluck, natural decay."""
    env = np.ones_like(t)

    attack_mask = t < attack
    if np.any(attack_mask):
        env[attack_mask] = (t[attack_mask] / attack) ** 0.7

    decay_mask = t >= attack
    if np.any(decay_mask):
        decay_t = t[decay_mask] - attack
        env[decay_mask] = np.exp(-decay_t / decay)

    end_fade = 0.06
    end_mask = t >= duration - end_fade
    if np.any(end_mask):
        fade_t = t[end_mask] - (duration - end_fade)
        fade_curve = 0.5 * (1.0 + np.cos(np.pi * fade_t / end_fade))
        env[end_mask] *= fade_curve

    return env


# =============================================================================
# Warm Reverb
# =============================================================================

class WarmReverb:
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
        prev = 0
        for i in range(len(signal)):
            if i >= delay:
                prev = output[i - delay] * (1 - self.damping) + prev * self.damping
                output[i] = signal[i] + prev * self.decay
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


# =============================================================================
# Signal Generation
# =============================================================================

def generate_melody(duration, cycle_duration):
    """Generate Jupiter melody with acoustic guitar tone."""
    num_samples = int(duration * SAMPLE_RATE)
    signal = np.zeros(num_samples, dtype=np.float64)
    t_global = np.linspace(0, duration, num_samples, endpoint=False)

    melody = create_melody()
    transpose_factor = 2.0 ** (-2.0 / 12.0)  # -2 semitones (same as original)

    for note in melody:
        # Calculate note timing
        note_musical_start = (note.bar - 1) * BAR_DURATION + note.beat * BEAT_DURATION
        note_musical_end = note_musical_start + note.dur_beats * BEAT_DURATION

        # Apply breath
        breath_dur = note.breath.value
        effective_end = note_musical_end - breath_dur

        # Find real time range for this note
        for i, real_time in enumerate(t_global):
            musical_time = real_to_musical_time(real_time, cycle_duration)

            if note_musical_start <= musical_time < effective_end:
                t_in_note = musical_time - note_musical_start
                note_dur = effective_end - note_musical_start

                # Acoustic guitar tone
                freq = note.freq * transpose_factor
                t_local = np.array([t_in_note])
                tone_val = acoustic_guitar_tone(freq, t_local, brightness=1.0)[0]

                # Envelope
                env_val = acoustic_guitar_envelope(t_local, note_dur, attack=0.008, decay=2.5)[0]

                # Gain (reduce high frequencies slightly)
                gain = 0.35
                if freq > 600:
                    gain *= 0.85

                signal[i] += tone_val * env_val * gain

    return signal


def soft_clip(signal, threshold=0.9):
    return np.tanh(signal / threshold) * threshold


def generate_acoustic_jupiter():
    """Generate complete acoustic guitar Jupiter."""
    cycle_duration = calculate_cycle_duration()
    duration = cycle_duration + LEAD_IN_SILENCE + 2.0  # Extra for reverb tail

    print(f"  Cycle duration: {cycle_duration:.1f}s")
    print(f"  Total duration: {duration:.1f}s")

    num_samples = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, num_samples, endpoint=False)

    print("  Generating melody...")
    melody = generate_melody(duration, cycle_duration)

    print("  Applying soft clip...")
    processed = soft_clip(melody)

    print("  Applying warm reverb...")
    reverb = WarmReverb(
        room_size=2.0,
        damping=0.50,
        decay=0.58,
        mix=0.32,
        predelay=0.022
    )
    processed = reverb.process(processed)

    processed = soft_clip(processed * 1.05, threshold=0.95)

    print("  Applying silence padding...")
    padded = apply_silence_padding(processed, fade_in_duration=0.5, fade_out_duration=2.5)

    max_val = np.max(np.abs(padded))
    if max_val > 0:
        padded = padded / max_val * 0.9

    return padded.astype(np.float32)


# =============================================================================
# File Output
# =============================================================================

def save_wav(signal, filename, sample_rate=SAMPLE_RATE):
    signal_int16 = (signal * 32767).astype(np.int16)
    wavfile.write(filename, sample_rate, signal_int16)


def main():
    print("=" * 60)
    print("Acoustic Guitar Jupiter Audio Generator for TsukiSound")
    print("=" * 60)
    print(f"Sample rate: {SAMPLE_RATE} Hz")
    print(f"Output directory: {OUTPUT_DIR}")
    print()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_DIR)
    os.makedirs(output_path, exist_ok=True)

    print("Generating Acoustic Guitar Jupiter...")
    signal = generate_acoustic_jupiter()

    wav_path = os.path.join(output_path, "acoustic_jupiter.wav")
    save_wav(signal, wav_path)
    print(f"Saved: acoustic_jupiter.wav")

    print()
    print("=" * 60)
    print("WAV file generated successfully!")
    print()
    print("Next step: Convert to CAF format using:")
    print()
    print(f"  cd {output_path}")
    print("  afconvert -f caff -d LEF32@48000 -c 1 acoustic_jupiter.wav acoustic_jupiter.caf")
    print("=" * 60)


if __name__ == "__main__":
    main()
