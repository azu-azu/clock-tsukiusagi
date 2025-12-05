"""
Shared audio utility functions for TsukiSound audio generators.
"""

import numpy as np

SAMPLE_RATE = 48000


def apply_loop_crossfade(signal: np.ndarray, crossfade_duration: float = 0.1, sample_rate: int = SAMPLE_RATE) -> np.ndarray:
    """
    Create perfect loop waveform by crossfading end into start.

    The key insight: both the START and END of the file must be modified
    so that when the file loops, the transition is seamless.

    Method:
    1. Crossfade the end section with the start section
    2. Replace BOTH the start and end with the crossfaded result
    3. This ensures: end of file == start of file (perfect loop)

    Args:
        signal: Input audio signal
        crossfade_duration: Duration of crossfade in seconds (default: 0.1)
        sample_rate: Sample rate in Hz (default: 48000)

    Returns:
        Signal with seamless loop crossfade applied
    """
    crossfade_samples = int(crossfade_duration * sample_rate)

    if crossfade_samples * 2 >= len(signal):
        return signal

    result = signal.copy()

    # Equal-power crossfade curves
    t = np.linspace(0, np.pi / 2, crossfade_samples)
    fade_out = np.cos(t) ** 2  # 1 -> 0
    fade_in = np.sin(t) ** 2   # 0 -> 1

    end_section = signal[-crossfade_samples:]
    start_section = signal[:crossfade_samples]

    # Create the crossfaded transition
    crossfaded = end_section * fade_out + start_section * fade_in

    # Apply to BOTH start and end (this is the key!)
    # The end fades out while mixing in the start
    # The start fades in while mixing in the end
    result[:crossfade_samples] = crossfaded
    result[-crossfade_samples:] = crossfaded

    return result


def apply_silence_padding(
    signal: np.ndarray,
    fade_in_duration: float = 0.5,
    fade_out_duration: float = 0.5,
    sample_rate: int = SAMPLE_RATE
) -> np.ndarray:
    """
    Apply fade-in at start and fade-out at end to create silence boundaries.

    This ensures the loop boundary is silence-to-silence, eliminating pops/clicks.

    The signal is modified in place:
    - Start: silence -> fade in over fade_in_duration
    - End: fade out over fade_out_duration -> silence

    Args:
        signal: Input audio signal
        fade_in_duration: Duration of fade-in in seconds (default: 0.5)
        fade_out_duration: Duration of fade-out in seconds (default: 0.5)
        sample_rate: Sample rate in Hz (default: 48000)

    Returns:
        Signal with silence padding applied
    """
    fade_in_samples = int(fade_in_duration * sample_rate)
    fade_out_samples = int(fade_out_duration * sample_rate)

    if fade_in_samples + fade_out_samples >= len(signal):
        return signal

    result = signal.copy()

    # Fade-in: 0 -> 1 using cosine curve (smooth start from silence)
    if fade_in_samples > 0:
        t_in = np.linspace(0, np.pi / 2, fade_in_samples)
        fade_in_curve = np.sin(t_in) ** 2  # 0 -> 1
        result[:fade_in_samples] *= fade_in_curve

    # Fade-out: 1 -> 0 using cosine curve (smooth end to silence)
    if fade_out_samples > 0:
        t_out = np.linspace(0, np.pi / 2, fade_out_samples)
        fade_out_curve = np.cos(t_out) ** 2  # 1 -> 0
        result[-fade_out_samples:] *= fade_out_curve

    return result


def normalize(signal: np.ndarray, target_peak: float = 0.9) -> np.ndarray:
    """
    Normalize signal to target peak level.

    Args:
        signal: Input audio signal
        target_peak: Target peak amplitude (default: 0.9)

    Returns:
        Normalized signal
    """
    max_val = np.max(np.abs(signal))
    if max_val > 0:
        return signal * (target_peak / max_val)
    return signal
