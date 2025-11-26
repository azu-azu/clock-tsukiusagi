# Audio System Operations & Testing Runbook

**Version**: 2.0 (Phase 2)
**Last Updated**: 2025-11-10
**Target Audience**: QA, Operations, Device Testers
**Prerequisites**: Physical iOS device with headphones

---

## Overview

This runbook provides step-by-step procedures for:
- **Pre-flight checks** before testing
- **Device testing procedures** for Phase 1 & 2 features
- **Pass/Fail criteria** for each test
- **Troubleshooting** common issues
- **Rollback plan** if problems occur

For **architecture decisions**, see `../architecture/audio-system-spec.md`.
For **implementation details**, see `../implementation/_guide-audio-system-impl.md`.

---

## Table of Contents

1. [Test Matrix](#1-test-matrix)
2. [Pre-Flight Checks](#2-pre-flight-checks)
3. [Phase 1 Test Procedures](#3-phase-1-test-procedures)
4. [Phase 2 Test Procedures](#4-phase-2-test-procedures)
5. [Pass/Fail Criteria](#5-passfail-criteria)
6. [Troubleshooting](#6-troubleshooting)
7. [Rollback Plan](#7-rollback-plan)

---

## 1. Test Matrix

### 1.1 Device Requirements

| Component | Requirement |
|-----------|-------------|
| **Device** | Physical iPhone (iOS 17.0+) |
| **Headphones** | Wired (Lightning/USB-C) + Bluetooth |
| **Network** | Not required (audio is local) |
| **Build** | Debug or Release (both should pass) |

### 1.2 Test Coverage Matrix

| Feature | Phase | Device | Wired HP | BT HP | Speaker | Lock |
|---------|-------|--------|----------|-------|---------|------|
| Screen transition survival | 1 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Route detection | 1 | ✅ | ✅ | ✅ | ✅ | - |
| Safety pause | 1 | ✅ | ✅ | ✅ | ⚠️ | - |
| Quiet breaks | 2 | ✅ | ✅ | ✅ | - | ✅ |
| Volume limiting | 2 | ✅ | ✅ | ⚠️ | ⚠️ | - |
| Fade effects | 2 | ✅ | ✅ | ✅ | ✅ | - |

**Legend**:
- ✅ Required test
- ⚠️ Optional (lower priority)
- `-` Not applicable

---

## 2. Pre-Flight Checks

### 2.1 Build Settings

```bash
# 1. Clean build
xcodebuild -scheme TsukiSound -sdk iphoneos clean

# 2. Build for device
xcodebuild -scheme TsukiSound -sdk iphoneos -configuration Debug

# 3. Verify no audio-related warnings
# Expected: 0 warnings in Core/Audio, Core/Services, Features/Settings
```

### 2.2 Permissions Check

**In Xcode**:
1. Open `Info.plist`
2. Verify present:
   - `Privacy - Microphone Usage Description` (not used but safe)
3. **NOT present** (to verify we don't request unnecessary permissions):
   - Microphone access (we only playback, no recording)

### 2.3 Settings Reset (Fresh Start)

**On device**:
1. Long-press app icon → "Remove App" → "Delete App"
2. Reinstall from Xcode
3. On first launch, verify:
   - Default settings loaded (quiet breaks OFF by default)
   - Route shows "Unknown" briefly, then updates to actual route

---

## 3. Phase 1 Test Procedures

### Test 1.1: Screen Transition Survival

**Objective**: Audio continues through UI navigation

**Procedure**:
1. Launch app
2. Navigate to **Audio** tab
3. Tap "Play"
4. Verify audio playing (listen for sound)
5. **Navigate to Clock tab**
6. Wait 5 seconds
7. **Navigate back to Audio tab**
8. **Lock device** (power button)
9. Wait 5 seconds
10. **Unlock device**
11. Verify audio still playing

**Pass Criteria**:
- ✅ Audio continues without interruption through all steps
- ✅ UI shows "Playing" state correctly after each transition
- ✅ No clicks, pops, or gaps in audio

**Fail Criteria**:
- ❌ Audio stops at any point
- ❌ UI shows "Stopped" but audio continues
- ❌ Audible clicks/pops during transitions

### Test 1.2: Route Detection - Wired Headphones

**Objective**: UI updates in real-time when headphones plugged/unplugged

**Procedure**:
1. Launch app with **no headphones**
2. Navigate to **Settings** tab
3. Observe route indicator
4. **Plug in wired headphones**
5. Observe route change
6. **Unplug headphones**
7. Observe route change

**Pass Criteria**:
- ✅ Initial route shows "Speaker 🔊" (if no headphones)
- ✅ Route changes to "Headphones 🎧" within 1 second of plug-in
- ✅ Route changes to "Speaker 🔊" within 1 second of unplug
- ✅ UI updates without app restart

**Fail Criteria**:
- ❌ Route shows "Unknown ❓" for >2 seconds
- ❌ Route doesn't update until app restarted
- ❌ Incorrect icon displayed

### Test 1.3: Route Detection - Bluetooth

**Objective**: Bluetooth headphones detected correctly

**Procedure**:
1. **Pair Bluetooth headphones** (via iOS Settings)
2. Launch app
3. Navigate to **Settings** tab
4. Observe route indicator
5. **Disconnect Bluetooth** (turn off headphones or unpair)
6. Observe route change

**Pass Criteria**:
- ✅ Route shows "Bluetooth 🅱️" when connected
- ✅ Route changes to "Speaker 🔊" when disconnected
- ✅ Transition smooth (no audio glitches)

**Fail Criteria**:
- ❌ Bluetooth not detected (shows Speaker despite connection)
- ❌ Audio cuts out during Bluetooth connect/disconnect

### Test 1.4: Safety Pause on Headphone Removal

**Objective**: Playback pauses when headphones removed (if setting enabled)

**Procedure**:
1. Navigate to **Settings** tab
2. **Enable** "Headphone-Only Mode"
3. Navigate to **Audio** tab
4. **Plug in wired headphones**
5. Tap "Play"
6. Verify audio playing in headphones
7. **Unplug headphones** (quickly)
8. Observe playback state

**Pass Criteria**:
- ✅ Playback **pauses** within 1 second of unplug
- ✅ UI shows "Paused" state
- ✅ Audio does NOT play through speaker
- ✅ Pause reason indicates "routeSafetySpeaker"

**Fail Criteria**:
- ❌ Audio continues playing through speaker
- ❌ Pause doesn't occur
- ❌ Delay >2 seconds before pause

**Variation**: Disable "Headphone-Only Mode", verify audio continues through speaker.

### Test 1.5: Settings Persistence

**Objective**: Settings survive app restart

**Procedure**:
1. Navigate to **Settings** tab
2. **Disable** "Headphone-Only Mode"
3. **Force-quit app** (swipe up in App Switcher)
4. Relaunch app
5. Navigate to **Settings** tab
6. Observe "Headphone-Only Mode" state

**Pass Criteria**:
- ✅ Setting remains **disabled** after restart
- ✅ All settings persist correctly

**Fail Criteria**:
- ❌ Settings reset to defaults after restart

---

## 4. Phase 2 Test Procedures

### Test 2.1: Quiet Break Cycle (Reduced Timing)

**Objective**: Scheduler triggers automatic pause/resume

**Setup**: Reduce timings for faster validation
1. **Modify AudioSettings.swift** (temporary):
   ```swift
   public var playMinutes: Int = 5   // Changed from 55
   public var breakMinutes: Int = 1  // Changed from 5
   ```
2. Rebuild app

**Procedure**:
1. Navigate to **Settings** tab
2. **Enable** "Quiet Breaks"
3. Verify "Play Duration: 5 min" and "Break Duration: 1 min"
4. Navigate to **Audio** tab
5. Tap "Play"
6. Observe "Next Break" time in Settings (should be ~5 minutes from now)
7. **Wait 5 minutes** (use stopwatch)
8. Observe automatic pause
9. **Wait 1 minute**
10. Observe automatic resume

**Pass Criteria**:
- ✅ Auto-pause occurs within ±10 seconds of 5-minute mark
- ✅ Fade-out smooth before pause
- ✅ Auto-resume occurs within ±10 seconds of 1-minute mark
- ✅ Fade-in smooth after resume
- ✅ "Next Break" time updates correctly

**Fail Criteria**:
- ❌ No auto-pause after 5+ minutes
- ❌ No auto-resume after break
- ❌ Timing drift >30 seconds

**Restore**: Revert `AudioSettings.swift` to original values (55/5) after test.

### Test 2.2: Quiet Break Sleep/Wake Drift Correction

**Objective**: Scheduler recalculates after device sleep

**Setup**: Use reduced timings (5min/1min) from Test 2.1

**Procedure**:
1. Enable quiet breaks (5min play / 1min break)
2. Tap "Play"
3. Note "Next Break" time (e.g., 17:05)
4. **Lock device** immediately
5. **Wait 6 minutes** (device asleep)
6. **Unlock device**
7. Observe playback state

**Pass Criteria**:
- ✅ Scheduler fired during sleep (audio paused)
- ✅ Break completed during sleep (audio resumed)
- ✅ OR: Scheduler recalculated on wake, fired immediately if overdue

**Fail Criteria**:
- ❌ Scheduler never fires
- ❌ Audio continues playing beyond break time
- ❌ Next break time not recalculated

### Test 2.3: Volume Limiter Effectiveness

**Objective**: Output limited to configured threshold

**Procedure**:
1. Navigate to **Settings** tab
2. Set "Maximum Output Level" to **-12 dB** (very low)
3. Navigate to **Audio** tab
4. Set volume slider to **maximum (1.0)**
5. Tap "Play" with **headphones on**
6. Observe perceived loudness
7. Return to Settings
8. Set "Maximum Output Level" to **0 dB**
9. Observe perceived loudness change

**Pass Criteria**:
- ✅ At -12 dB: Audio noticeably quieter than normal max volume
- ✅ At 0 dB: Audio louder (ceiling removed)
- ✅ No audible distortion at any setting
- ✅ Volume change smooth (no pops)

**Fail Criteria**:
- ❌ No volume difference between -12 dB and 0 dB settings
- ❌ Audible distortion/clipping
- ❌ Volume jumps abruptly

**Note**: Subjective test. Listen for harmonic distortion (buzzing/harshness) at various levels.

### Test 2.4: Fade Effects Smoothness

**Objective**: Fade-in/out without audible clicks

**Procedure**:
1. Navigate to **Audio** tab
2. **With headphones**: Tap "Play"
3. Listen for fade-in (0.5 seconds)
4. Tap "Stop"
5. Listen for fade-out (0.5 seconds)
6. Repeat 5 times

**Pass Criteria**:
- ✅ Fade-in smooth, no click at start
- ✅ Fade-out smooth, no click at end
- ✅ Consistent across multiple plays

**Fail Criteria**:
- ❌ Audible click/pop at start or end
- ❌ Abrupt volume jump
- ❌ Inconsistent behavior

### Test 2.5: Settings UI Immediate Effect

**Objective**: Settings changes apply without restart

**Procedure**:
1. Navigate to **Audio** tab
2. Tap "Play"
3. Navigate to **Settings** tab
4. Set "Maximum Output Level" to **-12 dB**
5. Return to **Audio** tab
6. Observe volume (should be quieter)
7. Return to **Settings** tab
8. **Disable** "Quiet Breaks"
9. Verify scheduler stopped (check "Next Break" disappears)

**Pass Criteria**:
- ✅ Volume change immediate (no restart needed)
- ✅ Quiet breaks stop when disabled
- ✅ All settings responsive during playback

**Fail Criteria**:
- ❌ Changes require app restart
- ❌ Settings don't apply while playing

---

## 5. Pass/Fail Criteria

### 5.1 Phase 1 Overall

**Required for Phase 1 completion**:
- [ ] All Test 1.1-1.5 pass
- [ ] Zero crashes in 2-hour continuous playback
- [ ] No audio glitches during 10+ tab switches
- [ ] Route detection <1 second latency

### 5.2 Phase 2 Overall

**Required for Phase 2 completion**:
- [ ] All Test 2.1-2.5 pass
- [ ] Break scheduler accurate within ±30 seconds (over 4-hour test)
- [ ] Volume limiter audibly effective (subjective)
- [ ] Fade transitions smooth (no clicks)
- [ ] Settings changes immediate

### 5.3 Regression Checks

**Verify Phase 1 still works**:
- [ ] Test 1.1 (screen transition) still passes
- [ ] Test 1.4 (safety pause) still passes

---

## 6. Troubleshooting

### Issue: Audio Doesn't Start

**Symptoms**: Tap "Play", but no sound

**Diagnosis**:
1. Check device **silent switch** (red indicator = silent mode)
2. Check device **volume buttons** (volume at 0?)
3. Check **Settings** → Maximum Output Level (is it at minimum?)

**Fix**:
- Flip silent switch to ring mode
- Increase volume with buttons
- Increase max output level in Settings

**If still failing**:
1. Check Xcode console for errors:
   ```
   ❌ setActive failed: ...
   ❌ Engine start failed: ...
   ```
2. See Implementation Guide section 5.2 (Session Issues)

### Issue: Route Shows "Unknown ❓"

**Symptoms**: Route indicator stuck on "Unknown"

**Diagnosis**:
1. Check if `AudioRouteMonitor.start()` called in `AudioService.init()`
2. Check console logs:
   ```
   🎧 [AudioRouteMonitor] Route change reason: ...
   ```

**Fix**:
- Ensure route monitoring starts at app launch, not first playback
- See Implementation Guide section 5.3 (Route Issues)

### Issue: Quiet Breaks Don't Fire

**Symptoms**: Waited >5 minutes (reduced timing), no auto-pause

**Diagnosis**:
1. Check if quiet breaks enabled in Settings
2. Check console logs:
   ```
   ⏰ [QuietBreakScheduler] Disabled, not starting
   ```
3. Check if scheduler started after playback begins

**Fix**:
- Enable in Settings UI
- Verify `breakScheduler.start()` called in `AudioService.play()`
- Check `isEnabled` flag in `QuietBreakScheduler`

### Issue: Volume Limiter No Effect

**Symptoms**: Volume same at -12 dB and 0 dB

**Diagnosis**:
1. Check if `SafeVolumeLimiter.configure()` called before `engine.start()`
2. Check console logs:
   ```
   🔊 [SafeVolumeLimiter] Configuring soft limiter (iOS)
   ```
3. Check if `isConfigured` flag preventing reconfiguration

**Fix**:
- Ensure limiter configured in `play()` before engine starts
- Stop and restart playback to reapply settings
- See Implementation Guide section 5.1 (API Issues)

### Issue: Fade Has Clicks

**Symptoms**: Audible click/pop at start or end of fade

**Diagnosis**:
1. Check if `asyncAfter` delay matches fade duration
2. Check if engine stops before fade completes

**Fix**:
```swift
// Ensure engine stops AFTER fade
fadeOut(duration: 0.5)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // ← Must match duration
    engine.stop()
}
```
- See Implementation Guide section 5.5 (Fade Issues)

---

## 7. Rollback Plan

### 7.1 Settings Rollback

**If Phase 2 settings cause issues**:

1. **Disable Quiet Breaks**:
   ```swift
   // In AudioSettings.swift
   public var quietBreakEnabled: Bool = false  // ← Change default
   ```

2. **Remove Volume Limiter**:
   ```swift
   // In AudioService.play()
   // Comment out:
   // let format = engine.engine.outputNode.inputFormat(forBus: 0)
   // volumeLimiter.configure(engine: engine.engine, format: format)
   ```

3. Rebuild and redeploy

### 7.2 Feature Flag (Future)

**Recommended for Phase 3**:

```swift
struct FeatureFlags {
    static let quietBreaksEnabled = false  // Master kill switch
    static let volumeLimiterEnabled = false
}

// In AudioService.play():
if FeatureFlags.quietBreaksEnabled {
    breakScheduler.start()
}
```

### 7.3 Git Rollback

**If Phase 2 entirely broken**:

```bash
# Rollback to Phase 1 tag
git reset --hard audio-architecture-phase1-complete

# Force push (ONLY if safe to do so)
git push --force
```

**Note**: Coordinate with team before force-pushing.

---

## 8. Monitoring & Logging

### 8.1 Key Log Messages to Watch

**Success indicators**:
```
✅ [AudioService] Initialized as singleton
✅ [AudioService] Audio session activated successfully
✅ [AudioService] Playback started successfully
🔊 [SafeVolumeLimiter] Configuration complete
⏰ [QuietBreakScheduler] Starting scheduler
```

**Warning indicators**:
```
⚠️ [AudioService] pause() called, reason: routeSafetySpeaker
⚠️ [AudioService] Still on speaker output, unsafe to resume
⏰ [QuietBreakScheduler] Disabled, not starting
```

**Error indicators**:
```
❌ [AudioService] setActive failed: ...
❌ [AudioService] Source registration failed: ...
❌ [AudioService] Engine start failed: ...
```

### 8.2 Xcode Console Filtering

**Filter by tag**:
```
[AudioService]
[AudioRouteMonitor]
[QuietBreakScheduler]
[SafeVolumeLimiter]
```

**Filter by symbol**:
```
✅  # Success
⚠️  # Warning
❌  # Error
🎵  # Audio event
🎧  # Route event
⏰  # Scheduler event
🔊  # Volume event
```

---

## Related Documents

- **Architecture Spec**: `../architecture/audio-system-spec.md`
- **Implementation Guide**: `../implementation/_guide-audio-system-impl.md`
- **ADR-0001**: Singleton Pattern (`../architecture/adrs/_adr-0001-audio-service-singleton.md`)
- **ADR-0002**: iOS Volume Limiter (`../architecture/adrs/_adr-0002-safe-volume-ios-alt.md`)
- **Changelog**: `../changelog/changelog-audio.md`

---

**Document Status**: ✅ Phase 2 Procedures Complete
**Last Updated**: 2025-11-10
**Next Review**: Before Phase 3 testing
