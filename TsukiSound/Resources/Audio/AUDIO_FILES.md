# Audio Resources

This directory contains audio files for TrackPlayer playback.

## Current Status

**Audio files are not included in the repository** due to file size considerations.

The app currently uses **real-time synthesized audio** via `ClickSuppressionDrone`, which generates:
- Pink noise (with 2kHz LPF)
- Low-frequency drones (165Hz, 196Hz)
- Breathing LFO modulation

This approach provides:
- ✅ Zero file size overhead
- ✅ Perfect seamless looping
- ✅ Dynamic parameter control
- ✅ No quality loss from compression

## Adding Audio Files (Optional)

If you want to use pre-recorded audio files with TrackPlayer:

### 1. Generate Audio Files

**Option A: Using homebrew tools (macOS)**
```bash
# Install audio generation tools
brew install sox
# or
brew install ffmpeg

# Run generation script
cd scripts
./generate_audio_simple.sh
```

**Option B: Manual addition**
Add your own WAV or CAF files to this directory:
- Supported formats: WAV (PCM), CAF (Apple Core Audio Format)
- Recommended: 44.1kHz, 16-bit, mono
- Duration: 30-60 seconds for seamless looping

### 2. Add to Xcode Project

1. Drag audio files into Xcode project navigator
2. Check "Copy items if needed"
3. Set Target Membership to **clock-tsukiusagi**
4. Verify files appear in Build Phases > Copy Bundle Resources

### 3. Update AudioFilePreset

Edit `Core/Audio/Presets/AudioFilePresets.swift`:

```swift
public enum AudioFilePreset: String, CaseIterable {
    case pinkNoise = "pink_noise_60s"
    case brownNoise = "brown_noise_60s"
    case oceanWaves = "ocean_waves_60s"
    // Add your files here
}
```

## File Naming Convention

Use descriptive names with duration suffix:
- `pink_noise_60s.caf`
- `ocean_waves_30s.caf`
- `rain_gentle_45s.caf`

Duration suffix helps identify loop length.

## Why CAF Format?

CAF (Core Audio Format) is Apple's recommended format because:
- Unrestricted file size
- Supports all audio formats
- Optimized for iOS/macOS
- Better metadata support

Convert WAV to CAF:
```bash
afconvert -f caff -d LEI16 input.wav output.caf
```

## Current Architecture

```
Audio Playback:
├── Real-time Synthesis (Primary)
│   └── ClickSuppressionDrone
│       ├── Pink noise generator
│       ├── Low-frequency drones
│       └── LFO modulation
│
└── File-based Playback (Optional)
    └── TrackPlayer
        ├── Loads WAV/CAF from Bundle
        ├── Seamless looping
        └── Crossfade support
```

## Performance Considerations

| Method | Pros | Cons |
|--------|------|------|
| Real-time Synthesis | Zero file size, Perfect loops, Dynamic control | CPU usage |
| Pre-recorded Files | Lower CPU, Consistent quality | File size, Storage |

Current app uses synthesis because:
- Audio is simple (noise + drones)
- Perfect loop seams without crossfade
- Parameters can be adjusted in real-time
- No storage overhead

## Testing TrackPlayer

To test TrackPlayer without adding large audio files:

1. Generate a short test tone:
```bash
# Using afplay (macOS built-in)
python3 -c "import math, wave;
w=wave.open('test_440hz.wav','w');
w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100);
w.writeframes(b''.join([int(32767*math.sin(2*math.pi*440*i/44100)).to_bytes(2,'little',signed=True) for i in range(44100)]))"
```

2. Convert to CAF:
```bash
afconvert -f caff -d LEI16 test_440hz.wav test_440hz.caf
```

3. Add to Xcode and test with TrackPlayer

## Future Enhancements

Potential audio files to add:
- [ ] Natural sounds (waves, rain, fire)
- [ ] Binaural beats
- [ ] ASMR triggers
- [ ] Music loops

Current priority: **Real-time synthesis works perfectly, audio files are optional enhancement**
