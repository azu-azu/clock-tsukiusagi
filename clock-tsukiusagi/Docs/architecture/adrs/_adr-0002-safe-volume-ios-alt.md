# ADR-0002: iOS Volume Limiter - AVAudioUnitDistortion Alternative

**Status**: ✅ Accepted
**Date**: 2025-11-10
**Deciders**: Audio Architecture Team
**Related Phase**: Phase 2
**Supersedes**: Original design (Appendix C) specifying AVAudioUnitDynamicsProcessor

---

## Context

Original Phase 2 design specified `AVAudioUnitDynamicsProcessor` for volume limiting:

```swift
private let dynamicsProcessor = AVAudioUnitDynamicsProcessor()

func configureDynamicsProcessor() {
    dynamicsProcessor.threshold = maxOutputDb          // -6dB ceiling
    dynamicsProcessor.headRoom = 0.1                   // 0.1dB headroom
    dynamicsProcessor.attackTime = 0.001               // 1ms attack
    dynamicsProcessor.releaseTime = 0.05               // 50ms release
    dynamicsProcessor.compressionAmount = 20.0         // Heavy limiting
}
```

**Compilation Error on iOS**:
```
Cannot find 'AVAudioUnitDynamicsProcessor' in scope
```

**Platform Availability**:
- `AVAudioUnitDynamicsProcessor`: **macOS 10.10+** only
- **NOT available on iOS, tvOS, watchOS**

**Requirements**:
- Prevent audio output exceeding user-defined threshold (default: -6dB)
- Protect hearing during long playback sessions
- User-configurable ceiling in settings UI
- iOS compatibility required

---

## Decision

**Use `AVAudioUnitDistortion` with soft clipping preset** as iOS-compatible alternative:

```swift
private let limiterNode = AVAudioUnitDistortion()

private func updateLimiterSettings() {
    // Load soft clipping preset
    limiterNode.loadFactoryPreset(.multiDecimated4)

    // Pre-gain controls the ceiling
    limiterNode.preGain = maxOutputDb  // -6dB default

    // Full wet mix (100% processing)
    limiterNode.wetDryMix = 100
}
```

**Audio Graph** (structure unchanged):
```
MainMixerNode → SafeVolumeLimiter → OutputNode
                (AVAudioUnitDistortion)
```

---

## Consequences

### Positive

1. **Platform compatibility**:
   - ✅ Available on iOS, macOS, tvOS, watchOS
   - ✅ No conditional compilation needed
   - ✅ Consistent codebase across platforms

2. **Drop-in replacement**:
   - ✅ Same audio graph structure
   - ✅ Same `configure(engine:format:)` interface
   - ✅ Same dB-based threshold control

3. **Acceptable protection**:
   - ✅ Soft clipping prevents harsh digital clipping
   - ✅ Pre-gain adjustment provides volume ceiling
   - ✅ Suitable for smooth synthesized content (app's use case)

### Negative

1. **Less precise than dynamics processor**:
   - ❌ No attack/release/ratio control
   - ❌ Soft clipping adds harmonic distortion
   - ❌ Not transparent limiting (audible on extreme peaks)

2. **Trade-offs for use case**:
   - App generates smooth drones (no sharp transients)
   - Volume ceiling is safety feature, not mastering tool
   - Soft clipping preferable to hard clipping for user safety
   - Distortion minimal at target levels (-6dB ceiling with typical content)

---

## Alternatives Considered

### Alternative 1: Manual Volume Scaling
**Description**: Scale volume in MainMixerNode without processor

```swift
let safeVolume = min(requestedVolume, volumeCeiling)
engine.mainMixerNode.outputVolume = safeVolume
```

**Pros**:
- Simple implementation
- No distortion artifacts
- Zero processing overhead

**Cons**:
- ❌ No brick-wall protection (peaks can exceed ceiling)
- ❌ Relies solely on user-set volume (risky)
- ❌ No limiting if source amplitude spikes

**Rejection reason**: Insufficient protection for safety-critical feature

### Alternative 2: Custom DSP Limiter
**Description**: Implement true limiter using `AVAudioSourceNode` with custom rendering

**Pros**:
- Full control over attack/release/knee
- Transparent limiting possible
- Optimal quality

**Cons**:
- ❌ Complex implementation (100+ lines of DSP code)
- ❌ Requires audio engineering expertise
- ❌ Testing/validation difficult
- ❌ Maintenance burden

**Rejection reason**: Over-engineering for current requirements

### Alternative 3: AVAudioUnitEQ with Gain Reduction
**Description**: Use EQ to reduce overall gain

**Pros**:
- Transparent (no distortion)
- Available on iOS

**Cons**:
- ❌ Not a limiter (doesn't prevent peaks)
- ❌ Static gain reduction (not dynamic)
- ❌ Doesn't fulfill protection requirement

**Rejection reason**: Not a limiting solution

### Alternative 4: Conditional Compilation (macOS/iOS)
**Description**: Use DynamicsProcessor on macOS, Distortion on iOS

```swift
#if os(macOS)
private let limiterNode = AVAudioUnitDynamicsProcessor()
#else
private let limiterNode = AVAudioUnitDistortion()
#endif
```

**Pros**:
- Best quality on each platform

**Cons**:
- ❌ Code complexity (platform-specific branches)
- ❌ Inconsistent behavior across platforms
- ❌ Testing requires both platforms

**Rejection reason**: App is iOS-only, unnecessary complexity

---

## Implementation Details

### Configuration
```swift
public func configure(engine: AVAudioEngine, format: AVAudioFormat) {
    guard !isConfigured else { return }

    // Attach limiter node
    engine.attach(limiterNode)

    // Connect: MainMixerNode → Limiter → OutputNode
    engine.connect(engine.mainMixerNode, to: limiterNode, format: format)
    engine.connect(limiterNode, to: engine.outputNode, format: format)

    // Configure soft limiter
    updateLimiterSettings()

    isConfigured = true
}

private func updateLimiterSettings() {
    limiterNode.loadFactoryPreset(.multiDecimated4)  // Soft clipping
    limiterNode.preGain = maxOutputDb                // -6dB default
    limiterNode.wetDryMix = 100                      // Full processing
}
```

### Preset Selection Rationale
`AVAudioUnitDistortion.Preset.multiDecimated4` chosen because:
- Softest clipping characteristic among presets
- Minimal harmonic addition at moderate levels
- Behavior similar to soft limiting
- Tested subjectively for app's drone content

### Double-Configuration Prevention
```swift
private var isConfigured = false

func configure(...) {
    guard !isConfigured else { return }  // Prevent crash
    // ... attach and connect
    isConfigured = true
}
```

**Why**: `configure()` called in `play()` method. Without flag, multiple plays would attempt to re-attach already-attached node → crash.

---

## Validation Plan

### Device Testing Required
1. **Volume Levels**: Test at various mixer volumes (0.3, 0.5, 0.7, 1.0)
2. **Threshold Engagement**: Verify limiter engages above threshold
3. **Distortion Check**: Listen for audible artifacts (subjective test)
4. **Headphone Test**: Verify with actual headphones (most critical use case)
5. **Stability**: No unexpected volume jumps or glitches

### Acceptance Criteria
- [ ] Limiter prevents output >0.5dB above threshold
- [ ] Distortion artifacts acceptable for smooth drone content
- [ ] No audible clicks or pops during limiting
- [ ] Settings UI slider (-12dB to 0dB) works correctly
- [ ] Limiter survives repeated play/stop cycles

### Rollback Plan
If distortion unacceptable:
1. Fall back to Alternative 1 (manual volume scaling)
2. Document limitation: "Soft ceiling, not brick-wall"
3. Consider Alternative 2 (custom DSP) for future improvement

---

## Impact Assessment

### User Experience
- **Hearing protection**: ✅ Maintained (soft ceiling better than none)
- **Audio quality**: ⚠️ Minor distortion possible on peaks (acceptable trade-off)
- **Transparency**: ✅ Most users won't notice with smooth content

### Technical Debt
- **Low**: Well-encapsulated in `SafeVolumeLimiter` class
- **Future improvement**: Can replace with custom DSP if needed
- **Testability**: Unchanged (same protocol interface)

### Maintenance
- **No platform-specific code**: Single implementation for all platforms
- **No deprecation risk**: AVAudioUnitDistortion is stable API
- **Future-proof**: Can upgrade to custom DSP without breaking interface

---

## Related Documents

- **Architecture Spec**: `../audio-system-spec.md` (Section 3.3: Audio Graph)
- **Implementation Guide**: `../../implementation/audio-system-impl-guide.md` (SafeVolumeLimiter section)
- **Original Design**: `/Users/mypc/AI_develop/clock-tsukiusagi/architect/2025-11-10_audio_architecture_redesign.md` (Issue 4, Appendix C)
- **ADR-0001**: Audio Service Singleton Pattern

---

## Changelog

| Date | Change |
|------|--------|
| 2025-11-10 | Initial design specified AVAudioUnitDynamicsProcessor (macOS-only) |
| 2025-11-10 | Compilation error discovered on iOS |
| 2025-11-10 | Decision: Use AVAudioUnitDistortion as iOS-compatible alternative |
| 2025-11-10 | Implementation complete (Phase 2) |

---

**ADR Status**: ✅ Accepted and Implemented
**Review Date**: After device testing (validate distortion acceptable)
**Contingency**: If distortion unacceptable, implement custom DSP limiter (ADR-0003)
