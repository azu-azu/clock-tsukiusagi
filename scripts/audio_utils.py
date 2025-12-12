"""
Shared audio utility functions for TsukiSound audio generators.
"""

import numpy as np

SAMPLE_RATE = 48000


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
