#!/usr/bin/env python3
"""
Analyze the `sea-and-seagull-wave-5932.mp3` ambience recording.

Usage:
    python scripts/analyze_sea_and_seagull.py sea-and-seagull-wave-5932.mp3

Outputs a JSON-like summary with duration, RMS, peak, spectral centroid,
and a coarse loudness envelope that you can use when designing presets.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import math
import shutil
import subprocess
import sys
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import List, Sequence

import numpy as np


@dataclass
class AudioStats:
    path: str
    sample_rate: int
    channels: int
    duration_sec: float
    rms_per_channel: Sequence[float]
    peak_per_channel: Sequence[float]
    spectral_centroid_hz: float
    rms_envelope: Sequence[float]


def ensure_wav(input_path: Path) -> Path:
    """Return a WAV version of `input_path`, transcoding via ffmpeg/afconvert if needed."""
    if input_path.suffix.lower() in {".wav", ".aiff", ".aif"}:
        return input_path

    tmp_dir = Path(tempfile.gettempdir())
    tmp_wav = tmp_dir / f"{input_path.stem}_analysis.wav"

    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        cmd = [
            ffmpeg,
            "-y",
            "-i",
            str(input_path),
            "-ac",
            "2",
            "-ar",
            "48000",
            str(tmp_wav),
        ]
    else:
        afconvert = shutil.which("afconvert")
        if not afconvert:
            raise RuntimeError("Need ffmpeg or afconvert to decode MP3 files.")
        cmd = [
            afconvert,
            str(input_path),
            str(tmp_wav),
            "-f",
            "WAVE",
            "-d",
            "LEI16",
        ]

    completed = subprocess.run(cmd, capture_output=True, text=True)
    if completed.returncode != 0:
        raise RuntimeError(f"Decoder failed ({completed.returncode}): {completed.stderr.strip()}")

    return tmp_wav


def read_wave(path: Path) -> tuple[np.ndarray, int]:
    import wave

    with contextlib.closing(wave.open(str(path), "rb")) as wf:
        channels = wf.getnchannels()
        sample_rate = wf.getframerate()
        sample_width = wf.getsampwidth()
        n_frames = wf.getnframes()
        raw = wf.readframes(n_frames)

    if sample_width != 2:
        raise ValueError(f"Expected 16-bit PCM, got {sample_width * 8}-bit.")

    data = np.frombuffer(raw, dtype=np.int16).reshape(-1, channels).astype(np.float32) / 32768.0
    return data, sample_rate


def compute_spectral_centroid(mono: np.ndarray, sample_rate: int) -> float:
    window = np.hanning(len(mono))
    spectrum = np.abs(np.fft.rfft(mono * window))
    freqs = np.fft.rfftfreq(len(mono), 1 / sample_rate)
    energy = np.sum(spectrum)
    return float(np.sum(freqs * spectrum) / energy) if energy > 0 else 0.0


def compute_rms_envelope(mono: np.ndarray, sample_rate: int, window_seconds: float = 0.5) -> List[float]:
    hop = max(1, int(sample_rate * window_seconds))
    envelopes: List[float] = []
    for start in range(0, len(mono), hop):
        chunk = mono[start : start + hop]
        if chunk.size == 0:
            continue
        envelopes.append(float(math.sqrt(float(np.mean(chunk**2)))))
    return envelopes


def analyze(path: Path) -> AudioStats:
    wav_path = ensure_wav(path)
    audio, sample_rate = read_wave(wav_path)
    duration = audio.shape[0] / sample_rate

    rms = np.sqrt(np.mean(np.square(audio), axis=0))
    peak = np.max(np.abs(audio), axis=0)
    mono = np.mean(audio, axis=1)
    centroid = compute_spectral_centroid(mono, sample_rate)
    envelope = compute_rms_envelope(mono, sample_rate)

    return AudioStats(
        path=str(path),
        sample_rate=sample_rate,
        channels=audio.shape[1],
        duration_sec=duration,
        rms_per_channel=[float(x) for x in rms],
        peak_per_channel=[float(x) for x in peak],
        spectral_centroid_hz=centroid,
        rms_envelope=envelope,
    )


def main(argv: Sequence[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Analyze MP3 ambience files.")
    parser.add_argument("audio_path", type=Path, help="Path to sea-and-seagull-wave-5932.mp3")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of pretty text")
    args = parser.parse_args(argv)

    stats = analyze(args.audio_path)

    if args.json:
        json.dump(asdict(stats), sys.stdout, indent=2)
        sys.stdout.write("\n")
        return

    print(f"File: {stats.path}")
    print(f"Duration: {stats.duration_sec:.3f}s")
    print(f"Sample rate: {stats.sample_rate} Hz")
    print(f"Channels: {stats.channels}")
    print(f"RMS (per channel): {stats.rms_per_channel}")
    print(f"Peak (per channel): {stats.peak_per_channel}")
    print(f"Spectral centroid: {stats.spectral_centroid_hz:.1f} Hz")
    print(f"Envelope samples (first 10): {stats.rms_envelope[:10]}")
    print(f"Total envelope slices: {len(stats.rms_envelope)}")


if __name__ == "__main__":
    main()
