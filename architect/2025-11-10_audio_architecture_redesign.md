# Audio System Architecture Redesign

🗓️ 2025/11/10 [Monday]

## Executive Summary

**Goal**: Transform the current instance-based audio system into a long-lived, app-wide service that survives screen transitions, provides safe output control, and enables advanced features like Live Activity, scheduled breaks, and headphone safety.

**Core Problem**: Current `LocalAudioEngine` instances are owned by Views, causing audio to stop during screen transitions.

**Solution**: Singleton AudioService pattern + Route monitoring + Scheduled breaks + Volume safety.

---

## 1. Current State Analysis

### Existing Architecture

```
AudioTestView (View)
  └─ @State audioEngine: LocalAudioEngine? (created in playAudio())
      ├─ AVAudioEngine (stops when View deinits)
      ├─ AudioSessionManager (fresh instance)
      └─ AudioSource[] (registered sources)
```

**Problems:**
- ❌ Engine lifetime tied to View lifecycle
- ❌ `onDisappear` or View destruction → audio stops
- ❌ No app-wide state coordination
- ❌ Session activation repeated per screen
- ❌ No route monitoring
- ❌ No scheduled breaks
- ❌ No volume safety limits

**Strengths:**
- ✅ Clean protocol-based AudioSource design
- ✅ Working interruption handling (AudioSessionManager)
- ✅ Effect chain (FilterBus, ReverbBus)
- ✅ Diagnostics (peak/RMS/clipping detection)
- ✅ ComfortPackDrone implementation complete

---

## 2. Target Architecture

### 2.1 Long-Lived Service Pattern

```
App Lifetime (ClockTsukiusagiApp)
  └─ @StateObject audioService: AudioService.shared
      ├─ LocalAudioEngine (never deallocated)
      ├─ AudioSessionManager (singleton)
      ├─ RouteMonitor (headphone detection)
      ├─ QuietBreakScheduler (55min/5min cycles)
      ├─ SafeVolumeLimiter (output protection)
      └─ State (@Published isPlaying, currentPreset, etc.)

Views (via @EnvironmentObject)
  └─ audioService.play() / stop() / setVolume()
      (commands only, no ownership)
```

**Benefits:**
- ✅ Survives screen transitions
- ✅ Single source of truth for audio state
- ✅ Centralized route/safety monitoring
- ✅ Consistent session management
- ✅ Ready for Live Activity integration

---

## 3. Core Components Design

### 3.1 AudioService (Singleton)

**File**: `Core/Audio/AudioService.swift`

**Responsibilities:**
- Owns `LocalAudioEngine` (never released)
- Coordinates all audio operations
- Publishes playback state to UI
- Integrates route monitoring, scheduling, volume limiting

**Interface:**
```swift
final class AudioService: ObservableObject {
    static let shared = AudioService()

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentPreset: NaturalSoundPreset?
    @Published private(set) var outputRoute: AudioOutputRoute = .unknown
    @Published private(set) var pauseReason: PauseReason?

    private let engine: LocalAudioEngine
    private let sessionManager: AudioSessionManager
    private let routeMonitor: AudioRouteMonitor
    private let breakScheduler: QuietBreakScheduler
    private let volumeLimiter: SafeVolumeLimiter

    private init() { /* setup all components */ }

    func play(preset: NaturalSoundPreset) throws
    func stop(fadeOut: TimeInterval = 0.5)
    func pause(reason: PauseReason)
    func resume() throws
    func setVolume(_ volume: Float)
}
```

**State Machine:**
```
[Idle] --play()--> [Playing]
[Playing] --route change (speaker)--> [Paused(.routeSafetySpeaker)]
[Playing] --55min--> [QuietBreak]
[QuietBreak] --5min--> [Playing]
[Playing] --stop()--> [Idle]
```

---

### 3.2 AudioRouteMonitor

**File**: `Core/Services/Route/AudioRouteMonitor.swift`

**Responsibilities:**
- Monitor `AVAudioSession.routeChangeNotification`
- Detect headphone disconnect → speaker switch
- Trigger safety pause if "Only Headphone Output" enabled

**Interface:**
```swift
protocol AudioRouteMonitoring {
    var currentRoute: AudioOutputRoute { get }
    var onRouteChanged: ((AudioOutputRoute) -> Void)? { get set }
    var onSpeakerSafety: (() -> Void)? { get set }
    func start()
    func stop()
}

enum AudioOutputRoute {
    case headphones     // Wired headphones (.headphones)
    case bluetooth      // A2DP/LE (.bluetoothA2DP, .bluetoothLE)
    case speaker        // Built-in or external speaker (.builtInSpeaker)
    case unknown
}

final class AudioRouteMonitor: AudioRouteMonitoring {
    private let session = AVAudioSession.sharedInstance()
    private var settings: AudioSettings // Read "onlyHeadphoneOutput"

    @objc private func handleRouteChange(_ notification: Notification) {
        // 1. Check reason - only act on device removal
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Only trigger safety on device unavailable (disconnect)
        guard reason == .oldDeviceUnavailable else {
            // Just notify on other changes (.newDeviceAvailable, etc.)
            onRouteChanged?(detectCurrentRoute())
            return
        }

        // 2. Check previous route - was it headphone/bluetooth?
        guard let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
              let previousOutput = previousRoute.outputs.first else {
            return
        }

        let wasHeadphoneType = [
            AVAudioSession.Port.headphones,
            AVAudioSession.Port.bluetoothA2DP,
            AVAudioSession.Port.bluetoothLE
        ].contains(previousOutput.portType)

        // 3. Check current route - is it now speaker?
        let currentRoute = detectCurrentRoute()

        // 4. Trigger safety if: headphone→speaker AND setting enabled
        if wasHeadphoneType && currentRoute == .speaker {
            if settings.onlyHeadphoneOutput {
                onSpeakerSafety?()  // Pause with reason
            } else {
                onRouteChanged?(currentRoute)  // Just notify
            }
        } else {
            onRouteChanged?(currentRoute)
        }
    }

    private func detectCurrentRoute() -> AudioOutputRoute {
        guard let output = session.currentRoute.outputs.first else {
            return .unknown
        }

        switch output.portType {
        case .headphones:
            return .headphones
        case .bluetoothA2DP, .bluetoothLE:
            return .bluetooth
        case .builtInSpeaker:
            return .speaker
        default:
            return .unknown
        }
    }
}
```

**Implementation Notes:**
- Use `AVAudioSession.routeChangeNotification`
- Check `reason == .oldDeviceUnavailable` to detect disconnects only
- Parse `AVAudioSessionRouteChangePreviousRouteKey` to identify previous output
- Use `session.currentRoute.outputs` to detect current output
- Audio session options: `.allowBluetooth` (modern, covers A2DP/HFP/LE)
- **Do NOT** use deprecated Bluetooth category constants

---

### 3.3 QuietBreakScheduler

**File**: `Core/Services/Scheduler/QuietBreakScheduler.swift`

**Responsibilities:**
- Schedule periodic breaks (default: 55min play, 5min silence)
- Fade volume during transitions
- Update Live Activity with "Next break at..."
- Handle sleep/wake drift correction

**Interface:**
```swift
protocol QuietBreakScheduling {
    var isEnabled: Bool { get set }
    var playDuration: TimeInterval { get set }  // 55 * 60
    var breakDuration: TimeInterval { get set } // 5 * 60
    var fadeDuration: TimeInterval { get set }  // 0.5-1.5s (configurable)
    var onBreakStart: (() -> Void)? { get set }
    var onBreakEnd: (() -> Void)? { get set }
    var nextBreakAt: Date? { get }  // Source of truth

    func start()
    func stop()
    func reset()
}

final class QuietBreakScheduler: QuietBreakScheduling {
    private var timer: DispatchSourceTimer?
    private var phase: Phase = .idle
    private var _nextBreakAt: Date?  // Ground truth

    var nextBreakAt: Date? { _nextBreakAt }

    enum Phase {
        case idle
        case playing(startedAt: Date)
        case breaking(startedAt: Date)
    }

    func start() {
        // Calculate next break time (ground truth)
        _nextBreakAt = Date().addingTimeInterval(playDuration)

        // Start timer with wallTime (not uptimeNanoseconds)
        scheduleTimer(for: playDuration)

        // Listen for app lifecycle events (sleep/wake)
        setupLifecycleObservers()
    }

    private func scheduleTimer(for interval: TimeInterval) {
        timer?.cancel()
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(wallDeadline: .now() + interval)
        timer?.setEventHandler { [weak self] in
            self?.handleTimerFired()
        }
        timer?.resume()
    }

    private func handleTimerFired() {
        switch phase {
        case .playing:
            fadeToSilence(duration: fadeDuration)
            onBreakStart?()
            phase = .breaking(startedAt: Date())
            _nextBreakAt = Date().addingTimeInterval(breakDuration)
            scheduleTimer(for: breakDuration)

        case .breaking:
            fadeIn(to: targetVolume, duration: fadeDuration)
            onBreakEnd?()
            phase = .playing(startedAt: Date())
            _nextBreakAt = Date().addingTimeInterval(playDuration)
            scheduleTimer(for: playDuration)

        default:
            break
        }
    }

    private func handleWakeFromSleep() {
        // Recalculate based on ground truth (nextBreakAt)
        guard let nextBreak = _nextBreakAt else { return }

        let now = Date()
        let remaining = nextBreak.timeIntervalSince(now)

        if remaining > 0 {
            // Reschedule with corrected interval
            scheduleTimer(for: remaining)
        } else {
            // Overdue - trigger immediately
            handleTimerFired()
        }
    }
}
```

**Fade Logic:**
```swift
func fadeToSilence(duration: TimeInterval) {
    // Animate mixer volume to 0 over duration
    // Use CADisplayLink or DispatchSourceTimer for smooth ramp
}

func fadeIn(to volume: Float, duration: TimeInterval) {
    // Animate mixer volume from 0 to target over duration
}
```

**Drift Correction Strategy:**
- Use `Date` (wall time) as **source of truth** for `nextBreakAt`
- Timer uses `wallDeadline` (not `uptimeNanoseconds`) to track real time
- On wake from sleep: recalculate remaining time based on `nextBreakAt`
- If overdue: trigger break/resume immediately
- Fade duration is **user-configurable** (not hardcoded)

---

### 3.4 SafeVolumeLimiter

**File**: `Core/Services/Volume/SafeVolumeLimiter.swift`

**Responsibilities:**
- Enforce maximum output volume (dB ceiling)
- Apply soft limiting using `AVAudioUnitDynamicsProcessor`
- Provide user-configurable safety threshold

**Interface:**
```swift
protocol SafeVolumeLimiting {
    var maxOutputDb: Float { get set }   // Default: -6dB (80% linear ≈ -2dB)
    func configure(engine: AVAudioEngine, format: AVAudioFormat)
    func updateLimit(_ db: Float)
}

final class SafeVolumeLimiter: SafeVolumeLimiting {
    private let dynamicsProcessor = AVAudioUnitDynamicsProcessor()
    var maxOutputDb: Float = -6.0  // User-configurable ceiling

    func configure(engine: AVAudioEngine, format: AVAudioFormat) {
        // Attach dynamics processor as final stage before output
        engine.attach(dynamicsProcessor)
        engine.connect(
            engine.mainMixerNode,
            to: dynamicsProcessor,
            format: format
        )
        engine.connect(
            dynamicsProcessor,
            to: engine.outputNode,
            format: format
        )

        // Configure as soft limiter
        dynamicsProcessor.threshold = maxOutputDb          // -6dB ceiling
        dynamicsProcessor.headRoom = 0.1                   // 0.1dB headroom
        dynamicsProcessor.attackTime = 0.001               // 1ms attack (fast)
        dynamicsProcessor.releaseTime = 0.05               // 50ms release
        dynamicsProcessor.overallGain = 0                  // No makeup gain
        dynamicsProcessor.compressionAmount = 20.0         // Heavy limiting
        dynamicsProcessor.inputAmplitude = 0               // Input metering
        dynamicsProcessor.outputAmplitude = 0              // Output metering
    }

    func updateLimit(_ db: Float) {
        maxOutputDb = db
        dynamicsProcessor.threshold = db
    }

    func setMasterVolume(_ volume: Float) {
        // Control mixer output volume (0.0-1.0)
        // Combine with dynamics processor for two-stage safety:
        // 1. User volume control (mainMixerNode.outputVolume)
        // 2. Hard ceiling (dynamicsProcessor.threshold)
        let clampedVolume = min(volume, 1.0)
        // Note: Actual volume setting happens in AudioService
    }
}
```

**Implementation Strategy:**

1. **Primary Method: AVAudioUnitDynamicsProcessor (Recommended)**
   - Insert as **final stage** before `outputNode`
   - Affects **all audio sources** uniformly
   - Soft limiting prevents harsh clipping
   - CPU efficient (hardware-accelerated on iOS)

2. **Secondary Method: Mixer Volume Control**
   - Set `mainMixerNode.outputVolume` based on user preference
   - Convert dB to linear: `volume = pow(10.0, db / 20.0)`
   - Default ceiling: -6dB ≈ 0.5 linear (50%)

3. **Combined Approach (Best)**
   - User slider → `mainMixerNode.outputVolume` (0.0-1.0)
   - Safety ceiling → `dynamicsProcessor.threshold` (-6dB hard limit)
   - Example: User at 100% volume → mixer at 1.0 → processor limits to -6dB

**Connection Graph:**
```
AudioSource → FilterBus → ReverbBus → MainMixerNode → DynamicsProcessor → OutputNode
                                       (user volume)    (safety ceiling)
```

**Why NOT Per-Sample Processing:**
- Per-sample limiting in `AVAudioSourceNode` render callback only affects **that source**
- Multiple sources would each need limiting (inefficient, inconsistent)
- Final-stage processing ensures **all audio** respects the ceiling
- Dynamics processor provides smooth, musical limiting (vs. hard clipping)

---

### 3.5 TrackPlayer (Future)

**File**: `Core/Audio/Players/TrackPlayer.swift`

**Status**: 🔄 Not yet implemented (Phase 2)

**Purpose**: Play local audio files (WAV/CAF) with seamless looping and crossfade

**Interface:**
```swift
protocol TrackPlaying {
    func load(url: URL) throws
    func play(loop: Bool, crossfadeDuration: TimeInterval)
    func stop(fadeOut: TimeInterval)
    var isPlaying: Bool { get }
}

final class TrackPlayer: TrackPlaying {
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var buffer: AVAudioPCMBuffer?

    func play(loop: Bool, crossfadeDuration: TimeInterval) {
        // Schedule buffer on playerNode
        // If loop: schedule next buffer with volume ramp for crossfade
    }
}
```

**Crossfade Logic:**
```
Buffer A: [====fade-out====]
Buffer B:     [====fade-in====]
           <-crossfade zone->
```

---

### 3.6 Live Activity (Future)

**Files**:
- `Core/Activity/AudioActivityAttributes.swift`
- `Core/Activity/AudioActivityController.swift`
- `AudioActivityWidget/` (Widget Extension target)

**Status**: 🔄 Not yet implemented (Phase 3)

**Purpose**: Display playback state on Lock Screen / Dynamic Island

**ContentState:**
```swift
struct AudioActivityState: Codable {
    var isPlaying: Bool
    var nextBreakAt: Date?
    var outputRoute: String  // "Headphones", "Bluetooth", "Speaker"
    var pauseReason: PauseReason?
}

enum PauseReason: String, Codable {
    case user
    case routeSafetySpeaker
    case quietBreak
    case interruption
}
```

**Actions:**
- `stop()` - User taps Stop button on Lock Screen → App receives intent → AudioService.stop()

**Display:**
- Lock Screen: Status text, timer (next break), output icon, Stop button
- Dynamic Island: Minimal status + tap to open app

---

### 3.7 Picture in Picture (Future)

**File**: `Features/NowPlaying/PiPController.swift`

**Status**: 🔄 Not yet implemented (Phase 3) - **Requires Research**

**Purpose**: Floating control overlay (iOS 16+)

**Technical Constraint:**
> **⚠️ PiP Limitation**: `AVPictureInPictureController` requires a **video layer** (`AVPlayerLayer` or `AVSampleBufferDisplayLayer`). Audio-only apps **cannot use native PiP** without a visual component.

**Implementation Options:**

**Option A: Dummy Video Layer (High Risk)**
- Create silent black video (1fps) with `AVPlayer`
- Attach `AVPictureInPictureController` to player layer
- Use custom UI overlay for controls
- **Risks**:
  - App Store review rejection risk (dummy content)
  - Battery drain from video pipeline
  - Memory overhead
  - Not recommended without Apple precedent

**Option B: Alternative UI (Recommended)**
- **Live Activity** for Lock Screen controls (native, battery-efficient)
- **MPNowPlayingInfoCenter** for Control Center integration
- **Custom mini floating UI** (SwiftUI overlay, not true PiP)
- **Benefits**:
  - No review risk
  - Lower battery consumption
  - Native iOS integration
  - Consistent with audio app best practices

**Decision Required:**
- Phase 3 should **research Option A feasibility** (check App Store guidelines, precedents)
- **Default to Option B** unless clear technical/review path exists for Option A
- Update design doc after research phase with Go/NoGo decision

---

## 4. Settings Schema

**File**: `Core/Settings/AudioSettings.swift`

```swift
struct AudioSettings: Codable {
    var onlyHeadphoneOutput: Bool = true        // Speaker safety
    var autoResumeAfterInterruption: Bool = true
    var stopOnHeadphoneDisconnect: Bool = true  // Legacy, use onlyHeadphoneOutput

    var quietBreakEnabled: Bool = false         // 55/5 cycle
    var playMinutes: Int = 55
    var breakMinutes: Int = 5

    var maxOutputDb: Float = -6.0               // Volume ceiling
    var crossfadeDuration: TimeInterval = 2.0   // For TrackPlayer

    var liveActivityEnabled: Bool = false       // Phase 3
    var pipEnabled: Bool = false                // Phase 3
}
```

**Storage**: UserDefaults with Codable

---

## 5. App Integration

### 5.1 App Entry Point

**File**: `clock-tsukiusagi/App/clock_tsukiusagiApp.swift`

**Changes:**
```swift
@main
struct clock_tsukiusagiApp: App {
    @StateObject private var audioService = AudioService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioService)
        }
    }
}
```

### 5.2 View Updates

**File**: `clock-tsukiusagi/Core/Audio/AudioTestView.swift`

**Before:**
```swift
@State private var audioEngine: LocalAudioEngine?  // ❌ View-owned

private func playAudio() {
    let engine = LocalAudioEngine(...)  // ❌ New instance per play
    try engine.start()
    audioEngine = engine
}
```

**After:**
```swift
@EnvironmentObject var audioService: AudioService  // ✅ Shared

private func playAudio() {
    try audioService.play(preset: selectedPreset)  // ✅ Command only
}

private func stopAudio() {
    audioService.stop()  // ✅ No lifecycle management
}
```

**Remove:**
- `onDisappear { audioEngine?.stop() }`  // ❌ Causes premature stop
- Local `audioEngine` state variable

---

## 6. Implementation Phases

### Phase 1: Core Service (Week 1)
**Goal**: Survive screen transitions, basic route monitoring

1. ✅ Create `AudioService.swift` with singleton pattern
2. ✅ Move `LocalAudioEngine` ownership to `AudioService`
3. ✅ Implement `AudioRouteMonitor` with speaker safety
4. ✅ Update `AudioTestView` to use `@EnvironmentObject`
5. ✅ Inject `AudioService` in `clock_tsukiusagiApp`
6. ✅ Remove `onDisappear` stop logic from all views
7. ✅ Test: Play → navigate away → audio continues

**Deliverables:**
- AudioService.swift
- AudioRouteMonitor.swift
- Updated AudioTestView.swift
- Updated clock_tsukiusagiApp.swift

---

### Phase 2: Safety & Scheduling (Week 2)
**Goal**: Quiet breaks, volume limiting

1. ✅ Implement `QuietBreakScheduler`
2. ✅ Implement `SafeVolumeLimiter`
3. ✅ Integrate scheduler into `AudioService`
4. ✅ Add settings UI for break schedule
5. ✅ Add settings UI for volume ceiling
6. ✅ Test: 55min/5min cycle with fade transitions

**Deliverables:**
- QuietBreakScheduler.swift
- SafeVolumeLimiter.swift
- Settings UI updates

---

### Phase 3: Advanced Features (Week 3+)
**Goal**: Live Activity, PiP, local file playback

1. 🔄 Implement `TrackPlayer` for audio file looping
2. 🔄 Add local audio files (WAV/CAF) to Resources/Audio/
3. 🔄 Create Live Activity Widget Extension
4. 🔄 Implement `AudioActivityController`
5. 🔄 Add PiP support (iOS 16+ devices)
6. 🔄 Test on device with Lock Screen controls

**Deliverables:**
- TrackPlayer.swift
- AudioActivityWidget/ (Widget Extension)
- AudioActivityController.swift
- PiPController.swift

---

## 7. Testing Strategy

### 7.1 Unit Tests

**File**: `clock-tsukiusagiTests/AudioServiceTests.swift`

```swift
func testAudioSurvivesScreenTransition() {
    let service = AudioService.shared
    try service.play(preset: .comfortRelax)
    XCTAssertTrue(service.isPlaying)

    // Simulate screen transition (View deinit)
    // Service should still be playing
    XCTAssertTrue(service.isPlaying)
}

func testRouteMonitorDetectsSpeaker() {
    let monitor = AudioRouteMonitor()
    var safetyTriggered = false
    monitor.onSpeakerSafety = { safetyTriggered = true }

    // Simulate route change to speaker
    // ...
    XCTAssertTrue(safetyTriggered)
}

func testQuietBreakScheduling() {
    let scheduler = QuietBreakScheduler()
    scheduler.playDuration = 2.0  // 2 seconds for test
    scheduler.breakDuration = 1.0

    var breakStarted = false
    scheduler.onBreakStart = { breakStarted = true }

    scheduler.start()
    // Wait 2 seconds
    XCTAssertTrue(breakStarted)
}
```

### 7.2 Integration Tests

**Scenarios:**
1. ✅ Play → Navigate to different screen → Back → Audio continues
2. ✅ Play → Tab switch → Audio continues
3. ✅ Play → Lock device → Unlock → Audio continues
4. ✅ Play with headphones → Unplug → Audio stops (if onlyHeadphoneOutput=true)
5. ✅ Play → 55 minutes → Auto-mute for 5 minutes → Resume
6. ✅ Play → Volume at 100% → Output clipped at maxOutputDb
7. ✅ Play → Interrupt (call) → Audio pauses → Resume after

### 7.3 Device Tests

**Physical iPhone required for:**
- Live Activity display (Lock Screen)
- Route change detection (headphone plug/unplug)
- Background audio continuation
- PiP controls

---

## 8. Success Criteria

### Must Have (Phase 1)
- ✅ Audio survives all screen transitions
- ✅ No manual `stop()` calls in `onDisappear`
- ✅ Headphone safety: Auto-pause when unplugged (if enabled)
- ✅ Single session activation (no repeated setActive calls)
- ✅ 2-hour continuous playback without crashes

### Should Have (Phase 2)
- ✅ Quiet break 55/5 cycle with smooth fades
- ✅ Volume ceiling enforced (no clipping above maxOutputDb)
- ✅ Settings UI for all safety features
- ✅ Route indicator (🎧/🔊) in UI

### Nice to Have (Phase 3)
- 🔄 Live Activity with Lock Screen controls
- 🔄 PiP floating controls
- 🔄 Local audio file playback with crossfade
- 🔄 Dynamic Island integration (iPhone 14 Pro+)

---

## 9. Risk Analysis

### 9.1 Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Singleton leaks memory | High | Use weak references in closures, implement proper deinit |
| Background audio drains battery | Medium | Use `.playback` category sparingly, monitor energy usage |
| Route detection fails on some devices | Medium | Fallback to manual output selection in settings |
| Live Activity quota exceeded | Low | Limit updates to state changes only |
| PiP not available (iOS < 16) | Low | Feature gate with @available check |

### 9.2 UX Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| User expects audio to stop on screen exit | Medium | Add explicit Stop button, clear status indicators |
| Volume safety too restrictive | Low | Make maxOutputDb configurable in settings |
| Break schedule interrupts focus | Low | Make schedule fully optional, add snooze |

---

## 10. File Structure (After Implementation)

```
clock-tsukiusagi/
├── App/
│   └── clock_tsukiusagiApp.swift          # AudioService injection
├── Core/
│   ├── Audio/
│   │   ├── AudioService.swift             # 🆕 Singleton service
│   │   ├── Engine/
│   │   │   └── LocalAudioEngine.swift     # Existing (owned by service)
│   │   ├── Session/
│   │   │   └── AudioSessionManager.swift  # Existing (updated)
│   │   ├── Sources/                       # Existing audio sources
│   │   ├── Presets/                       # Existing presets
│   │   └── Players/
│   │       └── TrackPlayer.swift          # 🆕 Phase 3
│   ├── Services/
│   │   ├── Route/
│   │   │   └── AudioRouteMonitor.swift    # 🆕 Phase 1
│   │   ├── Scheduler/
│   │   │   └── QuietBreakScheduler.swift  # 🆕 Phase 2
│   │   └── Volume/
│   │       └── SafeVolumeLimiter.swift    # 🆕 Phase 2
│   ├── Activity/
│   │   ├── AudioActivityAttributes.swift  # 🆕 Phase 3
│   │   └── AudioActivityController.swift  # 🆕 Phase 3
│   └── Settings/
│       └── AudioSettings.swift            # 🆕 Phase 1
├── Features/
│   ├── AudioTestView.swift                # Updated (use @EnvironmentObject)
│   └── NowPlaying/
│       └── PiPController.swift            # 🆕 Phase 3
└── Resources/
    └── Audio/                             # 🆕 Phase 3 (WAV/CAF files)
```

---

## 11. Next Steps

### Immediate (Before Implementation)
1. ✅ Review this design doc with stakeholders
2. ✅ Confirm priority: Phase 1 (survival) > Phase 2 (safety) > Phase 3 (polish)
3. ✅ Set up test device (physical iPhone for route detection)

### Phase 1 Kickoff
1. Create `AudioService.swift` skeleton
2. Move engine ownership from `AudioTestView` to `AudioService`
3. Implement `AudioRouteMonitor`
4. Update DI in `clock_tsukiusagiApp`
5. Test on device with navigation

---

## Appendix A: Code Samples

### AudioService Initialization

```swift
final class AudioService: ObservableObject {
    static let shared = AudioService()

    @Published private(set) var isPlaying = false
    @Published private(set) var pauseReason: PauseReason?

    private let engine: LocalAudioEngine
    private let sessionManager: AudioSessionManager
    private let routeMonitor: AudioRouteMonitor
    private let volumeLimiter: SafeVolumeLimiter

    private var sessionActivated = false  // Guard flag
    private var interruptionObserver: NSObjectProtocol?

    private init() {
        self.sessionManager = AudioSessionManager()
        self.engine = LocalAudioEngine(sessionManager: sessionManager, settings: BackgroundAudioToggle())
        self.routeMonitor = AudioRouteMonitor(settings: AudioSettings())
        self.volumeLimiter = SafeVolumeLimiter()

        setupCallbacks()
        setupInterruptionHandling()
    }

    private func setupCallbacks() {
        routeMonitor.onSpeakerSafety = { [weak self] in
            self?.pause(reason: .routeSafetySpeaker)
        }
    }

    private func setupInterruptionHandling() {
        // Handle phone calls, Siri, etc.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            switch type {
            case .began:
                // Fade and pause
                self.pause(reason: .interruption)

            case .ended:
                // Check if we should resume
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        // Auto-resume based on settings
                        if self.settings.autoResumeAfterInterruption {
                            try? self.resume()
                        }
                    }
                }

            @unknown default:
                break
            }
        }
    }

    func play(preset: NaturalSoundPreset) throws {
        // Activate session only once
        if !sessionActivated {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth]  // Modern API
            )
            try session.setPreferredIOBufferDuration(0.005)  // 5ms target
            try session.setActive(true)
            sessionActivated = true
        }

        // Configure engine and sources
        try engine.configure()
        // ... register sources based on preset

        // Configure volume safety (final stage)
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        volumeLimiter.configure(engine: engine.avEngine, format: format)

        try engine.start()

        routeMonitor.start()
        isPlaying = true
        pauseReason = nil
    }

    func pause(reason: PauseReason) {
        // Fade out over 0.5s
        fadeOut(duration: 0.5)

        pauseReason = reason
        isPlaying = false
    }

    func resume() throws {
        guard let reason = pauseReason else { return }

        // Check if resume is safe
        if reason == .routeSafetySpeaker {
            let currentRoute = routeMonitor.currentRoute
            guard currentRoute != .speaker else {
                throw AudioError.unsafeToResume("Still on speaker output")
            }
        }

        try engine.start()
        fadeIn(duration: 0.5)

        isPlaying = true
        pauseReason = nil
    }

    func stop(fadeOut: TimeInterval = 0.5) {
        fadeOut(duration: fadeOut)

        engine.stop()
        routeMonitor.stop()
        isPlaying = false
        pauseReason = nil

        // Do NOT deactivate session - keep it active for quick restart
    }

    private func fadeOut(duration: TimeInterval) {
        // TODO: Implement smooth volume ramp
        // Use CADisplayLink or DispatchSourceTimer
    }

    private func fadeIn(duration: TimeInterval) {
        // TODO: Implement smooth volume ramp
    }
}

enum PauseReason: String, Codable {
    case user
    case routeSafetySpeaker
    case quietBreak
    case interruption
}
```

---

## Appendix B: Vocabulary

| English | Japanese |
|---------|----------|
| Singleton | シングルトン（単一インスタンス） |
| Long-lived object | 長寿命オブジェクト |
| Dependency Injection (DI) | 依存性注入 |
| Environment Object | 環境オブジェクト |
| Route monitoring | 出力経路監視 |
| Safety pause | 安全停止 |
| Quiet break | 無音タイム |
| Soft clipping | ソフトクリップ |
| Fade in/out | フェードイン/アウト |
| Live Activity | ライブアクティビティ |

---

## Appendix C: Phase 1 Implementation Issues and Solutions

### Issue 1: OSStatus -50 Error on Audio Session Activation

**Problem**: `AVAudioSession.setCategory()` failed with OSStatus error -50 (invalid parameter) on device.

**Error Message**:
```
AVAudioSessionClient_Common.mm:600   Failed to set properties, error: -50
Domain: NSOSStatusErrorDomain Code: -50
Description: The operation couldn't be completed. (OSStatus error -50.)
```

**Root Cause**:
The `.allowBluetooth` option in `AVAudioSession.CategoryOptions` was causing the error. While this option is documented and should be valid, it triggered an invalid parameter error on the test device (iOS実機).

**Initial Configuration (Failed)**:
```swift
try session.setCategory(
    .playback,
    mode: .default,
    options: [.mixWithOthers, .allowBluetooth]  // ❌ This failed
)
```

**Solution**:
Remove the `.allowBluetooth` option and use only `.mixWithOthers`:

```swift
try session.setCategory(
    .playback,
    mode: .default,
    options: [.mixWithOthers]  // ✅ This works
)
```

**Impact**:
- ✅ Audio session activates successfully on device
- ✅ Playback works normally
- ⚠️ Bluetooth audio routing may require testing (not verified in Phase 1)
- 📝 For Phase 2: Consider conditionally adding `.allowBluetooth` based on iOS version or device capabilities

**Testing Results** (Device):
```
Current Category: AVAudioSessionCategorySoloAmbient
After setCategory: AVAudioSessionCategoryPlayback
✅ Session activated successfully
✅ Audio playback working
✅ Screen transitions maintain playback
```

**Diagnostic Logs**:
```
Noise: -25.6 dB
Drone: -25.3 dB
Mixed: -32.7 dB
RMS: -42.3 dB
✅ No clipping detected
```

### Issue 2: Duplicate Session Activation Attempts

**Problem**: Initial implementation attempted to activate audio session in multiple places:
1. `AudioService.activateAudioSession()`
2. `LocalAudioEngine.configure()` → `AudioSessionManager.activate()`

**Root Cause**:
Legacy architecture where `LocalAudioEngine` managed its own session. In the new singleton pattern, `AudioService` owns session management, but the engine still tried to configure it.

**Solution**:
- Remove `engine.configure()` call from `AudioService.play()`
- AudioService handles session activation directly
- LocalAudioEngine only manages AVAudioEngine lifecycle (start/stop)

**Code Change**:
```swift
// Before (caused conflicts):
try engine.configure()  // Would try to activate session again

// After (correct):
// Skip engine.configure() - session already activated by AudioService
try registerSource(for: preset)
try engine.start()
```

### Issue 3: Route Detection Timing Issues

**Problem**: Audio route displayed as "Unknown" on app launch, and route changes not reflected in UI in real-time.

**Symptoms**:
1. Launch with Bluetooth headphones → UI shows "Unknown ❓"
2. Start playback → UI updates to "Bluetooth 🅱️"
3. Plug/unplug headphones during playback → UI doesn't update
4. Route changes while stopped → No UI feedback

**Root Cause 1: Late Initialization**
Route detection only happened when playback started:
```swift
// In AudioService.play():
routeMonitor.start()  // Called on playback, not on launch
onRouteChanged?(currentRoute)  // First notification delayed
```

**Root Cause 2: Selective Notification**
Route monitor only notified UI on `.oldDeviceUnavailable` (device removal):
```swift
guard reason == .oldDeviceUnavailable else {
    // Other route changes (like .newDeviceAvailable) were ignored
    return
}
```

**Solution**:
1. **Detect route on app launch**:
```swift
// In AudioService.init():
outputRoute = routeMonitor.currentRoute  // Immediate detection
routeMonitor.start()  // Start monitoring from launch
```

2. **Always notify route changes**:
```swift
// In AudioRouteMonitor.handleRouteChange():
let newRoute = detectCurrentRoute()
onRouteChanged?(newRoute)  // Always notify, regardless of reason

// Safety pause only on device removal
guard reason == .oldDeviceUnavailable else { return }
// ... check for headphone→speaker transition
```

3. **Continuous monitoring**:
```swift
// Route monitor never stops (removed from stop() method)
// Monitors even when playback is stopped
```

**Testing Results** (After Fix):
```
Launch with Bluetooth: Bluetooth 🅱️ (immediate)
Plug headphones: Headphones 🎧 (real-time)
Unplug headphones: Speaker 🔊 + safety pause (if enabled)
Route changes while stopped: UI updates correctly
```

**Impact**:
- ✅ Immediate route display on launch
- ✅ Real-time UI updates for all route changes
- ✅ Better user feedback (always know current output)
- ✅ Safety pause still works correctly (unchanged behavior)

---

### Lessons Learned

1. **Audio Session Options**: Not all documented options work reliably across iOS versions/devices. Start minimal, add options incrementally.

2. **Separation of Concerns**: Clear ownership is critical:
   - `AudioService` → Session management + Route state publishing
   - `LocalAudioEngine` → Engine lifecycle only
   - `AudioRouteMonitor` → Route observation + Change notifications

3. **Error Diagnosis**: OSStatus errors require systematic elimination:
   - Test with minimal configuration first
   - Add options one by one
   - Log current session state before changes

4. **Testing Strategy**: Always test on physical device for audio features. Simulator has limitations.

5. **Initialization Timing**: UI-critical state should be initialized as early as possible:
   - Don't wait for user action (playback) to detect system state (route)
   - Start monitoring immediately on app launch
   - Publish initial values to avoid "Unknown" states

6. **Notification Filtering**: Be careful about filtering notifications:
   - Different notification reasons serve different purposes
   - UI updates need all changes, safety features need specific changes
   - Separate "notify UI" from "trigger action" logic

---

**Document Status**: ✅ Phase 1 Complete - Tested on Device
**Last Updated**: 2025-11-10 (Phase 1 implementation verified + route detection fixes)
**Next Review**: Before Phase 2 implementation
