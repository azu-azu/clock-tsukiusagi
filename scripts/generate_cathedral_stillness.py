#!/usr/bin/env python3
"""
Generate Cathedral Stillness audio for TsukiSound

Generates the complete cathedral stillness sound including:
- Organ drone (C3 + G3 fifth chord with slow LFO breathing)
- Jupiter melody (Holst's Jupiter theme in C Major)
- Tree chime accents (metallic shimmer)
- Schroeder reverb

The output is a single audio file that can be looped seamlessly.

Based on existing Swift implementations:
- CathedralStillnessSignal.swift (organ drone)
- JupiterSignal.swift (melody)
- JupiterMelodyData.swift (note data)
- JupiterTiming.swift (tempo/section control)
"""

import numpy as np
from scipy.io import wavfile
from scipy import signal as scipy_signal
import os
from dataclasses import dataclass
from enum import Enum
from typing import List, Tuple, Optional

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
SECTION_0_TEMPO = 0.8   # Slower, a cappella style
SECTION_1_TEMPO = 1.0   # Normal
SECTION_2_TEMPO = 1.1   # Slightly faster
SECTION_3_5_TEMPO = 1.2 # Fast

# Section boundaries (bar numbers, 1-indexed)
SECTION_BARS = [1, 5, 9, 13, 17, 21]

# Intro rest (2 beats) - skipped on first cycle
INTRO_REST_BEATS = 2.0


def calculate_cycle_duration() -> Tuple[float, float]:
    """Calculate first and normal cycle durations with tempo stretch."""
    # Musical durations (in beats)
    sec0_musical = (SECTION_BARS[1] - SECTION_BARS[0]) * BAR_DURATION  # 12
    sec1_musical = (SECTION_BARS[2] - SECTION_BARS[1]) * BAR_DURATION  # 12
    sec2_musical = (SECTION_BARS[3] - SECTION_BARS[2]) * BAR_DURATION  # 12
    sec3_5_musical = (TOTAL_BARS - SECTION_BARS[3] + 1) * BAR_DURATION  # 39

    # Real durations with tempo stretch
    sec0_real = sec0_musical / SECTION_0_TEMPO
    sec1_real = sec1_musical / SECTION_1_TEMPO
    sec2_real = sec2_musical / SECTION_2_TEMPO
    sec3_5_real = sec3_5_musical / SECTION_3_5_TEMPO

    full_musical = TOTAL_BARS * BAR_DURATION  # 75s

    tempo_extra = (sec0_real - sec0_musical) + (sec2_real - sec2_musical) + (sec3_5_real - sec3_5_musical)

    intro_rest_musical = INTRO_REST_BEATS * BEAT_DURATION

    first_cycle = full_musical - intro_rest_musical + tempo_extra
    normal_cycle = full_musical + tempo_extra

    return first_cycle, normal_cycle


def real_to_musical_time(real_time: float, first_cycle: float, normal_cycle: float) -> float:
    """Convert real time to musical time (accounting for tempo stretch and intro skip)."""
    if real_time < first_cycle:
        return convert_with_tempo_stretch(real_time, intro_skipped=True)
    else:
        time_after_first = real_time - first_cycle
        cycle_time = time_after_first % normal_cycle
        return convert_with_tempo_stretch(cycle_time, intro_skipped=False)


def convert_with_tempo_stretch(real_time: float, intro_skipped: bool) -> float:
    """Convert real time within a cycle to musical time."""
    intro_rest_musical = INTRO_REST_BEATS * BEAT_DURATION

    # Musical boundaries
    sec0_start = intro_rest_musical if intro_skipped else 0.0
    sec0_end = (SECTION_BARS[1] - 1) * BAR_DURATION  # 12.0
    sec1_end = (SECTION_BARS[2] - 1) * BAR_DURATION  # 24.0
    sec2_end = (SECTION_BARS[3] - 1) * BAR_DURATION  # 36.0
    sec3_5_end = TOTAL_BARS * BAR_DURATION           # 75.0

    # Musical durations
    sec0_musical_dur = sec0_end - sec0_start
    sec1_musical_dur = sec1_end - sec0_end
    sec2_musical_dur = sec2_end - sec1_end
    sec3_5_musical_dur = sec3_5_end - sec2_end

    # Real durations
    sec0_real_dur = sec0_musical_dur / SECTION_0_TEMPO
    sec1_real_dur = sec1_musical_dur / SECTION_1_TEMPO
    sec2_real_dur = sec2_musical_dur / SECTION_2_TEMPO
    sec3_5_real_dur = sec3_5_musical_dur / SECTION_3_5_TEMPO

    # Cumulative real time boundaries
    sec0_real_end = sec0_real_dur
    sec1_real_end = sec0_real_end + sec1_real_dur
    sec2_real_end = sec1_real_end + sec2_real_dur
    sec3_5_real_end = sec2_real_end + sec3_5_real_dur

    if real_time < sec0_real_end:
        progress = real_time / sec0_real_dur if sec0_real_dur > 0 else 0
        return sec0_start + progress * sec0_musical_dur
    elif real_time < sec1_real_end:
        time_in_sec = real_time - sec0_real_end
        return sec0_end + time_in_sec  # 1:1 for section 1
    elif real_time < sec2_real_end:
        time_in_sec = real_time - sec1_real_end
        progress = time_in_sec / sec2_real_dur if sec2_real_dur > 0 else 0
        return sec1_end + progress * sec2_musical_dur
    elif real_time < sec3_5_real_end:
        time_in_sec = real_time - sec2_real_end
        progress = time_in_sec / sec3_5_real_dur if sec3_5_real_dur > 0 else 0
        return sec2_end + progress * sec3_5_musical_dur
    else:
        return sec3_5_end


def get_section_at_musical_time(musical_time: float) -> int:
    """Get section number (0-5) at given musical time."""
    bar = int(musical_time / BAR_DURATION) + 1
    bar = max(1, min(bar, TOTAL_BARS))

    for i in range(len(SECTION_BARS) - 1, -1, -1):
        if bar >= SECTION_BARS[i]:
            return i
    return 0


def get_section_progress(musical_time: float, section: int) -> float:
    """Get progress within a section (0.0 to 1.0)."""
    sec_start = (SECTION_BARS[section] - 1) * BAR_DURATION
    if section < len(SECTION_BARS) - 1:
        sec_end = (SECTION_BARS[section + 1] - 1) * BAR_DURATION
    else:
        sec_end = TOTAL_BARS * BAR_DURATION

    sec_dur = sec_end - sec_start
    time_in_sec = musical_time - sec_start
    return max(0.0, min(1.0, time_in_sec / sec_dur))


# =============================================================================
# Jupiter Melody Data (from JupiterMelodyData.swift)
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
    # Low octave
    C4 = 261.63
    D4 = 293.66
    E4 = 329.63
    F4 = 349.23
    G4 = 392.00
    A4 = 440.00
    B4 = 493.88
    # High octave
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
    """Create the Jupiter melody data."""
    return [
        # Bar 1: Rest(2 beats) + E-G (eighth + eighth)
        JupiterNote(JupiterPitch.E4.value, 1, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G4.value, 1, 2.5, JupiterDuration.EIGHTH.value),

        # Bar 2: A(quarter) A-C-B.-G
        JupiterNote(JupiterPitch.A4.value, 2, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.A4.value, 2, 1.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 2, 1.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B4.value, 2, 2.0, JupiterDuration.DOTTED_EIGHTH.value),
        JupiterNote(JupiterPitch.G4.value, 2, 2.75, JupiterDuration.SIXTEENTH.value),

        # Bar 3: C-D-C B
        JupiterNote(JupiterPitch.C5.value, 3, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 3, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 3, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.B4.value, 3, 2.0, JupiterDuration.QUARTER.value),

        # Bar 4: A-B-A G
        JupiterNote(JupiterPitch.A4.value, 4, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B4.value, 4, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.A4.value, 4, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.G4.value, 4, 2.0, JupiterDuration.QUARTER.value),

        # Bar 5: E(half) E-G
        JupiterNote(JupiterPitch.E4.value, 5, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.E4.value, 5, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G4.value, 5, 2.5, JupiterDuration.EIGHTH.value),

        # Bar 6: A A-C-B.-G
        JupiterNote(JupiterPitch.A4.value, 6, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.A4.value, 6, 1.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 6, 1.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B4.value, 6, 2.0, JupiterDuration.DOTTED_EIGHTH.value),
        JupiterNote(JupiterPitch.G4.value, 6, 2.75, JupiterDuration.SIXTEENTH.value),

        # Bar 7: C-D E E
        JupiterNote(JupiterPitch.C5.value, 7, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 7, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E5.value, 7, 1.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.E5.value, 7, 2.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),

        # Bar 8: E-D-C D
        JupiterNote(JupiterPitch.E5.value, 8, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 8, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 8, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.D5.value, 8, 2.0, JupiterDuration.QUARTER.value),

        # Bar 9: C(half) G-E
        JupiterNote(JupiterPitch.C5.value, 9, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.G5.value, 9, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E5.value, 9, 2.5, JupiterDuration.EIGHTH.value),

        # Bar 10: D D C-E
        JupiterNote(JupiterPitch.D5.value, 10, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.D5.value, 10, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.C5.value, 10, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E5.value, 10, 2.5, JupiterDuration.EIGHTH.value),

        # Bar 11: D G G-E
        JupiterNote(JupiterPitch.D5.value, 11, 0.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.G4.value, 11, 1.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.G5.value, 11, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E5.value, 11, 2.5, JupiterDuration.EIGHTH.value),

        # Bar 12: D D E-G
        JupiterNote(JupiterPitch.D5.value, 12, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.D5.value, 12, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.E5.value, 12, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 12, 2.5, JupiterDuration.EIGHTH.value, JupiterBreath.SHORT),

        # Bar 13: A(half) A-B
        JupiterNote(JupiterPitch.A5.value, 13, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.A5.value, 13, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B5.value, 13, 2.5, JupiterDuration.EIGHTH.value),

        # Bar 14: C B A
        JupiterNote(JupiterPitch.C6.value, 14, 0.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.B5.value, 14, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.A5.value, 14, 2.0, JupiterDuration.QUARTER.value),

        # Bar 15: G C E
        JupiterNote(JupiterPitch.G5.value, 15, 0.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.C6.value, 15, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.E5.value, 15, 2.0, JupiterDuration.QUARTER.value),

        # Bar 16: D-C D E
        JupiterNote(JupiterPitch.D5.value, 16, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C5.value, 16, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D5.value, 16, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.E5.value, 16, 2.0, JupiterDuration.QUARTER.value),

        # Bar 17: G(half) E-G
        JupiterNote(JupiterPitch.G5.value, 17, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.E5.value, 17, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 17, 2.5, JupiterDuration.EIGHTH.value, JupiterBreath.SHORT),

        # Bar 18: A A-C-B.-G
        JupiterNote(JupiterPitch.A5.value, 18, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.A5.value, 18, 1.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C6.value, 18, 1.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B5.value, 18, 2.0, JupiterDuration.DOTTED_EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 18, 2.75, JupiterDuration.SIXTEENTH.value),

        # Bar 19: C-D C B
        JupiterNote(JupiterPitch.C6.value, 19, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D6.value, 19, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C6.value, 19, 1.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.B5.value, 19, 2.0, JupiterDuration.QUARTER.value),

        # Bar 20: A-B-A G
        JupiterNote(JupiterPitch.A5.value, 20, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B5.value, 20, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.A5.value, 20, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.G5.value, 20, 2.0, JupiterDuration.QUARTER.value),

        # Bar 21: E(half) E-G
        JupiterNote(JupiterPitch.E5.value, 21, 0.0, JupiterDuration.HALF.value, JupiterBreath.LONG),
        JupiterNote(JupiterPitch.E5.value, 21, 2.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 21, 2.5, JupiterDuration.EIGHTH.value, JupiterBreath.SHORT),

        # Bar 22: A A-C-B.-G
        JupiterNote(JupiterPitch.A5.value, 22, 0.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.A5.value, 22, 1.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C6.value, 22, 1.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.B5.value, 22, 2.0, JupiterDuration.DOTTED_EIGHTH.value),
        JupiterNote(JupiterPitch.G5.value, 22, 2.75, JupiterDuration.SIXTEENTH.value, JupiterBreath.SHORT),

        # Bar 23: C-D E E
        JupiterNote(JupiterPitch.C6.value, 23, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D6.value, 23, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.E6.value, 23, 1.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),
        JupiterNote(JupiterPitch.E6.value, 23, 2.0, JupiterDuration.QUARTER.value, JupiterBreath.SHORT),

        # Bar 24: E-D-C D
        JupiterNote(JupiterPitch.E6.value, 24, 0.0, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.D6.value, 24, 0.5, JupiterDuration.EIGHTH.value),
        JupiterNote(JupiterPitch.C6.value, 24, 1.0, JupiterDuration.QUARTER.value),
        JupiterNote(JupiterPitch.D6.value, 24, 2.0, JupiterDuration.QUARTER.value),

        # Bar 25: C (dotted half = ending)
        JupiterNote(JupiterPitch.C6.value, 25, 0.0, JupiterDuration.DOTTED_HALF.value),
    ]


# =============================================================================
# Sound Generators
# =============================================================================

def generate_organ_drone(t: np.ndarray, first_cycle: float, normal_cycle: float) -> np.ndarray:
    """Generate organ drone (CathedralStillnessSignal)."""
    root_freq = 130.81  # C3
    fifth_freq = 196.00  # G3
    lfo_freq = 0.02     # 50s cycle

    section_0_volume = 0.3
    section_2_volume = 1.0

    harmonics = [1.0, 2.0, 3.0, 4.0]
    amps = [0.9, 0.4, 0.25, 0.15]

    output = np.zeros_like(t)

    for i, time in enumerate(t):
        musical_time = real_to_musical_time(time, first_cycle, normal_cycle)
        section = get_section_at_musical_time(musical_time)
        section_progress = get_section_progress(musical_time, section)

        # LFO breathing (0.4 - 0.8 range)
        lfo_value = 0.6 + 0.2 * np.sin(2.0 * np.pi * lfo_freq * time)

        # Section volume
        if section == 0:
            volume = section_0_volume
        elif section == 1:
            volume = section_0_volume + (section_2_volume - section_0_volume) * section_progress
        else:
            volume = section_2_volume

        value = 0.0

        # Root note harmonics
        for h, a in zip(harmonics, amps):
            freq = root_freq * h
            value += a * 0.5 * np.sin(2.0 * np.pi * freq * time)

        # Fifth note harmonics (slightly quieter)
        for h, a in zip(harmonics, amps):
            freq = fifth_freq * h
            value += a * 0.35 * np.sin(2.0 * np.pi * freq * time)

        output[i] = value * lfo_value * 0.12 * volume

    return output


def generate_jupiter_melody(t: np.ndarray, first_cycle: float, normal_cycle: float) -> np.ndarray:
    """Generate Jupiter melody (JupiterSignal)."""
    melody = create_melody()
    full_musical_cycle = TOTAL_BARS * BAR_DURATION

    # Sound parameters
    transpose_factor = 2.0 ** (-2.0 / 12.0)  # -2 semitones

    # Organ harmonics
    organ_harmonics = [1.0, 2.0, 3.0, 4.0, 6.0]
    organ_amps = [1.0, 0.45, 0.25, 0.12, 0.03]

    # Trumpet harmonics
    trumpet_harmonics = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    trumpet_amps = [1.0, 0.55, 0.35, 0.2, 0.12, 0.06]

    # Clarinet harmonics (odd only)
    clarinet_harmonics = [1.0, 3.0, 5.0, 7.0, 9.0]
    clarinet_amps = [1.0, 0.33, 0.2, 0.14, 0.11]

    # Envelope parameters
    attack_time = 0.15
    release_time = 0.18
    gymno_attack = 0.35
    gymno_decay = 4.5
    gymno_release = 0.5
    gymno_detune = 0.1

    master_gain = 0.22
    gymno_gain = 0.28

    vibrato_rate = 4.0
    vibrato_depth = 0.001

    # Crossfade timing (Bar 2, Beat 1.0)
    crossfade_start = (2 - 1) * BAR_DURATION + 1.0 * BEAT_DURATION
    crossfade_dur = 2.0 * BEAT_DURATION
    crossfade_end = crossfade_start + crossfade_dur

    # Timbre switch points
    trumpet_start = (17 - 1) * BAR_DURATION + 2.0 * BEAT_DURATION
    clarinet_start = (21 - 1) * BAR_DURATION + 2.0 * BEAT_DURATION

    high_freq_threshold = 600.0
    high_freq_max = JupiterPitch.C6.value

    output = np.zeros_like(t)

    for i, time in enumerate(t):
        musical_time = real_to_musical_time(time, first_cycle, normal_cycle)
        local = musical_time % full_musical_cycle
        section = get_section_at_musical_time(musical_time)
        section_progress = get_section_progress(musical_time, section)

        # Calculate organ blend
        if local < crossfade_start:
            organ_blend = 0.0
        elif local < crossfade_end:
            organ_blend = (local - crossfade_start) / crossfade_dur
        else:
            organ_blend = 1.0

        value = 0.0

        for note in melody:
            note_start = (note.bar - 1) * BAR_DURATION + note.beat * BEAT_DURATION
            note_dur = note.dur_beats * BEAT_DURATION

            breath_amount = note.breath.value
            effective_dur = max(note_dur - breath_amount, attack_time) if breath_amount > 0 else note_dur

            active_release = gymno_release if organ_blend < 1.0 else release_time

            if local >= note_start and local < note_start + effective_dur + active_release:
                dt = local - note_start
                transposed_freq = note.freq * transpose_factor

                # High frequency gain reduction
                if transposed_freq >= high_freq_threshold:
                    reduction_ratio = min(1.0, (transposed_freq - high_freq_threshold) / (high_freq_max - high_freq_threshold))
                    gain_reduction = 1.0 - reduction_ratio * 0.35
                else:
                    gain_reduction = 1.0

                if organ_blend == 0.0:
                    # Pure Gymnopédie (Bar 1)
                    env = calculate_gymnopédie_envelope(dt, effective_dur, gymno_attack, gymno_decay, gymno_release)
                    v = generate_gymnopédie_voice(transposed_freq, time, gymno_detune)
                    value += v * env * gymno_gain

                elif organ_blend < 1.0:
                    # Crossfade
                    gymno_fade = 1.0 - organ_blend
                    organ_fade = organ_blend

                    gymno_env = calculate_gymnopédie_envelope(dt, effective_dur, gymno_attack, gymno_decay, gymno_release)
                    gymno_v = generate_gymnopédie_voice(transposed_freq, time, gymno_detune)

                    organ_env = calculate_asr_envelope(dt, effective_dur, attack_time, active_release)
                    organ_v = generate_harmonic_voice(transposed_freq, time, organ_harmonics, organ_amps, vibrato_rate, vibrato_depth)

                    value += gymno_v * gymno_env * gymno_gain * gymno_fade
                    value += organ_v * organ_env * gain_reduction * master_gain * organ_fade

                elif note_start < trumpet_start:
                    # Organ
                    env = calculate_asr_envelope(dt, effective_dur, attack_time, active_release)
                    v = generate_harmonic_voice(transposed_freq, time, organ_harmonics, organ_amps, vibrato_rate, vibrato_depth)
                    value += v * env * gain_reduction * master_gain

                elif note_start < clarinet_start:
                    # Trumpet
                    env = calculate_asr_envelope(dt, effective_dur, attack_time, active_release)
                    v = generate_harmonic_voice(transposed_freq, time, trumpet_harmonics, trumpet_amps, vibrato_rate, vibrato_depth * 1.5)
                    value += v * env * gain_reduction * master_gain

                else:
                    # Clarinet with climax fade
                    env = calculate_asr_envelope(dt, effective_dur, attack_time, active_release)
                    v = generate_harmonic_voice(transposed_freq, time, clarinet_harmonics, clarinet_amps, vibrato_rate, vibrato_depth)

                    if section_progress < 0.8:
                        climax_gain = 1.1
                    else:
                        fade_progress = (section_progress - 0.8) / 0.2
                        c = np.cos(fade_progress * np.pi * 0.5)
                        climax_gain = 1.1 * c * c

                    value += v * env * gain_reduction * master_gain * climax_gain

        output[i] = soft_clip(value)

    return output


def calculate_asr_envelope(time: float, duration: float, attack: float, release: float) -> float:
    """ASR envelope with sin²/cos² curves."""
    if time < attack:
        progress = time / attack
        s = np.sin(progress * np.pi * 0.5)
        return s * s

    if time < duration:
        return 1.0

    release_progress = (time - duration) / release
    if release_progress < 1.0:
        c = np.cos(release_progress * np.pi * 0.5)
        return c * c

    return 0.0


def calculate_gymnopédie_envelope(time: float, duration: float, attack: float, decay: float, release: float) -> float:
    """Gymnopédie-style ADR envelope."""
    if time < attack:
        progress = time / attack
        s = np.sin(progress * np.pi * 0.5)
        return s * s

    if time < duration:
        decay_progress = time - attack
        return np.exp(-decay_progress / decay)

    release_progress = (time - duration) / release
    if release_progress < 1.0:
        env_at_end = np.exp(-(duration - attack) / decay)
        c = np.cos(release_progress * np.pi * 0.5)
        return env_at_end * c * c

    return 0.0


def generate_harmonic_voice(freq: float, t: float, harmonics: list, amps: list, vibrato_rate: float, vibrato_depth: float) -> float:
    """Generate voice with harmonics and vibrato."""
    vibrato = np.sin(2.0 * np.pi * vibrato_rate * t) * vibrato_depth

    signal = 0.0
    for h, a in zip(harmonics, amps):
        h_freq = freq * h
        raw_phase = h_freq * t
        wrapped_phase = raw_phase - np.floor(raw_phase)
        phase = 2.0 * np.pi * (wrapped_phase + vibrato)
        signal += np.sin(phase) * a

    return signal / len(harmonics)


def generate_gymnopédie_voice(freq: float, t: float, detune: float) -> float:
    """Generate Gymnopédie-style voice with subtle detune."""
    v1 = np.sin(2.0 * np.pi * freq * t)
    v2 = np.sin(2.0 * np.pi * (freq + detune) * t)
    v3 = np.sin(2.0 * np.pi * (freq - detune) * t)
    return (v1 + v2 + v3) / 3.0


def soft_clip(x: float, threshold: float = 0.8) -> float:
    """Soft clip to prevent harsh distortion."""
    if abs(x) <= threshold:
        return x
    sign = 1.0 if x > 0 else -1.0
    return sign * (threshold + (1.0 - threshold) * np.tanh((abs(x) - threshold) / (1.0 - threshold)))


def generate_tree_chime(t: np.ndarray, first_cycle: float, normal_cycle: float, seed: int = 42) -> np.ndarray:
    """Generate tree chime accents at appropriate musical positions."""
    np.random.seed(seed)

    num_grains = 24
    cascade_interval = 0.020
    grain_duration = 1.2
    base_freq = 6000.0
    detune_range = 3.0
    master_gain = 0.03
    section_0_gain = 0.1

    # Pre-generate base frequencies
    base_freqs = [base_freq * (0.8 + (i / (num_grains - 1)) * 0.5) for i in range(num_grains)]

    output = np.zeros_like(t)
    full_musical_cycle = TOTAL_BARS * BAR_DURATION

    # Chime trigger positions (10-20s intervals depending on section)
    # We'll place chimes at strategic musical positions
    chime_times = []

    # Section 0-1: very sparse (20-40s intervals)
    chime_times.append(15.0)  # One distant chime

    # Section 2 (Bar 9-12): Initial appearance
    chime_times.extend([25.0, 30.0])

    # Section 3-4 (Bar 13-20): Regular
    chime_times.extend([38.0, 48.0, 55.0])

    # Section 5 (Bar 21-25): Climax
    chime_times.extend([62.0, 68.0])

    for chime_start in chime_times:
        # Generate random values for this chime
        detunes = (np.random.random(num_grains) - 0.5) * detune_range
        phase_offsets = np.random.random(num_grains) * 2 * np.pi

        # Determine gain based on section
        musical_time = real_to_musical_time(chime_start, first_cycle, normal_cycle)
        section = get_section_at_musical_time(musical_time)

        if section in [0, 1]:
            section_gain = section_0_gain
        elif section == 2:
            section_gain = 0.6
        elif section in [3, 4]:
            section_gain = 0.8
        else:
            section_progress = get_section_progress(musical_time, section)
            if section_progress < 0.8:
                section_gain = 1.0
            else:
                fade_progress = (section_progress - 0.8) / 0.2
                c = np.cos(fade_progress * np.pi * 0.5)
                section_gain = section_0_gain + (1.0 - section_0_gain) * c * c

        # Find samples for this chime
        chime_end = chime_start + num_grains * cascade_interval + grain_duration * 3.0
        mask = (t >= chime_start) & (t < chime_end)
        indices = np.where(mask)[0]

        for idx in indices:
            time = t[idx]
            time_since_chime = time - chime_start

            value = 0.0
            for i in range(num_grains):
                grain_start = i * cascade_interval
                time_since_grain = time_since_chime - grain_start

                if time_since_grain < 0:
                    continue

                envelope = np.exp(-time_since_grain / grain_duration)
                if envelope < 0.001:
                    continue

                freq = base_freqs[i] + detunes[i]
                phase = 2.0 * np.pi * freq * time + phase_offsets[i]
                value += np.sin(phase) * envelope

            output[idx] += value / num_grains * master_gain * section_gain

    return output


def apply_schroeder_reverb(signal: np.ndarray, sample_rate: int = SAMPLE_RATE) -> np.ndarray:
    """Apply Schroeder reverb for cathedral atmosphere."""
    room_size = 2.2
    damping = 0.35
    decay = 0.88
    mix = 0.55
    predelay = 0.04

    # Predelay
    predelay_samples = int(predelay * sample_rate)
    delayed = np.zeros(len(signal) + predelay_samples)
    delayed[predelay_samples:] = signal

    # Simple comb filter reverb (simplified Schroeder)
    output = np.copy(delayed)

    # Comb filter delays (ms) scaled by room size
    comb_delays_ms = [29.7, 37.1, 41.1, 43.7]
    comb_gains = [decay] * 4

    for delay_ms, gain in zip(comb_delays_ms, comb_gains):
        delay_samples = int(delay_ms * room_size * sample_rate / 1000.0)
        filtered = np.zeros_like(output)

        for i in range(delay_samples, len(output)):
            filtered[i] = output[i] + gain * (1.0 - damping) * filtered[i - delay_samples]

        output = output + filtered * 0.25

    # Allpass filters for diffusion
    allpass_delays_ms = [5.0, 1.7]

    for delay_ms in allpass_delays_ms:
        delay_samples = int(delay_ms * room_size * sample_rate / 1000.0)
        filtered = np.zeros_like(output)

        g = 0.5
        for i in range(delay_samples, len(output)):
            filtered[i] = -g * output[i] + output[i - delay_samples] + g * filtered[i - delay_samples]

        output = filtered

    # Mix dry and wet
    result = (1.0 - mix) * signal + mix * output[:len(signal)]

    return result


def normalize(signal: np.ndarray, target_peak: float = 0.9) -> np.ndarray:
    """Normalize signal to target peak level."""
    max_val = np.max(np.abs(signal))
    if max_val > 0:
        return signal * (target_peak / max_val)
    return signal


def apply_loop_crossfade(signal: np.ndarray, crossfade_duration: float = 0.1, sample_rate: int = SAMPLE_RATE) -> np.ndarray:
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


def main():
    print("=" * 60)
    print("Cathedral Stillness Audio Generator for TsukiSound")
    print("=" * 60)

    # Calculate cycle duration
    first_cycle, normal_cycle = calculate_cycle_duration()
    print(f"First cycle duration: {first_cycle:.2f}s")
    print(f"Normal cycle duration: {normal_cycle:.2f}s")

    # Generate one full cycle (first cycle for seamless loop start)
    duration = first_cycle
    num_samples = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, num_samples, endpoint=False)

    print(f"\nGenerating audio ({duration:.2f}s at {SAMPLE_RATE}Hz)...")
    print()

    # Generate each layer
    print("1/4 Generating organ drone...")
    drone = generate_organ_drone(t, first_cycle, normal_cycle)

    print("2/4 Generating Jupiter melody...")
    melody = generate_jupiter_melody(t, first_cycle, normal_cycle)

    print("3/4 Generating tree chime accents...")
    chime = generate_tree_chime(t, first_cycle, normal_cycle)

    # Mix layers
    print("4/4 Mixing and applying reverb...")
    mixed = drone + melody * 0.7 + chime * 0.8

    # Apply reverb
    with_reverb = apply_schroeder_reverb(mixed)

    # Apply crossfade for seamless looping (100ms)
    crossfaded = apply_loop_crossfade(with_reverb, crossfade_duration=0.1)

    # Normalize
    final = normalize(crossfaded)

    # Save
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_DIR)
    os.makedirs(output_path, exist_ok=True)

    wav_path = os.path.join(output_path, "cathedral_stillness.wav")

    # Convert to 16-bit PCM
    signal_int16 = (final * 32767).astype(np.int16)
    wavfile.write(wav_path, SAMPLE_RATE, signal_int16)

    print()
    print(f"Saved: cathedral_stillness.wav")
    print()
    print("=" * 60)
    print("Next step: Convert to CAF format using:")
    print()
    print("  cd TsukiSound/Resources/Audio")
    print('  afconvert -f caff -d LEF32@48000 -c 1 cathedral_stillness.wav cathedral_stillness.caf')
    print("=" * 60)


if __name__ == "__main__":
    main()
