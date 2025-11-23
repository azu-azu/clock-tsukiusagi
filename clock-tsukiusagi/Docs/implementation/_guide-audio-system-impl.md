# Audio System Implementation Guide

**Version**: 2.1 (Phase 2 + 3-Layer Architecture)
**Last Updated**: 2025-11-23
**Target Audience**: Developers implementing or maintaining audio features
**Prerequisites**: Read `../architecture/audio-system-spec.md` first

---

## Overview

This guide provides practical implementation details for the audio system architecture. It focuses on:
- **How to build** each component correctly
- **Common pitfalls** and how to avoid them
- **Code snippets** ready to use
- **Verification steps** to ensure correct implementation

For **why** decisions were made, see ADRs in `../architecture/adrs/`.
For **testing procedures**, see `../runbook/_runbook-audio-ops-and-tests.md`.

---

## Table of Contents

1. [Directory Structure](#1-directory-structure)
2. [Setup & Dependencies](#2-setup--dependencies)
3. [Core Components](#3-core-components)
4. [Implementation How-Tos](#4-implementation-how-tos)
5. [Pitfalls & Fixes](#5-pitfalls--fixes)
6. [Code Snippets](#6-code-snippets)
7. [Verification](#7-verification)

---

## 1. Directory Structure

```
clock-tsukiusagi/
├── Core/
│   ├── Audio/
│   │   ├── AudioService.swift              # Singleton service
│   │   ├── LocalAudioEngine.swift          # Engine wrapper
│   │   └── AudioSessionManager.swift       # Session management
│   ├── Services/
│   │   ├── Route/
│   │   │   └── AudioRouteMonitor.swift     # Route detection
│   │   ├── Scheduler/
│   │   │   └── QuietBreakScheduler.swift   # Break scheduling
│   │   └── Volume/
│   │       └── SafeVolumeLimiter.swift     # Volume ceiling
│   └── Settings/
│       └── AudioSettings.swift             # Persisted settings
├── Features/
│   ├── Settings/
│   │   └── Views/
│   │       └── AudioSettingsView.swift     # Settings UI
│   └── [Other features...]
└── App/
    ├── clock_tsukiusagiApp.swift           # App entry point
    └── ContentView.swift                   # Root view
```

---

## 2. Setup & Dependencies

### 2.1 Required Imports

```swift
// For audio core
import AVFoundation
import Foundation

// For UI components
import SwiftUI

// For lifecycle notifications
import UIKit  // Required for UIApplication notifications
```

**Critical**: Forgetting `import UIKit` in QuietBreakScheduler causes compilation error:
```
Cannot find 'UIApplication' in scope
```

### 2.2 Initialization Order

**Correct sequence** (enforced by App structure):

```swift
@main
struct clock_tsukiusagiApp: App {
    // 1. Create AudioService singleton (once)
    @StateObject private var audioService = AudioService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 2. Inject into environment (available to all Views)
                .environmentObject(audioService)
        }
    }
}
```

**Why this order**:
- `@StateObject` ensures single instance creation
- `.environmentObject()` makes service available app-wide
- AudioService.init() runs before any View accesses it

---

## 3. Core Components

### 3.1 AudioService (Singleton)

**Responsibilities**:
- Manage audio engine lifecycle
- Publish playback state to UI
- Coordinate route monitoring
- Manage break scheduler
- Apply volume limiting

**Key implementation points**:

```swift
@MainActor
public final class AudioService: ObservableObject {
    // Singleton instance
    public static let shared = AudioService()

    // Published state (UI observes these)
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentPreset: NaturalSoundPreset?
    @Published public private(set) var outputRoute: AudioOutputRoute = .unknown
    @Published public private(set) var pauseReason: PauseReason?

    // Components
    private let engine: LocalAudioEngine
    private let sessionManager: AudioSessionManager
    private let routeMonitor: AudioRouteMonitor
    public let breakScheduler: QuietBreakScheduler  // Public for Settings UI
    private let volumeLimiter: SafeVolumeLimiter

    // State flags
    private var sessionActivated = false  // Prevent double-activation

    private init() {
        // Load settings
        self.settings = AudioSettings.load()

        // Initialize components
        self.sessionManager = AudioSessionManager()
        self.engine = LocalAudioEngine(...)
        self.routeMonitor = AudioRouteMonitor(settings: settings)
        self.breakScheduler = QuietBreakScheduler(...)
        self.volumeLimiter = SafeVolumeLimiter(...)

        // Setup callbacks
        setupCallbacks()
        setupInterruptionHandling()
        setupBreakSchedulerCallbacks()

        // Start route monitoring IMMEDIATELY (don't wait for playback)
        outputRoute = routeMonitor.currentRoute
        routeMonitor.start()  // ← Critical: Start at launch, not in play()
    }
}
```

**Critical**: Route monitoring must start in `init()`, not in `play()`. Otherwise UI shows "Unknown" until first playback.

### 3.2 AudioRouteMonitor

**Responsibilities**:
- Detect current audio output route
- Notify on route changes
- Trigger safety pause on headphone removal

**Key implementation points**:

```swift
public final class AudioRouteMonitor: AudioRouteMonitoring {
    public var onRouteChanged: ((AudioOutputRoute) -> Void)?
    public var onSpeakerSafety: (() -> Void)?

    @objc private func handleRouteChange(_ notification: Notification) {
        // 1. Always detect current route
        let newRoute = detectCurrentRoute()

        // 2. ALWAYS notify UI (real-time updates)
        onRouteChanged?(newRoute)

        // 3. Safety pause ONLY on device removal
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let changeReason = AVAudioSession.RouteChangeReason(rawValue: reason),
              changeReason == .oldDeviceUnavailable else {
            return  // Not a device removal, skip safety check
        }

        // 4. Check if previous route was headphone-type
        guard let previousRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
              let previousOutput = previousRoute.outputs.first else {
            return
        }

        let wasHeadphoneType = [
            AVAudioSession.Port.headphones,
            AVAudioSession.Port.bluetoothA2DP,
            AVAudioSession.Port.bluetoothLE
        ].contains(previousOutput.portType)

        // 5. Trigger safety pause if headphone→speaker AND setting enabled
        if wasHeadphoneType && newRoute == .speaker {
            if settings.onlyHeadphoneOutput {
                onSpeakerSafety?()
            }
        }
    }
}
```

**Why separate UI updates from safety actions**:
- UI needs all route changes (Bluetooth→headphones, speaker→Bluetooth, etc.)
- Safety pause only triggers on specific scenario (headphone→speaker removal)

### 3.3 QuietBreakScheduler

**Responsibilities**:
- Schedule breaks (55min play / 5min break)
- Correct timer drift after sleep/wake
- Trigger automatic pause/resume

**Key implementation points**:

```swift
public final class QuietBreakScheduler: QuietBreakScheduling {
    // Ground truth (wall-clock time)
    private var _nextBreakAt: Date?  // ← Date is source of truth, not timer interval

    // Timer
    private var timer: DispatchSourceTimer?

    // Phase tracking
    private enum Phase {
        case idle
        case playing(startedAt: Date)
        case breaking(startedAt: Date)
    }

    private func scheduleTimer(for interval: TimeInterval) {
        let newTimer = DispatchSource.makeTimerSource(queue: .main)
        newTimer.schedule(wallDeadline: .now() + interval)  // ← wallDeadline, NOT uptimeNanoseconds
        newTimer.setEventHandler { [weak self] in
            self?.handleTimerFired()
        }
        newTimer.resume()
        timer = newTimer
    }

    public func start() {
        guard isEnabled else { return }

        // Calculate next break time (ground truth)
        let now = Date()
        _nextBreakAt = now.addingTimeInterval(playDuration)

        // Schedule timer
        scheduleTimer(for: playDuration)
        phase = .playing(startedAt: now)
    }

    private func handleWakeFromSleep() {
        guard let nextBreak = _nextBreakAt else { return }

        let now = Date()
        let remaining = nextBreak.timeIntervalSince(now)

        if remaining > 0 {
            // Recalculate timer from ground truth
            scheduleTimer(for: remaining)
        } else {
            // Overdue - trigger immediately
            handleTimerFired()
        }
    }
}
```

**Why wallDeadline**: `wallDeadline` uses real-world clock, survives device sleep. `uptimeNanoseconds` pauses during sleep → timer drift.

**Why Date ground truth**: Timer intervals accumulate error. Always recalculate from `Date` after sleep/wake.

### 3.4 SafeVolumeLimiter

**Responsibilities**:
- Limit output volume to user-defined ceiling
- Prevent hearing damage during long sessions
- iOS-compatible implementation

**Key implementation points**:

```swift
public final class SafeVolumeLimiter: SafeVolumeLimiting {
    private let limiterNode = AVAudioUnitDistortion()  // iOS-compatible
    private var isConfigured = false  // ← Prevent double-attach

    public func configure(engine: AVAudioEngine, format: AVAudioFormat) {
        guard !isConfigured else { return }  // ← Critical: Skip if already configured

        // Attach limiter node
        engine.attach(limiterNode)

        // Connect: MainMixerNode → Limiter → OutputNode
        engine.connect(engine.mainMixerNode, to: limiterNode, format: format)
        engine.connect(limiterNode, to: engine.outputNode, format: format)

        // Configure soft limiter
        limiterNode.loadFactoryPreset(.multiDecimated4)  // Soft clipping
        limiterNode.preGain = maxOutputDb                // -6dB default
        limiterNode.wetDryMix = 100                      // Full processing

        isConfigured = true
    }
}
```

**Why isConfigured flag**: `configure()` called in `play()` method. Without flag, multiple plays attempt to re-attach node → crash.

**Why AVAudioUnitDistortion**: `AVAudioUnitDynamicsProcessor` is macOS-only. Distortion provides soft clipping on iOS. (See ADR-0002)

---

## 4. Implementation How-Tos

### 4.1 How to Implement Playback Flow

```swift
public func play(preset: UISoundPreset) throws {
    // 1. Activate session (once per launch)
    if !sessionActivated {
        try activateAudioSession()
        sessionActivated = true
    }

    // 2. Register audio source (UI preset is mapped to technical preset internally)
    try registerSource(for: preset)

    // 3. Set initial volume
    engine.setMasterVolume(0.5)

    // 4. Configure volume limiter (before engine starts)
    let format = engine.engine.outputNode.inputFormat(forBus: 0)
    volumeLimiter.configure(engine: engine.engine, format: format)

    // 5. Start engine
    try engine.start()

    // 6. Start break scheduler
    breakScheduler.start()

    // 7. Update state
    isPlaying = true
    currentPreset = preset
    pauseReason = nil
    outputRoute = routeMonitor.currentRoute
}

// Internal: Map UI preset to technical preset
private func registerSource(for uiPreset: UISoundPreset) throws {
    // Try PureTone first
    if let pureTonePreset = mapToPureTone(uiPreset) {
        let sources = PureToneBuilder.build(pureTonePreset)
        sources.forEach { engine.register($0) }
        return
    }

    // Try NaturalSound
    guard let naturalPreset = mapToNaturalSound(uiPreset) else {
        return
    }

    let mixerOutput = signalBuilder.makeMixerOutput(for: naturalPreset)
    engine.register(mixerOutput)
}
```

### 4.2 How to Implement Stop with Fade

```swift
public func stop(fadeOut fadeOutDuration: TimeInterval = 0.5) {
    // 1. Start fade-out
    fadeOut(duration: fadeOutDuration)

    // 2. Wait for fade to complete, THEN stop engine
    DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) { [weak self] in
        self?.engine.stop()
    }

    // 3. Stop break scheduler
    breakScheduler.stop()

    // 4. Update state (immediately, don't wait for fade)
    isPlaying = false
    currentPreset = nil
    pauseReason = nil
}
```

**Why asyncAfter**: Engine must keep running during fade. Stopping immediately cuts off fade.

### 4.3 How to Implement Fade Effects

```swift
private var fadeTimer: Timer?
private var targetVolume: Float = 0.5

private func fadeOut(duration: TimeInterval) {
    fadeTimer?.invalidate()

    let startVolume = engine.engine.mainMixerNode.outputVolume
    targetVolume = startVolume  // ← Remember original volume

    let steps = 60  // 60fps animation
    let stepDuration = duration / Double(steps)
    let volumeStep = startVolume / Float(steps)

    var currentStep = 0

    fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
        guard let self = self else {
            timer.invalidate()
            return
        }

        // Wrap in Task for Swift 6 concurrency
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            currentStep += 1
            let newVolume = max(0.0, startVolume - (volumeStep * Float(currentStep)))
            self.engine.setMasterVolume(newVolume)

            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimer = nil
            }
        }
    }
}

private func fadeIn(duration: TimeInterval) {
    fadeTimer?.invalidate()

    let endVolume = targetVolume  // ← Restore remembered volume

    // Similar implementation...
}
```

**Why 60 steps**: Matches display refresh rate for smooth perceived transition.

**Why Task { @MainActor }**: Swift 6 concurrency requires explicit actor isolation for MainActor properties accessed in Sendable closures.

**Why remember targetVolume**: User may have set custom volume. Fade-in should return to that volume, not default.

### 4.4 How to Implement Break Scheduler Callbacks

```swift
private func setupBreakSchedulerCallbacks() {
    breakScheduler.onBreakStart = { [weak self] in
        Task { @MainActor in
            self?.pause(reason: .quietBreak)
        }
    }

    breakScheduler.onBreakEnd = { [weak self] in
        Task { @MainActor in
            try? self?.resume()
        }
    }
}

public func resume() throws {
    // ... safety checks

    try engine.start()
    fadeIn(duration: 0.5)

    // Only restart scheduler if NOT resuming from quiet break
    // (scheduler handles its own auto-resume)
    if reason != .quietBreak {
        breakScheduler.start()
    }

    isPlaying = true
    pauseReason = nil
}
```

**Why check pauseReason**: Scheduler triggers `onBreakEnd` → `resume()`. Don't restart scheduler in this case (double-start).

---

## 5. Pitfalls & Fixes

### 5.1 API Availability Issues

#### Problem: AVAudioUnitDynamicsProcessor on iOS
```
Cannot find 'AVAudioUnitDynamicsProcessor' in scope
```

**Cause**: This class is macOS-only.

**Fix**: Use `AVAudioUnitDistortion` with soft clipping preset:
```swift
// ❌ Wrong (macOS-only)
private let dynamicsProcessor = AVAudioUnitDynamicsProcessor()

// ✅ Correct (iOS-compatible)
private let limiterNode = AVAudioUnitDistortion()
limiterNode.loadFactoryPreset(.multiDecimated4)
```

See ADR-0002 for full rationale.

#### Problem: Missing UIKit Import
```
Cannot find 'UIApplication' in scope
```

**Cause**: `UIApplication.willEnterForegroundNotification` requires UIKit.

**Fix**:
```swift
import Foundation
import UIKit  // ← Add this
```

### 5.2 Audio Session Issues

#### Problem: Session Activation Error -50
```
Error Domain=NSOSStatusErrorDomain Code=-50
```

**Cause**: `.allowBluetooth` option conflicts on some devices.

**Fix**: Start with minimal options, add incrementally:
```swift
// ❌ Wrong (can fail on some devices)
try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])

// ✅ Correct (minimal, stable)
try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
```

Only add options if specifically needed and tested.

#### Problem: Double Session Activation
```
Multiple calls to setActive(true)
```

**Cause**: Session activated in both `AudioService` and `LocalAudioEngine`.

**Fix**: Use flag to activate once:
```swift
private var sessionActivated = false

func play(...) throws {
    if !sessionActivated {
        try activateAudioSession()
        sessionActivated = true  // ← Prevent re-activation
    }
}
```

### 5.3 Route Monitoring Issues

#### Problem: UI Shows "Unknown" Route at Launch
**Cause**: Route monitoring not started until playback begins.

**Fix**: Start monitoring in `init()`, not `play()`:
```swift
private init() {
    // ...
    outputRoute = routeMonitor.currentRoute  // Get initial route
    routeMonitor.start()  // ← Start immediately
}
```

#### Problem: Safety Pause Triggers Too Often
**Cause**: Filtering all route changes, not just device removal.

**Fix**: Check `AVAudioSessionRouteChangeReason`:
```swift
guard changeReason == .oldDeviceUnavailable else {
    return  // Only trigger on device removal
}
```

### 5.4 Timer Drift Issues

#### Problem: Break Scheduler Drifts After Sleep
**Cause**: Using `uptimeNanoseconds` (pauses during sleep).

**Fix**: Use `wallDeadline` + Date ground truth:
```swift
// ❌ Wrong (drifts on sleep)
timer.schedule(deadline: .now() + interval)

// ✅ Correct (survives sleep)
_nextBreakAt = Date().addingTimeInterval(interval)
timer.schedule(wallDeadline: .now() + interval)

// Recalculate on wake:
let remaining = _nextBreakAt!.timeIntervalSince(Date())
timer.schedule(wallDeadline: .now() + remaining)
```

### 5.5 Fade Coordination Issues

#### Problem: Fade Cut Off (No Sound at All)
**Cause**: Stopping engine before fade completes.

**Fix**: Wait for fade before stopping:
```swift
// ❌ Wrong (cuts off fade)
fadeOut(duration: 0.5)
engine.stop()

// ✅ Correct (waits for fade)
fadeOut(duration: 0.5)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    engine.stop()
}
```

### 5.6 Swift 6 Concurrency Issues

#### Problem: Actor Isolation Warnings
```
Main actor-isolated property 'engine' cannot be referenced from a Sendable closure
```

**Cause**: Timer closures are `Sendable`, but AudioService is `@MainActor`.

**Fix**: Wrap in `Task { @MainActor }`:
```swift
// ❌ Wrong (Swift 6 warning)
fadeTimer = Timer.scheduledTimer(...) { [weak self] timer in
    self?.engine.setMasterVolume(...)  // Warning
}

// ✅ Correct (explicit actor isolation)
fadeTimer = Timer.scheduledTimer(...) { [weak self] timer in
    Task { @MainActor [weak self] in
        self?.engine.setMasterVolume(...)  // Safe
    }
}
```

### 5.7 Optional Chaining Issues

#### Problem: Incorrect Optional Chaining
```
Cannot use optional chaining on non-optional value of type 'QuietBreakScheduler'
```

**Cause**: `breakScheduler` is `let` (non-optional), but `nextBreakAt` is optional.

**Fix**: Only chain on the optional property:
```swift
// ❌ Wrong
if let nextBreak = audioService.breakScheduler?.nextBreakAt { }
                                                ^^^ breakScheduler not optional

// ✅ Correct
if let nextBreak = audioService.breakScheduler.nextBreakAt { }
```

### 5.8 Sample Rate Mismatch Issues ⭐ NEW

#### Problem: Crackling/Clicking Noise in Audio
**Symptoms**:
- "Pachi-pachi" (clicking/popping) noise in synthesized audio
- Artifacts at regular intervals
- LFO/oscillator phase discontinuities

**Cause**: Sample rate mismatch between AudioSource implementations and actual hardware.

**iOS uses 48 kHz as standard**, but some AudioSource files were using 44.1 kHz:

```swift
// ❌ Wrong (44.1 kHz - causes noise)
_sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
    let sampleRate = 44100.0  // Mismatch!
    lfoPhase += twoPi * frequency / sampleRate
    return noErr
}

// ✅ Correct (48 kHz - iOS standard)
_sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
    let sampleRate = 48000.0  // Matches iOS hardware
    lfoPhase += twoPi * frequency / sampleRate
    return noErr
}
```

**Why this causes noise**:
- Hardware runs at 48 kHz
- AudioSource calculates phase at 44.1 kHz
- Phase increments are incorrect: 48000/44100 = 1.088
- LFO period becomes 4.35s instead of 4.0s → phase discontinuity → clicks

**Fix**: Standardize all AudioSource implementations to 48 kHz.

**Verification**:
```bash
# Check for inconsistent sample rates
grep -rn "44100\|48000" clock-tsukiusagi/Core/Audio/Sources/
```

**Rule**: **Always use 48000.0 Hz for iOS AudioSource implementations.**

See [trouble-audio-sample-rate-mismatch.md](../trouble-audio-sample-rate-mismatch.md) for detailed RCA.

---

## 6. Code Snippets

### 6.1 AudioSettings Binding Pattern

```swift
struct AudioSettingsView: View {
    @EnvironmentObject private var audioService: AudioService
    @State private var settings: AudioSettings

    init() {
        _settings = State(initialValue: AudioSettings.load())
    }

    private func saveSettings() {
        settings.save()  // Persist to UserDefaults
        audioService.updateSettings(settings)  // Apply to live service
    }

    var body: some View {
        SettingsToggle(
            title: "Enable Quiet Breaks",
            isOn: Binding(
                get: { settings.quietBreakEnabled },
                set: {
                    settings.quietBreakEnabled = $0
                    saveSettings()  // Save on every change
                }
            )
        )
    }
}
```

### 6.2 Route Change Callback Pattern

```swift
private func setupCallbacks() {
    routeMonitor.onRouteChanged = { [weak self] route in
        Task { @MainActor in
            self?.outputRoute = route
        }
    }

    routeMonitor.onSpeakerSafety = { [weak self] in
        Task { @MainActor in
            self?.pause(reason: .routeSafetySpeaker)
        }
    }
}
```

### 6.3 Interruption Handling Pattern

```swift
private func setupInterruptionHandling() {
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

        Task { @MainActor in
            switch type {
            case .began:
                self.pause(reason: .interruption)

            case .ended:
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) && self.settings.autoResumeAfterInterruption {
                        try? self.resume()
                    }
                }

            @unknown default:
                break
            }
        }
    }
}
```

---

## 7. Verification

### 7.1 Self-Check Before Commit

- [ ] **Imports**: UIKit imported in QuietBreakScheduler
- [ ] **Route monitoring**: Started in `init()`, not `play()`
- [ ] **Session activation**: Single activation with flag
- [ ] **Volume limiter**: `isConfigured` flag prevents double-attach
- [ ] **Timer**: Using `wallDeadline`, not `deadline`
- [ ] **Ground truth**: Storing `Date`, recalculating on wake
- [ ] **Fade coordination**: `asyncAfter` before `engine.stop()`
- [ ] **Swift 6**: `Task { @MainActor }` in Timer closures
- [ ] **Optional chaining**: Only on optional properties
- [ ] **Break scheduler resume**: Checking `pauseReason != .quietBreak`

### 7.2 Build Verification

```bash
# Clean build
xcodebuild -scheme clock-tsukiusagi -sdk iphonesimulator clean build

# Check for warnings
# Expected: 0 warnings related to audio system
```

### 7.3 Runtime Verification (Console Logs)

Expected log sequence on successful playback:

```
🎵 [AudioService] Initialized as singleton
   Initial output route: Headphones 🎧
   Quiet breaks: Enabled
   Max output: -6.0 dB

🎵 [AudioService] play() called with preset: comfortRelax
🎵 [AudioService] Activating audio session...
   ✅ Category set
   ✅ Session activated
🔊 [SafeVolumeLimiter] Configuring soft limiter (iOS)
   Pre-gain: -6.0 dB
⏰ [QuietBreakScheduler] Starting scheduler
   Play duration: 55 minutes
   Next break at: [timestamp]
🎵 [AudioService] Playback started successfully
```

---

## Related Documents

- **Architecture Spec**: `../architecture/audio-system-spec.md`
- **ADR-0001**: Singleton Pattern (`../architecture/adrs/_adr-0001-audio-service-singleton.md`)
- **ADR-0002**: iOS Volume Limiter (`../architecture/adrs/_adr-0002-safe-volume-ios-alt.md`)
- **Operations Runbook**: `../runbook/_runbook-audio-ops-and-tests.md`
- **Changelog**: `../changelog/changelog-audio.md`

---

## Changelog

| Date | Version | Change |
|------|---------|--------|
| 2025-11-10 | 2.0 | Phase 2 implementation guide complete |
| 2025-11-23 | 2.1 | Updated playback flow to use UISoundPreset and mapping logic |

---

**Document Status**: ✅ Phase 2 Complete + 3-Layer Architecture
**Last Updated**: 2025-11-23
**Next Review**: Before Phase 3 implementation
