# ADR-0001: Audio Service Singleton Pattern

**Status**: ✅ Accepted
**Date**: 2025-11-10
**Deciders**: Audio Architecture Team
**Related Phase**: Phase 1

---

## Context

The current audio system uses View-owned `LocalAudioEngine` instances created in `playAudio()`. This causes audio to stop when:
- User navigates to different screen
- Tab switching occurs
- View is destroyed (`onDisappear` or navigation pop)
- App enters background (in some cases)

Requirements for new system:
1. Audio must continue during screen transitions
2. Single source of truth for playback state
3. Settings must persist across app launches
4. Future features need app-wide coordination (Live Activity, scheduled breaks)

---

## Decision

**Adopt Singleton pattern for AudioService** with the following design:

```swift
@MainActor
public final class AudioService: ObservableObject {
    public static let shared = AudioService()

    @Published public private(set) var isPlaying: Bool
    @Published public private(set) var currentPreset: NaturalSoundPreset?
    @Published public private(set) var outputRoute: AudioOutputRoute

    private let engine: LocalAudioEngine
    private let sessionManager: AudioSessionManager
    private let routeMonitor: AudioRouteMonitor

    private init() {
        // Initialize once at app launch
        // Components persist for app lifetime
    }
}
```

**Injection into SwiftUI**:
```swift
@main
struct ClockTsukiusagiApp: App {
    @StateObject private var audioService = AudioService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioService)
        }
    }
}
```

**View usage**:
```swift
struct AudioTestView: View {
    @EnvironmentObject var audioService: AudioService

    var body: some View {
        Button("Play") {
            try? audioService.play(preset: .comfortRelax)
        }
        .disabled(audioService.isPlaying)
    }
}
```

---

## Consequences

### Positive

1. **Screen transition survival**:
   - Audio continues regardless of View lifecycle
   - No `onDisappear` stops playback
   - State persists across navigation

2. **Single source of truth**:
   - One AudioService instance for entire app
   - Consistent state across all Views
   - No synchronization issues between screens

3. **Future extensibility**:
   - Live Activity can access service directly
   - Scheduled breaks coordinate with UI state
   - Background playback easier to implement

4. **Simplified View logic**:
   - Views don't manage audio lifecycle
   - Views observe state, send commands
   - Clear separation of concerns

5. **Performance**:
   - Audio session activated once per launch
   - No repeated setup/teardown overhead
   - Engine resources reused

### Negative

1. **Memory overhead**:
   - Singleton persists for app lifetime
   - Cannot be deallocated until app termination
   - **Mitigation**: Acceptable for core service (small footprint)

2. **Testing complexity**:
   - Singleton harder to mock in unit tests
   - Global state can leak between tests
   - **Mitigation**: Protocol-based design allows dependency injection in tests

3. **Initialization timing**:
   - Must ensure AudioService ready before first use
   - Circular dependency risks if not careful
   - **Mitigation**: Initialize in `@main` App struct, guaranteed early

4. **Concurrency concerns**:
   - Singleton accessed from multiple Views
   - AVAudioSession requires main thread
   - **Mitigation**: `@MainActor` annotation enforces thread safety

---

## Alternatives Considered

### Alternative 1: Scoped Service (per-scene)
**Description**: Create AudioService per SwiftUI Scene, passed via `.environmentObject()`

**Pros**:
- Easier to deallocate when scene destroyed
- Multiple scenes could have independent audio

**Cons**:
- ❌ Doesn't solve screen transition problem within scene
- ❌ Multiple audio sessions conflict
- ❌ State synchronization nightmare across scenes

**Rejection reason**: Doesn't address core problem (View lifecycle dependency)

### Alternative 2: View Model Pattern
**Description**: Pass AudioService reference through ViewModels

**Pros**:
- More testable (DI via initializer)
- Explicit dependencies

**Cons**:
- ❌ Boilerplate for every ViewModel
- ❌ Doesn't prevent View lifecycle coupling
- ❌ State still needs app-wide coordination

**Rejection reason**: Adds complexity without solving survival problem

### Alternative 3: Actor-based Service
**Description**: Use Swift actor for concurrency safety

**Pros**:
- Better concurrency isolation
- Compiler-enforced thread safety

**Cons**:
- ❌ AVAudioSession requires main thread (actor isolation conflict)
- ❌ SwiftUI `@Published` requires `ObservableObject` (main actor)
- ❌ Added complexity for marginal benefit

**Rejection reason**: Platform constraints (AVAudioSession) require main thread anyway

### Alternative 4: Notification-based Coordination
**Description**: Views post notifications, global observer manages audio

**Pros**:
- Decoupled Views

**Cons**:
- ❌ Harder to track state
- ❌ Notification ordering issues
- ❌ Debugging nightmare

**Rejection reason**: Notification center anti-pattern for direct state management

---

## Implementation Notes

### Initialization Order
1. App launches → `@main` struct created
2. `@StateObject audioService = AudioService.shared` created
3. AudioService.init() runs once
4. Components initialized (engine, session, monitors)
5. `.environmentObject(audioService)` injected into root View
6. All child Views access via `@EnvironmentObject`

### Lifecycle Hooks
- **App launch**: AudioService.init() called
- **App terminate**: AudioService.deinit() called (cleanup observers)
- **View appear/disappear**: No effect on AudioService
- **Scene phase changes**: AudioService persists

### Thread Safety
- `@MainActor` annotation ensures all access on main thread
- AVAudioSession operations safe (platform requirement)
- `@Published` properties update UI correctly

---

## Validation

### Success Criteria
- [x] Audio continues through tab switches
- [x] Audio continues through navigation push/pop
- [x] Audio continues when app locked
- [x] State consistent across all Views
- [x] No double session activation

### Test Results (Phase 1)
- ✅ 10+ tab switches without interruption
- ✅ Push/pop navigation maintains playback
- ✅ Lock screen → unlock preserves state
- ✅ Single session activation per launch (verified via logs)
- ✅ Memory stable over 2-hour run

---

## Related Documents

- **Architecture Spec**: `../audio-system-spec.md`
- **Implementation Guide**: `../../implementation/audio-system-impl-guide.md`
- **Original Design**: `/Users/mypc/AI_develop/clock-tsukiusagi/architect/2025-11-10_audio_architecture_redesign.md` (Section 2.1)

---

## Changelog

| Date | Change |
|------|--------|
| 2025-11-10 | Initial decision: Singleton pattern adopted |
| 2025-11-10 | Phase 1 implementation complete, validation passed |

---

**ADR Status**: ✅ Accepted and Implemented
**Review Date**: N/A (foundational decision, no planned changes)
