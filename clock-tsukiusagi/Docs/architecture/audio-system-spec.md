# Audio System Architecture Specification

**Version**: 2.1
**Status**: Phase 2 Complete + 3-Layer Architecture
**Last Updated**: 2025-11-23
**Related Tags**: `audio-architecture-phase1-complete`, `audio-architecture-phase2-complete`, `3-layer-architecture`

---

## 1. Executive Summary

### Purpose
Transform the current instance-based audio system into a long-lived, app-wide service that survives screen transitions, provides safe output control, and enables advanced features like scheduled breaks and headphone safety.

### Core Problem
Current `LocalAudioEngine` instances are owned by Views, causing audio to stop during screen transitions.

### Solution
Singleton AudioService pattern with route monitoring, scheduled breaks, and volume safety.

---

## 2. Design Principles

### 2.1 Long-Lived Service Pattern
- **Single source of truth**: One AudioService instance for entire app lifetime
- **View independence**: Audio playback continues regardless of UI state
- **State publishing**: Views observe service state via `@Published` properties
- **Command pattern**: Views send commands (`play()`, `stop()`), don't own lifecycle

### 2.2 Safety-First Design
- **Route monitoring**: Continuous detection of audio output changes
- **Automatic protection**: Pause on headphone removal (configurable)
- **Volume ceiling**: User-configurable maximum output level
- **Scheduled breaks**: Automatic quiet periods to prevent continuous exposure

### 2.3 Separation of Concerns
Clear ownership boundaries:
- `AudioService` → Session management + State publishing
- `LocalAudioEngine` → Engine lifecycle only
- `AudioRouteMonitor` → Route observation + Change notifications
- `QuietBreakScheduler` → Break timing + Phase management
- `SafeVolumeLimiter` → Output volume protection

---

## 3. System Architecture

### 3.1 Component Hierarchy

```
App Lifetime (ClockTsukiusagiApp)
  └─ @StateObject audioService: AudioService.shared
      ├─ LocalAudioEngine (never deallocated)
      ├─ AudioSessionManager (singleton)
      ├─ AudioRouteMonitor (headphone detection)
      ├─ QuietBreakScheduler (55min/5min cycles)
      ├─ SafeVolumeLimiter (output protection)
      └─ State (@Published isPlaying, currentPreset, etc.)

Views (via @EnvironmentObject)
  └─ audioService.play() / stop() / setVolume()
      (commands only, no ownership)
```

### 3.2 State Machine

#### Playback States
```
┌─────────┐  play()   ┌─────────┐  stop()   ┌─────────┐
│  Idle   │ ───────> │ Playing │ ───────> │  Idle   │
└─────────┘           └─────────┘           └─────────┘
                           │
                    pause(reason)
                           │
                           v
                      ┌─────────┐  resume()
                      │ Paused  │ ─────────> (back to Playing)
                      └─────────┘

Pause Reasons:
- .user: User-initiated pause
- .routeSafetySpeaker: Headphone removed → speaker (safety pause)
- .quietBreak: Scheduled break (auto-pause/resume)
- .interruption: System interruption (phone call, Siri)
```

#### Route Detection States
```
┌─────────┐  detect   ┌─────────────┐
│ Unknown │ ───────> │ Headphones  │ ──┐
└─────────┘           └─────────────┘   │
                                        │ user changes
                      ┌─────────────┐   │
                      │  Bluetooth  │ <─┤
                      └─────────────┘   │
                                        │
                      ┌─────────────┐   │
                      │   Speaker   │ <─┘
                      └─────────────┘
                           │
                    oldDeviceUnavailable
                           │
                           v
                   Safety Pause (if enabled)
```

#### Break Scheduler States
```
┌──────┐  start()   ┌──────────┐  55min   ┌──────────┐
│ Idle │ ────────> │ Playing  │ ──────> │ Breaking │
└──────┘            └──────────┘          └──────────┘
                         ^                      │
                         │        5min          │
                         └──────────────────────┘
```

### 3.3 Audio Graph

```
[ComfortPackDrone Source]
         │
         v
    [FilterBus]
         │
         v
    [ReverbBus]
         │
         v
  [MainMixerNode]
         │
         v
 [SafeVolumeLimiter] ← User-configurable ceiling
         │
         v
   [OutputNode] → Headphones/Speaker
```

---

## 4. Public Interfaces

### 4.1 AudioService

```swift
@MainActor
public final class AudioService: ObservableObject {
    // Singleton
    public static let shared: AudioService

    // Published State
    @Published public private(set) var isPlaying: Bool
    @Published public private(set) var currentPreset: UISoundPreset?
    @Published public private(set) var outputRoute: AudioOutputRoute
    @Published public private(set) var pauseReason: PauseReason?

    // Public Access (Read-only)
    public let breakScheduler: QuietBreakScheduler

    // Commands
    public func play(preset: UISoundPreset) throws
    public func stop(fadeOut: TimeInterval = 0.5)
    public func pause(reason: PauseReason)
    public func resume() throws
    public func setVolume(_ volume: Float)
    public func updateSettings(_ settings: AudioSettings)
}
```

### 4.2 AudioRouteMonitor

```swift
public final class AudioRouteMonitor: AudioRouteMonitoring {
    public var currentRoute: AudioOutputRoute { get }
    public var onRouteChanged: ((AudioOutputRoute) -> Void)? { get set }
    public var onSpeakerSafety: (() -> Void)? { get set }

    public func start()
    public func stop()
}
```

### 4.3 QuietBreakScheduler

```swift
public final class QuietBreakScheduler: QuietBreakScheduling {
    public var isEnabled: Bool { get set }
    public var playDuration: TimeInterval { get set }
    public var breakDuration: TimeInterval { get set }
    public var nextBreakAt: Date? { get }
    public var onBreakStart: (() -> Void)? { get set }
    public var onBreakEnd: (() -> Void)? { get set }

    public func start()
    public func stop()
    public func reset()
}
```

### 4.4 SafeVolumeLimiter

```swift
public final class SafeVolumeLimiter: SafeVolumeLimiting {
    public var maxOutputDb: Float { get set }

    public func configure(engine: AVAudioEngine, format: AVAudioFormat)
    public func updateLimit(_ db: Float)
}
```

---

## 5. Phase Implementation Plan

### Phase 1: Foundation ✅ Complete
**Goal**: Long-lived service that survives screen transitions

**Deliverables**:
- Singleton AudioService with app-wide lifetime
- Screen transition survival (tab switch, navigation, lock screen)
- Audio route monitoring with real-time UI updates
- Safety pause on headphone removal (configurable)

**Success Criteria (DoD)**:
- [ ] Audio continues during screen transitions
- [ ] No `onDisappear` stops playback
- [ ] No session double-activation
- [ ] Route changes update UI in real-time
- [ ] Safety pause triggers correctly on headphone removal
- [ ] Settings persist across app launches

**Tag**: `audio-architecture-phase1-complete`

### Phase 2: Safety & Scheduling ✅ Complete
**Goal**: Scheduled breaks + Volume safety + Smooth transitions

**Deliverables**:
- QuietBreakScheduler (55min play / 5min break with drift correction)
- SafeVolumeLimiter (iOS-compatible volume ceiling)
- Fade in/out effects (smooth transitions)
- Settings UI for all Phase 2 features

**Success Criteria (DoD)**:
- [ ] Break scheduler triggers at correct intervals (within ±2 seconds)
- [ ] Sleep/wake recalculation prevents drift
- [ ] Volume limiter prevents clipping above threshold
- [ ] Fade effects smooth (no audible clicks)
- [ ] Settings changes apply immediately
- [ ] Next break time displays in Settings UI

**Tag**: `audio-architecture-phase2-complete`

### Phase 3: Advanced Features (Future)
**Goal**: Live Activity + Track Player + Picture-in-Picture

**Deliverables**:
- Live Activity with playback controls
- Track player with file-based audio
- Seamless crossfade between tracks
- Picture-in-Picture support (conditional)

**Success Criteria (DoD)**:
- [ ] Live Activity shows current state + controls work
- [ ] Track transitions have no gaps or clicks
- [ ] Crossfade duration configurable
- [ ] PiP decision documented in ADR (Go/No-Go)

**Tag**: TBD (after Phase 3 completion)

---

## 6. Constraints & Assumptions

### 6.1 Platform Requirements
- **iOS 17.0+**: Required for Live Activity (Phase 3)
- **Device testing required**: Simulator has audio limitations
- **Physical headphones needed**: For route detection testing

### 6.2 Technical Constraints
- **Single audio session**: No simultaneous sessions allowed
- **Main thread operations**: AVAudioSession requires main queue
- **Memory management**: Singleton persists for app lifetime (acceptable trade-off)

### 6.3 Design Assumptions
- **Primary use case**: Long-duration ambient sound playback
- **User behavior**: Headphone use preferred for safety/privacy
- **Content type**: Synthesized drones (smooth, no sharp transients)
- **Break compliance**: User wants automatic health breaks

---

## 7. Non-Goals (Out of Scope)

### Phase 1-2 Exclusions
- ❌ Multiple simultaneous audio sources
- ❌ Recording functionality
- ❌ Audio file playback (deferred to Phase 3)
- ❌ Background audio notifications (handled by Live Activity in Phase 3)
- ❌ Custom DSP beyond volume limiting
- ❌ Spatial audio / 3D positioning

### Future Considerations
- Custom dynamics processor (if AVAudioUnitDistortion insufficient)
- User-adjustable fade duration
- Break scheduler pause/resume (manual override)
- Multiple break schedules (work mode, sleep mode, etc.)

---

## 8. Success Metrics

### Phase 1 Validation
- Audio continues through 10+ tab switches without interruption
- Route UI updates within 1 second of change
- No crashes after 2-hour continuous playback
- Session activation logs show single activation per launch

### Phase 2 Validation
- Break scheduler accurate within ±2 seconds over 4-hour test
- Volume limiter prevents peaks >0.5dB above threshold
- Fade transitions perceived as smooth (subjective test)
- Settings changes reflected in <1 second

### Overall Quality Gates
- Zero crashes in 24-hour soak test
- <100MB memory growth over 8 hours
- All route transitions handled gracefully
- User settings persist correctly across force-quit

---

## 9. Related Documentation

### Implementation Details
- **Implementation Guide**: `clock-tsukiusagi/Docs/implementation/audio-system-impl-guide.md`
- **Operations Runbook**: `clock-tsukiusagi/Docs/runbook/audio-ops-and-test-runbook.md`

### Decision Records
- **ADR-0001**: Audio Service Singleton Pattern (`architecture/adrs/ADR-0001-audio-service-singleton.md`)
- **ADR-0002**: iOS Volume Limiter Alternative (`architecture/adrs/ADR-0002-safe-volume-ios-alt.md`)

### Change History
- **Changelog**: `clock-tsukiusagi/Docs/changelog/audio-changelog.md`

### Original Design Document
- **Full Design**: `/Users/mypc/AI_develop/clock-tsukiusagi/architect/2025-11-10_audio_architecture_redesign.md`
  - Contains detailed implementation reports and historical context
  - Retained for reference, superseded by this spec for current architecture

---

## 10. Glossary

| Term | Definition |
|------|------------|
| **AudioService** | Singleton managing app-wide audio state and lifecycle |
| **Route** | Audio output path (headphones, Bluetooth, speaker) |
| **Safety Pause** | Automatic pause when headphones removed (prevents speaker output) |
| **Quiet Break** | Scheduled silent period (default: 5 min every hour) |
| **Drift Correction** | Recalculating timer based on wall-clock time after sleep/wake |
| **Ground Truth** | Using `Date` as authoritative time source (not timer intervals) |
| **Fade** | Gradual volume change to prevent audible clicks |
| **DoD** | Definition of Done (success criteria for phase completion) |

---

## 11. Changelog

| Date | Version | Change |
|------|---------|--------|
| 2025-11-10 | 2.0 | Phase 2 specification complete (safety features) |
| 2025-11-23 | 2.1 | Updated AudioService API to use UISoundPreset (3-layer architecture) |

---

**Document Status**: ✅ Phase 2 Specification Complete + 3-Layer Architecture
**Next Review**: Before Phase 3 implementation
**Owner**: Audio Architecture Team
