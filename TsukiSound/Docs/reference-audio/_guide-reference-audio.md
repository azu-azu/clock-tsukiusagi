# Reference Audio Assets

This directory contains field recordings and other external audio files that are **only** used for analysis, preset tuning, or reproduction experiments. These files are *not* bundled with the shipping application and should stay outside `TsukiSound/Resources/Audio`.

## Current Files

- `sea-and-seagull-wave-5932.mp3` — beach ambience with periodic seagull calls. Used as the reference profile for `generate_seagull_chirp` and the OceanWavesSeagulls preset.

## How to Use

1. Run the analyzer to pull quick metrics:
   ```bash
   python scripts/analyze_sea_and_seagull.py TsukiSound/Docs/reference-audio/sea-and-seagull-wave-5932.mp3
   ```
   This prints duration, RMS, peak levels, spectral centroid, and a coarse envelope for preset calibration.
2. Update `scripts/generate_test_tone.py` (or other synthesis tools) using those measurements.
3. When adding new reference takes, drop them into this folder and document their origin plus usage notes here.

> Tip: Keep this directory git-tracked only when the licensing of the reference audio permits redistributing with the repository. Otherwise, store the file elsewhere and mention the download location in this README.
