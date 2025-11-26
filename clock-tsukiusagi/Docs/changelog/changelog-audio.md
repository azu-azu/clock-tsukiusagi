# Audio System Changelog

**Module**: Audio System (Core/Audio, Core/Services, Features/Settings)
**Current Version**: Phase 2 Complete + 3-Layer Architecture
**Last Updated**: 2025-11-26

---

## Experiment: Air Layer (2025-11-26) - REVERTED

**Status**: ❌ Failed - Removed
**Focus**: High-frequency transparency layer for ambient depth
**Commits**: `37e4758` (added), `32823ff` (expanded), `fa91528` (removed)

### Implementation Attempt

#### Air Layer Concept
- **Purpose**: Add subtle "air" presence in high-frequency range (6-10 kHz)
- **Inspiration**: Endel-style transparency layering technique
- **Goal**: Improve perceived transparency without muddying main sound

#### Technical Implementation
- **File**: `Core/Audio/Signal/Synthesis/AirLayer.swift` (created, then deleted)
- **Approach**: White noise → High-pass filter (6-10 kHz) → Very low volume (0.02-0.03)
- **Integration**: Added to all 5 presets via `FinalMixer`
- **Settings**: UI controls for enable/disable and volume adjustment

#### Preset-Specific Parameters
- `.pentatonicChime`: 9kHz cutoff, 0.030 volume (bright)
- `.cathedralStillness`: 8kHz cutoff, 0.035 volume (cathedral air)
- `.toyPiano`: 7kHz cutoff, 0.025 volume (soft, warm)
- `.moonlightFlow`: 8kHz cutoff, 0.030 volume (standard)
- `.moonlightFlowMidnight`: 6kHz cutoff, 0.020 volume (deep night)

### Why It Failed

#### Problem: Audible White Noise
- **Expected**: Barely audible "air" presence adding transparency
- **Actual**: Clearly audible "さーーっ" white noise hiss
- **User Feedback**: "Sounds like noise, not transparency"

#### Root Cause: Design Flaw

**1. Incorrect Use of Signal Paradigm**
```swift
// WRONG: Signal is a pure time function (stateless)
let filter = StateVariableFilter(...)
return Signal { time in
    let noise = Float.random(in: -1...1)
    return filter.process(noise * volume, time: time)
}
```

**Issues**:
- White noise is **random**, not a deterministic time function
- `StateVariableFilter` is **stateful** (maintains z1, z2 internal state)
- Signal closure is **stateless** (should be pure function of time)
- Incompatible paradigms led to filter malfunction

**2. Filter State Management Error**
- Filter created **outside** Signal closure
- But referenced **inside** closure with varying `time` parameter
- Result: Filter state corrupted, passing raw noise instead of filtered air

**3. Noise Generation Pattern**
- `Float.random()` called per sample breaks Signal purity
- No seed control means unpredictable behavior
- Pattern incompatible with Signal's time-function model

### Correct Implementation (Not Pursued)

**Should Have Used TreeChime Pattern**:
```swift
public final class AirLayerSource: AudioSource {
    private let _sourceNode: AVAudioSourceNode

    init(...) {
        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList in
            // Real-time noise generation + filtering in render callback
            // Proper stateful filter management
        }
    }
}
```

**Why Not Implemented**:
- Requires 2-3 hours of work
- Effect was not perceptible even with correct implementation
- Cost-benefit analysis: Not worth the effort

### Changes Reverted

**Files Deleted**:
- `AirLayer.swift` - Flawed Signal-based implementation

**Code Removed**:
- `PureToneBuilder.swift` - All `airLayer` instantiation and `mixer.add()` calls
- `AudioSettings.swift` - `airLayerEnabled` and `airLayerVolume` properties
- `AudioSettingsView.swift` - Air Layer settings UI section

**Presets Cleaned**:
- All 5 presets reverted to original design (no air layer)

### Lessons Learned

1. **Signal vs AudioSource**: Use Signal for deterministic time functions only. Use AudioSource for stochastic processes (noise, random events).

2. **Filter Paradigm Matching**: Stateful filters (StateVariableFilter) require stateful container (AudioSource), not stateless Signal.

3. **Prototype Validation**: Test core concept (white noise filtering) in isolation before full integration.

4. **User Perception > Theory**: "Transparency enhancement" that sounds like noise is worse than no enhancement.

### Commits

- `37e4758` - feat: add Air Layer for high-frequency transparency
- `32823ff` - feat: expand Air Layer to all presets with user settings
- `fa91528` - revert: remove Air Layer implementation completely

### Documentation Impact

- No changes to `Audio-Preset-Concepts.md` (not documented before removal)
- This changelog entry serves as historical record

---

## Architecture: 3-Layer Audio Preset System (2025-11-23)

**Status**: ✅ Complete
**Focus**: Clean separation of UI and technical concerns for audio presets
**Commits**: `b7ff4e4`, `2e29215`, `1799b8f`

### Added

#### UISoundPreset (UI Layer)
- **File**: `Core/Audio/Presets/UISoundPreset.swift` (new)
- **Purpose**: Display-only preset enum for UI selection
- **Features**:
  - All audio presets (PureTone + NaturalSound) unified in single enum
  - Display names (Japanese + emoji)
  - English titles
  - Test/production flags
  - No technical audio parameters

#### PureTone Module (Technical Layer)
- **Directory**: `Core/Audio/PureTone/` (new)
- **Files**:
  - `PureTonePreset.swift` - Preset definitions for pure tones
  - `PureToneParams.swift` - Parameter structure
  - `PureToneBuilder.swift` - Builder pattern for creating audio sources
  - `LunarPulse.swift` - Moved from Sources/
  - `TreeChime.swift` - Moved from Sources/
- **Purpose**: Isolated pure tone/instrument sound implementation

### Changed

#### AudioService API
- **File**: `Core/Audio/AudioService.swift`
- **Changes**:
  - `currentPreset` type: `NaturalSoundPreset?` → `UISoundPreset?`
  - `play(preset:)` signature: `NaturalSoundPreset` → `UISoundPreset`
  - Added `mapToPureTone()` - Maps UI preset to PureTonePreset
  - Added `mapToNaturalSound()` - Maps UI preset to NaturalSoundPreset
  - Updated `registerSource(for:)` to handle mapping logic

#### NaturalSoundPresets
- **File**: `Core/Audio/Presets/NaturalSoundPresets.swift`
- **Changes**:
  - Removed `.lunarPulse` case (moved to PureTonePreset)
  - Removed obsolete `LunarPulse` parameter struct
  - Added deprecation notes to `displayName`/`englishTitle` (UI now uses UISoundPreset)
  - Clean separation: natural/environmental sounds only

#### SignalPresetBuilder
- **File**: `Core/Audio/Signal/SignalPresetBuilder.swift`
- **Changes**:
  - Removed `.lunarPulse` handling from `createRawSignal()`
  - Removed PureTone effects from `applyEffectsForPreset()`

#### AudioTestView
- **File**: `Core/Audio/AudioTestView.swift`
- **Changes**:
  - `AudioSourcePreset` now uses `UISoundPreset`
  - `allSources` iterates `UISoundPreset.allCases`

### Architecture Benefits

1. **Clear Separation of Concerns**:
   - UI layer has zero audio parameters
   - Technical layers have zero display logic
   - No mixing of responsibilities

2. **Maintainability**:
   - UI changes don't affect audio implementation
   - Audio parameter changes don't affect UI
   - Easy to add new presets without touching multiple layers

3. **Type Safety**:
   - Automatic mapping prevents incorrect preset usage
   - Compile-time verification of mappings

4. **Extensibility**:
   - PureTone module can grow independently
   - NaturalSound presets remain isolated
   - UI can reorganize without code changes

### Documentation Updates
- Updated `architecture/_arch-audio-parameter-safety-rules.md` to v2.0 with 3-layer architecture
- Updated `audio-system-spec.md` API examples
- Updated `_guide-audio-system-impl.md` with mapping flow
- Updated `CLAUDE.md` with architecture explanation
- Updated all ADRs to reflect new preset types

---

## Enhancements: Audio Presets & Quality (2025-11-17)

**Status**: ✅ Complete
**Focus**: New audio presets, UI improvements, sample rate standardization

### Added

#### 12 New Natural Sound Presets
- **Files**: Multiple new AudioSource implementations in `Core/Audio/Sources/`
- **New Presets**:
  - MoonlitSea (深夜の海) - Pink noise + slow LFO for deep sea breathing
  - LunarPulse (月の脈動) - 528Hz pure tone + ultra-slow fade for light breathing
  - DarkShark (黒いサメの影) - Brown noise + random LFO for underwater presence
  - MidnightTrain (夜汽車) - Brown noise + rhythmic LFO for train rhythm
  - LunarTide (月光の潮流) - Pink noise + shimmer band + LFO for moonlit sea
  - AbyssalBreath (深海の呼吸) - Brown noise + sub-bass sine + LFO for deep sea creature
  - StardustNoise (星屑ノイズ) - White noise + high-band + micro bursts for star twinkle
  - LunarDustStorm (月面の砂嵐) - Pink noise + notch filter for vacuum wind
  - SilentLibrary (夜の図書館) - Brown noise + warm band for quiet space
  - DistantThunder (遠雷) - Brown noise + low-band pulse for distant thunder
  - SinkingMoon (沈む月) - 432Hz sine + ultra-slow fade for silence fading
  - DawnHint (朝の気配) - Pink noise + shimmer band for dawn air
- **Configuration**: All presets defined in `NaturalSoundPresets.swift`
- **Implementation**: Each preset has dedicated AudioSource class with custom DSP

#### UI Enhancements
- **Emoji Icons**: Added emoji to 12 new preset display names
  - Examples: 🌊 深夜の海, 🦈 黒いサメの影, 🚂 夜汽車
- **Bilingual Display**:
  - Picker shows Japanese + emoji (e.g., "💿 🌊 深夜の海")
  - Selected display shows English title (e.g., "Moonlit Silent Sea")
- **Production/Test Separation**:
  - Production presets: 💿 icon
  - Test presets: ✏️ icon (DEBUG build only)
- **File**: `AudioTestView.swift` - Added `englishTitle` property to `AudioSourcePreset`
- **File**: `NaturalSoundPresets.swift` - Added `englishTitle` computed property

### Changed

#### Preset Status Updates
- **Promoted to Production** (removed from `isTest` array):
  - 🌊 深夜の海 (Moonlit Silent Sea)
  - 🦈 黒いサメの影 (Dark Shape Underwater)
  - 🚂 夜汽車 (Midnight Train in the Distance)
  - 🌙🌊 月光の潮流 (Lunar Tide Drift)
  - 🫧💙 深海の呼吸 (Abyssal Breath)
- These now show 💿 icon instead of ✏️

### Fixed

#### Sample Rate Mismatch Issue ⭐ CRITICAL
- **Problem**: Crackling/clicking noise ("pachi-pachi") in new audio presets
- **Root Cause**: Sample rate inconsistency between AudioSource implementations
  - Old files: 44.1 kHz (OceanWaves, WindChime, TibetanBowl, ClickMaskingDrone)
  - New files: 48 kHz (all 12 new presets)
  - iOS hardware: **48 kHz standard**
  - Mismatch caused LFO phase calculation errors → clicks/pops
- **Solution**: Standardized ALL AudioSource implementations to **48 kHz**
- **Files Modified**:
  - `OceanWaves.swift`: 44100 → 48000 Hz
  - `WindChime.swift`: 44100 → 48000 Hz
  - `TibetanBowl.swift`: 44100 → 48000 Hz
  - `ClickMaskingDrone.swift`: 44100 → 48000 Hz (including diagnostic interval)
- **Result**: All 16 AudioSource files now use 48 kHz consistently
- **Impact**: Eliminated all clicking/crackling noise, improved audio quality
- **Documentation**: See [trouble-audio-sample-rate-mismatch.md](../trouble-audio-sample-rate-mismatch.md)

### Removed

#### Unused Presets Cleanup
- **Removed from NaturalSoundPreset**:
  - clickSuppression, pinkNoise, brownNoise, pleasantDrone, pleasantWarm,
    pleasantCalm, pleasantDeep, ambientFocus, ambientRelax, ambientSleep,
    oceanWaves (preset, kept OceanWaves class), cracklingFire
- **Removed from AudioFilePreset**:
  - testTone (test_tone_440hz)
  - pinkNoise (pink_noise_60s)
  - rain (rain_60s)
- **Files Deleted**: 7 AudioSource implementation files
- **Reason**: Consolidation and focus on curated preset collection

### Commits

- `849792e` - fix: standardize all audio sources to 48kHz sample rate
- `4e164c2` - feat: add emoji icons and English titles to audio presets
- `6cf792a` - refactor: remove 3 unused audio file presets
- `a830cdf` - refactor: promote 5 audio presets from test to production
- (Additional commits for 12 new preset implementations)

### Documentation

- **New**: [trouble-audio-sample-rate-mismatch.md](../trouble-audio-sample-rate-mismatch.md) - RCA and fix for sample rate issues
- **Updated**: [_guide-audio-system-impl.md](../implementation/_guide-audio-system-impl.md) - Added Section 5.8: Sample Rate Mismatch Issues

---

## Phase 2: Safety & Scheduling (2025-11-10)

**Tag**: `audio-architecture-phase2-complete`
**Status**: ✅ Complete - Ready for Device Testing

### Added

#### QuietBreakScheduler - Automatic Break Management
- **File**: `Core/Services/Scheduler/QuietBreakScheduler.swift` (new, 204 lines)
- **Feature**: 55min play / 5min break cycle (configurable)
- **Implementation**:
  - `DispatchSourceTimer` with `wallDeadline` for accurate timing
  - Ground truth timing pattern using `Date` as source of truth
  - Sleep/wake drift correction via `UIApplication.willEnterForegroundNotification`
  - Callbacks: `onBreakStart`, `onBreakEnd` for automatic pause/resume
  - Phase tracking: `.idle`, `.playing(startedAt:)`, `.breaking(startedAt:)`

#### SafeVolumeLimiter - Volume Ceiling Protection
- **File**: `Core/Services/Volume/SafeVolumeLimiter.swift` (new, 100 lines)
- **Feature**: User-configurable maximum output level (default: -6dB)
- **Implementation**:
  - iOS-compatible using `AVAudioUnitDistortion` (macOS `AVAudioUnitDynamicsProcessor` not available)
  - Soft clipping with `.multiDecimated4` preset
  - Audio graph: MainMixerNode → SafeVolumeLimiter → OutputNode
  - `isConfigured` flag prevents double-configuration crashes
- **See**: ADR-0002 for iOS compatibility decision rationale

#### Fade Effects - Smooth Transitions
- **File**: `Core/Audio/AudioService.swift` (methods added)
- **Feature**: Smooth fade-in/out on play/pause/resume
- **Implementation**:
  - 60-step timer-based fade (60fps animation)
  - Target volume memory for restoration after fade
  - `DispatchQueue.asyncAfter` coordination with engine stop
  - Swift 6 concurrency: `Task { @MainActor }` in Timer closures

#### Settings UI - Configuration Interface
- **File**: `Features/Settings/Views/AudioSettingsView.swift` (new, 242 lines)
- **Feature**: Comprehensive settings for Phase 1 & 2 features
- **Sections**:
  - Route Safety: Headphone-only mode, auto-resume toggles
  - Quiet Break Schedule: Enable/disable, play/break duration steppers, next break time display
  - Volume Safety: Max output level slider (-12dB to 0dB)
- **Integration**: Settings tab added to ContentView

### Changed

#### AudioService Integration
- **File**: `Core/Audio/AudioService.swift` (+127 lines)
- **Changes**:
  - Initialize `breakScheduler` and `volumeLimiter` in `init()` from `AudioSettings`
  - Configure volume limiter before engine start in `play()`
  - Start/stop break scheduler in `play()`/`stop()`/`resume()`
  - Resume scheduler on `resume()` except for `.quietBreak` reason (scheduler self-manages)
  - Made `breakScheduler` public for Settings UI access
  - Added `.quietBreak` to `PauseReason` enum
- **Callbacks**:
  - `onBreakStart` → `pause(reason: .quietBreak)` (automatic pause)
  - `onBreakEnd` → `resume()` (automatic resume)

#### AudioSettings Schema
- **File**: `Core/Settings/AudioSettings.swift`
- **New fields**:
  - `quietBreakEnabled: Bool` (default: false)
  - `playMinutes: Int` (default: 55)
  - `breakMinutes: Int` (default: 5)
  - `maxOutputDb: Float` (default: -6.0)

### Fixed

#### iOS Compatibility Issue
- **Problem**: `AVAudioUnitDynamicsProcessor` compilation error (macOS-only API)
- **Solution**: Replaced with `AVAudioUnitDistortion` for iOS
- **Impact**: Soft clipping vs true dynamics processor trade-off (acceptable for use case)
- **See**: ADR-0002, Issue 4 in design doc

#### Swift 6 Concurrency Warnings
- **Problem**: MainActor-isolated properties accessed in Sendable closures (Timer callbacks)
- **Solution**: Wrap Timer closure body in `Task { @MainActor [weak self] in }`
- **Files**: `AudioService.swift` (fadeOut, fadeIn methods)

#### Optional Chaining Error
- **Problem**: Incorrect `audioService.breakScheduler?.nextBreakAt` (breakScheduler not optional)
- **Solution**: Changed to `audioService.breakScheduler.nextBreakAt`
- **File**: `AudioSettingsView.swift`

#### UIKit Import Missing
- **Problem**: `UIApplication.willEnterForegroundNotification` requires UIKit
- **Solution**: Added `import UIKit` to `QuietBreakScheduler.swift`

### Commits

1. `e7bc662` - feat: implement Phase 2 audio features - quiet breaks, volume limiting, and fade effects
2. `8d3f9f7` - feat: add Phase 2 settings UI and fix iOS compatibility for volume limiter
3. `3ab933e` - fix: add UIKit import to QuietBreakScheduler for UIApplication access
4. `666f982` - fix: remove incorrect optional chaining for breakScheduler in AudioSettingsView
5. `2be5048` - fix: wrap Timer closures in Task { @MainActor } for Swift 6 concurrency
6. `f0ad0aa` - docs: add Phase 2 implementation report and Issue 4 (iOS compatibility) to design doc

### Testing Status

**Unit Tests**: ⏳ Pending
**Integration Tests**: ⏳ Pending
**Device Tests**: ⏳ **Required before production**

**Critical device tests**:
- [ ] Quiet break cycle (reduced timing: 5min/1min)
- [ ] Sleep/wake drift correction
- [ ] Volume limiter effectiveness
- [ ] Distortion artifacts check
- [ ] Fade smoothness (no clicks)
- [ ] Settings UI immediate effect

### Known Limitations

1. **Volume Limiter Precision**: `AVAudioUnitDistortion` less precise than dynamics processor. May allow brief peaks above threshold.
2. **Fade Granularity**: 60-step fade may be perceptible on very quiet passages. Could increase to 120 steps if needed.
3. **Break Scheduler Accuracy**: `DispatchSourceTimer` can drift ~1-2 seconds over 55 minutes. Recalculation on wake helps but not perfect.
4. **Settings UI - Next Break Display**: Only shows when quiet breaks enabled AND scheduler started (after first play). Shows nil before first playback.

### Deprecations

None in this phase.

### Breaking Changes

**Settings Schema**:
- New fields added to `AudioSettings` (backward compatible - defaults provided)
- Existing settings unaffected

**API Changes**:
- `AudioService.breakScheduler` now public (read-only access)
- No breaking changes to existing methods

---

## Phase 1: Foundation (2025-11-10)

**Tag**: `audio-architecture-phase1-complete`
**Status**: ✅ Complete - Tested on Device

### Added

#### AudioService Singleton
- **File**: `Core/Audio/AudioService.swift` (new, ~280 lines)
- **Feature**: Long-lived audio service surviving screen transitions
- **Implementation**:
  - Singleton pattern with `@StateObject` injection in App
  - Published state: `isPlaying`, `currentPreset`, `outputRoute`, `pauseReason`
  - Methods: `play()`, `stop()`, `pause()`, `resume()`, `setVolume()`, `updateSettings()`
  - Session management (single activation per launch)
  - Interruption handling (phone calls, Siri)
- **See**: ADR-0001 for singleton decision rationale

#### AudioRouteMonitor - Route Detection
- **File**: `Core/Services/Route/AudioRouteMonitor.swift` (new, 187 lines)
- **Feature**: Real-time audio output route detection
- **Implementation**:
  - Detect headphones, Bluetooth, speaker
  - Route change notifications (UI updates)
  - Safety pause callback (headphone→speaker)
  - Start monitoring at app launch (not first playback)

#### AudioSettings - Persisted Configuration
- **File**: `Core/Settings/AudioSettings.swift` (new, ~100 lines)
- **Feature**: UserDefaults-backed settings
- **Fields**:
  - `onlyHeadphoneOutput: Bool` (default: true)
  - `autoResumeAfterInterruption: Bool` (default: true)
- **Methods**: `save()`, `load()`

### Changed

#### App Entry Point
- **File**: `App/clock_tsukiusagiApp.swift`
- **Changes**:
  - Added `@StateObject audioService = AudioService.shared`
  - Injected via `.environmentObject(audioService)` to ContentView

#### LocalAudioEngine
- **File**: `Core/Audio/LocalAudioEngine.swift`
- **Changes**:
  - Removed session activation (delegated to AudioService)
  - Focused on engine lifecycle only

### Fixed

#### Route Detection Timing Issue
- **Problem**: Route showed "Unknown" until first playback
- **Solution**: Start `AudioRouteMonitor` in `AudioService.init()`, not `play()`
- **See**: Issue 3 in design doc

#### Route Change Notification Filtering
- **Problem**: Safety pause triggered on all route changes (Bluetooth connect, etc.)
- **Solution**: Filter by `AVAudioSessionRouteChangeReason.oldDeviceUnavailable`
- **Impact**: Only pause on headphone removal, not other route changes

#### Session Double-Activation
- **Problem**: Session activated in both AudioService and LocalAudioEngine
- **Solution**: Added `sessionActivated` flag, activate once in AudioService
- **Impact**: No more -50 errors from duplicate activation

### Commits

1. `cbab26c` - Implement two-circle analytical moon rendering for perfect First/Third Quarter symmetry
2. `0d024a5` - Astronomical moon phase (UTC) + new MoonPhaseCalculator
3. `65f6377` - feat: improve safe area handling and add tap gesture documentation
4. `4ce2b50` - refactor: restructure visual components into CrossFeatureUI architecture
5. `b03c53b` - fix: improve audio route detection timing and real-time updates
6. `5ca8960` - docs: add Issue 3 (route detection timing) to design doc

### Testing Status

**Device Tests**: ✅ Passed
- Screen transition survival (10+ tab switches)
- Route detection (<1 second latency)
- Safety pause on headphone removal
- Settings persistence across app restart
- 2-hour continuous playback (stable)

### Known Limitations

None identified in Phase 1.

---

## Pre-Architecture (Before 2025-11-10)

**Status**: ⚠️ Deprecated - View-owned audio engines

### Implementation

- View-owned `LocalAudioEngine` instances
- Created in `playAudio()` method
- Destroyed on `onDisappear` or view destruction

### Problems

- Audio stopped on screen transitions
- No app-wide state coordination
- Session activation repeated per screen
- No route monitoring
- No persistent settings

### Migration Path

All View-owned engines replaced with `@EnvironmentObject` AudioService singleton in Phase 1.

---

## Versioning Scheme

**Tags**: `audio-architecture-phase{N}-complete`
- `phase1-complete`: Foundation (singleton, route monitoring)
- `phase2-complete`: Safety & scheduling (breaks, volume limit, fade)
- `phase3-complete`: Future (Live Activity, track player, PiP)

**Semantic Versioning** (future):
- Major: Breaking API changes
- Minor: New features (backward compatible)
- Patch: Bug fixes

---

## Related Documents

- **Architecture Spec**: `../architecture/audio-system-spec.md`
- **Implementation Guide**: `../implementation/_guide-audio-system-impl.md`
- **Operations Runbook**: `../runbook/_runbook-audio-ops-and-tests.md`
- **ADR-0001**: Singleton Pattern (`../architecture/adrs/_adr-0001-audio-service-singleton.md`)
- **ADR-0002**: iOS Volume Limiter (`../architecture/adrs/_adr-0002-safe-volume-ios-alt.md`)

---

**Changelog Maintenance**:
- Update on phase completion
- Document breaking changes prominently
- Link to related ADRs for major decisions
- Include testing status for each phase
