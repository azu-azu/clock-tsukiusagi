# Audio System Changelog

**Module**: Audio System (Core/Audio, Core/Services, Features/Settings)
**Current Version**: Phase 2 Complete
**Last Updated**: 2025-11-10

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
