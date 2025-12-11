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
import os
from dataclasses import dataclass
from enum import Enum
from typing import List, Optional

from pedalboard import Pedalboard, Reverb, Compressor, Limiter

from audio_utils import normalize

# Constants
SAMPLE_RATE = 48000
OUTPUT_DIR = "../TsukiSound/Resources/Audio"

# =============================================================================
# Jupiter Timing (from JupiterTiming.swift)
# =============================================================================

BEAT_DURATION = 1.0  # 60 BPM = 1.0s per beat
BAR_DURATION = BEAT_DURATION * 3.0  # 3/4 time = 3 beats per bar
TOTAL_BARS = 25

# Tempo ratios per section (lower = slower)
SECTION_0_TEMPO = 0.8   # Slower, a cappella style
SECTION_1_TEMPO = 1.0   # Normal
SECTION_2_TEMPO = 1.1   # Slightly faster
SECTION_3_4_TEMPO = 1.2 # Fast (sections 3-4)
SECTION_5_TEMPO_START = 1.2  # Start at same tempo as section 3-4
SECTION_5_TEMPO_END = 1.0    # Gradually slow to normal tempo
# Average tempo for section 5 duration calculation
SECTION_5_TEMPO = (SECTION_5_TEMPO_START + SECTION_5_TEMPO_END) / 2  # 1.1

# Section boundaries (bar numbers, 1-indexed)
SECTION_BARS = [1, 5, 9, 13, 17, 21]

# Intro rest (2 beats) - skipped because no organ accompaniment
INTRO_REST_BEATS = 2.0

# Lead-in silence before first note (for natural start)
LEAD_IN_SILENCE = 0.5  # seconds


def calculate_cycle_duration() -> float:
    """Calculate cycle duration with tempo stretch.

    Since we have no organ accompaniment and end in silence,
    we skip the intro rest entirely for seamless looping.
    A short lead-in silence is added for natural start feel.
    """
    # Musical durations (in beats)
    sec0_musical = (SECTION_BARS[1] - SECTION_BARS[0]) * BAR_DURATION  # 12 (bars 1-4)
    sec1_musical = (SECTION_BARS[2] - SECTION_BARS[1]) * BAR_DURATION  # 12 (bars 5-8)
    sec2_musical = (SECTION_BARS[3] - SECTION_BARS[2]) * BAR_DURATION  # 12 (bars 9-12)
    sec3_4_musical = (SECTION_BARS[5] - SECTION_BARS[3]) * BAR_DURATION  # 24 (bars 13-20)
    sec5_musical = (TOTAL_BARS - SECTION_BARS[5] + 1) * BAR_DURATION  # 15 (bars 21-25)

    # Real durations with tempo stretch
    sec0_real = sec0_musical / SECTION_0_TEMPO
    sec1_real = sec1_musical / SECTION_1_TEMPO
    sec2_real = sec2_musical / SECTION_2_TEMPO
    sec3_4_real = sec3_4_musical / SECTION_3_4_TEMPO
    sec5_real = sec5_musical / SECTION_5_TEMPO

    full_musical = TOTAL_BARS * BAR_DURATION  # 75s

    tempo_extra = ((sec0_real - sec0_musical) + (sec2_real - sec2_musical) +
                   (sec3_4_real - sec3_4_musical) + (sec5_real - sec5_musical))

    # Skip intro rest (2 beats at slow tempo) - no organ so no need for rest
    intro_rest_real = (INTRO_REST_BEATS * BEAT_DURATION) / SECTION_0_TEMPO
    cycle_without_intro = full_musical + tempo_extra - intro_rest_real

    return cycle_without_intro


def real_to_musical_time(real_time: float, cycle_duration: float) -> float:
    """Convert real time to musical time (with lead-in offset and intro skip)."""
    # Subtract lead-in silence to get actual musical time
    adjusted_time = real_time - LEAD_IN_SILENCE
    if adjusted_time < 0:
        # During lead-in silence, return time before first note
        return INTRO_REST_BEATS * BEAT_DURATION + adjusted_time
    return convert_with_tempo_stretch(adjusted_time, intro_skipped=True)


def calculate_section5_real_duration(musical_dur: float) -> float:
    """Calculate real duration for section 5 with gradual tempo change.

    For tempo changing linearly from t0 to t1 over musical duration M:
    real_duration = M * 2 / (t0 + t1) = M / average_tempo
    """
    return musical_dur / SECTION_5_TEMPO  # Uses average tempo


def section5_real_to_musical(real_time_in_section: float, sec5_real_dur: float, sec5_musical_dur: float) -> float:
    """Convert real time within section 5 to musical time.

    With linearly changing tempo from SECTION_5_TEMPO_START to SECTION_5_TEMPO_END:
    - At start: tempo = 1.2 (fast, matches section 3-4)
    - At end: tempo = 1.0 (normal)

    The relationship is:
    d(musical)/d(real) = tempo(progress)
    tempo(progress) = start + (end - start) * progress

    Integrating: musical = real * (start + (end-start)/2 * progress)
    But progress depends on real_time, making this implicit.

    For simplicity, we use a quadratic approximation that's accurate enough.
    """
    if sec5_real_dur <= 0:
        return 0.0

    # Linear progress through section 5 real time
    real_progress = real_time_in_section / sec5_real_dur
    real_progress = max(0.0, min(1.0, real_progress))

    # Tempo at this point (linear interpolation)
    tempo_start = SECTION_5_TEMPO_START
    tempo_end = SECTION_5_TEMPO_END

    # For gradual slowdown, the musical time advances faster at the start
    # (when tempo is high) and slower at the end (when tempo is low).
    #
    # Using integral approach:
    # If tempo(p) = t0 + (t1-t0)*p, and we integrate d(musical) = tempo * d(real)
    # musical_progress = integral of tempo over real_progress
    # = t0 * p + (t1-t0) * p^2 / 2, normalized by average
    #
    # Normalized: musical_progress = (t0 * p + (t1-t0) * p^2 / 2) / ((t0 + t1) / 2)

    p = real_progress
    t0, t1 = tempo_start, tempo_end
    avg_tempo = (t0 + t1) / 2

    # Unnormalized integral: t0*p + (t1-t0)*p^2/2
    unnormalized = t0 * p + (t1 - t0) * p * p / 2
    # Normalize so that at p=1, result=1
    # At p=1: unnormalized = t0 + (t1-t0)/2 = (t0+t1)/2 = avg_tempo
    musical_progress = unnormalized / avg_tempo

    return musical_progress * sec5_musical_dur


def convert_with_tempo_stretch(real_time: float, intro_skipped: bool = True) -> float:
    """Convert real time within a cycle to musical time."""
    intro_rest_musical = INTRO_REST_BEATS * BEAT_DURATION

    # Musical boundaries
    sec0_start = intro_rest_musical if intro_skipped else 0.0  # Skip 2 beats on first cycle
    sec0_end = (SECTION_BARS[1] - 1) * BAR_DURATION  # 12.0 (bar 4 end)
    sec1_end = (SECTION_BARS[2] - 1) * BAR_DURATION  # 24.0 (bar 8 end)
    sec2_end = (SECTION_BARS[3] - 1) * BAR_DURATION  # 36.0 (bar 12 end)
    sec3_4_end = (SECTION_BARS[5] - 1) * BAR_DURATION  # 60.0 (bar 20 end)
    sec5_end = TOTAL_BARS * BAR_DURATION             # 75.0 (bar 25 end)

    # Musical durations
    sec0_musical_dur = sec0_end - sec0_start
    sec1_musical_dur = sec1_end - sec0_end
    sec2_musical_dur = sec2_end - sec1_end
    sec3_4_musical_dur = sec3_4_end - sec2_end
    sec5_musical_dur = sec5_end - sec3_4_end

    # Real durations
    sec0_real_dur = sec0_musical_dur / SECTION_0_TEMPO
    sec1_real_dur = sec1_musical_dur / SECTION_1_TEMPO
    sec2_real_dur = sec2_musical_dur / SECTION_2_TEMPO
    sec3_4_real_dur = sec3_4_musical_dur / SECTION_3_4_TEMPO
    sec5_real_dur = calculate_section5_real_duration(sec5_musical_dur)

    # Cumulative real time boundaries
    sec0_real_end = sec0_real_dur
    sec1_real_end = sec0_real_end + sec1_real_dur
    sec2_real_end = sec1_real_end + sec2_real_dur
    sec3_4_real_end = sec2_real_end + sec3_4_real_dur
    sec5_real_end = sec3_4_real_end + sec5_real_dur

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
    elif real_time < sec3_4_real_end:
        time_in_sec = real_time - sec2_real_end
        progress = time_in_sec / sec3_4_real_dur if sec3_4_real_dur > 0 else 0
        return sec2_end + progress * sec3_4_musical_dur
    elif real_time < sec5_real_end:
        time_in_sec = real_time - sec3_4_real_end
        # Use gradual tempo change for section 5
        musical_offset = section5_real_to_musical(time_in_sec, sec5_real_dur, sec5_musical_dur)
        return sec3_4_end + musical_offset
    else:
        return sec5_end


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

def generate_organ_drone(t: np.ndarray, cycle_duration: float) -> np.ndarray:
    """Generate organ drone (CathedralStillnessSignal).

    Section 0: Silent (a cappella melody)
    Section 1: Fade in from 0 to full
    Section 2-4: Full volume
    Section 5: Fade out to silence (a cappella clarinet ending)

    This creates seamless looping: silence -> silence.
    """
    root_freq = 130.81  # C3
    fifth_freq = 196.00  # G3
    lfo_freq = 0.02     # 50s cycle

    full_volume = 1.0

    harmonics = [1.0, 2.0, 3.0, 4.0]
    amps = [0.9, 0.4, 0.25, 0.15]

    output = np.zeros_like(t)

    for i, time in enumerate(t):
        musical_time = real_to_musical_time(time, cycle_duration)
        section = get_section_at_musical_time(musical_time)
        section_progress = get_section_progress(musical_time, section)

        # LFO breathing (0.4 - 0.8 range)
        lfo_value = 0.6 + 0.2 * np.sin(2.0 * np.pi * lfo_freq * time)

        # Section volume: silent at start and end, full in middle
        if section == 0:
            # Section 0: Silent (a cappella)
            volume = 0.0
        elif section == 1:
            # Section 1: Fade in from silence to full
            s = np.sin(section_progress * np.pi * 0.5)
            volume = full_volume * s * s
        elif section == 5:
            # Section 5: Fade out to silence
            # Start fading at 20% progress, reach silence at 80%
            if section_progress < 0.2:
                volume = full_volume
            elif section_progress < 0.8:
                fade_progress = (section_progress - 0.2) / 0.6
                c = np.cos(fade_progress * np.pi * 0.5)
                volume = full_volume * c * c
            else:
                volume = 0.0  # Silent for the rest
        else:
            # Section 2-4: Full volume
            volume = full_volume

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


def generate_jupiter_melody(t: np.ndarray, cycle_duration: float) -> np.ndarray:
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
        musical_time = real_to_musical_time(time, cycle_duration)
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
                    # Clarinet with gradual fadeout through Section 5
                    env = calculate_asr_envelope(dt, effective_dur, attack_time, active_release)
                    v = generate_harmonic_voice(transposed_freq, time, clarinet_harmonics, clarinet_amps, vibrato_rate, vibrato_depth)

                    # Gradual fadeout: start at 30%, reach silence at 100%
                    if section_progress < 0.3:
                        climax_gain = 1.1
                    else:
                        fade_progress = (section_progress - 0.3) / 0.7
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


def generate_tree_chime(t: np.ndarray, cycle_duration: float, seed: int = 42) -> np.ndarray:
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
        musical_time = real_to_musical_time(chime_start, cycle_duration)
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


def apply_final_fadeout(signal: np.ndarray, fadeout_duration: float = 2.0, sample_rate: int = SAMPLE_RATE) -> np.ndarray:
    """Apply fadeout at the end to ensure silence for seamless looping."""
    fadeout_samples = int(fadeout_duration * sample_rate)

    if fadeout_samples >= len(signal):
        return signal

    result = signal.copy()

    # Equal-power fadeout curve
    t = np.linspace(0, np.pi / 2, fadeout_samples)
    fade_out = np.cos(t) ** 2  # 1 -> 0

    result[-fadeout_samples:] *= fade_out

    return result


def main():
    print("=" * 60)
    print("Cathedral Stillness Audio Generator for TsukiSound")
    print("=" * 60)

    # Calculate cycle duration (skips intro rest since no organ)
    cycle_duration = calculate_cycle_duration()
    print(f"Musical cycle duration: {cycle_duration:.2f}s (skips intro rest)")

    # Add lead-in silence for natural start
    lead_in = LEAD_IN_SILENCE
    # Add silence padding for reverb tail decay
    silence_padding = 1.0  # 1 second of silence at end (reduced since we have lead-in)

    # Generate one full cycle with lead-in and padding
    # Loop structure: lead-in → music → fadeout → silence → [loop] → lead-in → ...
    duration = lead_in + cycle_duration + silence_padding
    num_samples = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, num_samples, endpoint=False)

    print(f"\nGenerating audio ({duration:.2f}s at {SAMPLE_RATE}Hz)...")
    print(f"  - Lead-in silence: {lead_in:.2f}s")
    print(f"  - Musical content: {cycle_duration:.2f}s")
    print(f"  - End padding: {silence_padding:.2f}s")
    print()

    # Generate each layer
    print("1/4 Generating organ drone...")
    drone = generate_organ_drone(t, cycle_duration)

    print("2/4 Generating Jupiter melody...")
    melody = generate_jupiter_melody(t, cycle_duration)

    print("3/4 Generating tree chime accents...")
    chime = generate_tree_chime(t, cycle_duration)

    # Mix layers
    print("4/4 Mixing and applying effects...")
    mixed = drone + melody * 0.7 + chime * 0.8

    # Apply Pedalboard effects (professional quality)
    print("    Applying Pedalboard effects (Compressor + Reverb + Limiter)...")
    board = Pedalboard([
        # Gentle compression for consistent dynamics
        Compressor(
            threshold_db=-20,
            ratio=2.5,
            attack_ms=30,
            release_ms=250
        ),
        # Cathedral-style reverb for spacious atmosphere
        Reverb(
            room_size=0.7,
            damping=0.4,
            wet_level=0.45,
            dry_level=0.55,
            width=1.0
        ),
        # Final limiting to prevent clipping
        Limiter(threshold_db=-1.0)
    ])

    # Pedalboard expects shape (channels, samples) for mono: (1, N)
    mixed_2d = mixed.reshape(1, -1).astype(np.float32)
    processed_2d = board(mixed_2d, SAMPLE_RATE)
    with_effects = processed_2d.flatten()

    # Apply final fadeout (reverb tail fades to silence)
    # This ensures end is silent, matching the intro rest (silent)
    faded = apply_final_fadeout(with_effects, fadeout_duration=2.0)

    # Normalize
    final = normalize(faded)

    # Save
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_DIR)
    os.makedirs(output_path, exist_ok=True)

    wav_path = os.path.join(output_path, "jupiter.wav")

    # Convert to 16-bit PCM
    signal_int16 = (final * 32767).astype(np.int16)
    wavfile.write(wav_path, SAMPLE_RATE, signal_int16)

    print()
    print(f"Saved: jupiter.wav")
    print()
    print("=" * 60)
    print("Next step: Convert to CAF format using:")
    print()
    print("  cd TsukiSound/Resources/Audio")
    print('  afconvert -f caff -d LEF32@48000 -c 1 jupiter.wav jupiter.caf')
    print("=" * 60)


if __name__ == "__main__":
    main()
