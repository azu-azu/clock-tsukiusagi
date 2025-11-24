//
//  BassoonDrone.swift
//  clock-tsukiusagi
//
//  Deep orchestral boom generator with sub-bass characteristics
//  Creates random "boooon" resonances with falling pitch
//
//  REDESIGNED: No longer a bassoon-like woodwind drone.
//  Now produces a deep orchestral boom / bass drum / sub-bass effect
//  with a characteristic pitch drop over the duration.
//

import AVFoundation
import Foundation

private final class BassoonState {
    var isSuspended = false
    var time: Double = 0.0
    var lastTriggerTime: Double = -10.0  // 最後にブームを鳴らした時刻
    var currentDroneTime: Double = -1.0  // 現在のブームの経過時間（-1 = 発音中でない）
}

/// BassoonDrone - Deep orchestral boom generator
///
/// Generates random deep "boooon" bass resonances with falling pitch.
///
/// Sound characteristics:
/// - Sub-bass fundamental (55Hz = A1 by default)
/// - Simple harmonic structure: fundamental dominant + subtle upper harmonics
/// - Fast attack (~0.08s), long smooth decay (~5s)
/// - Falling pitch over duration (creates "bwoooon" falling effect)
/// - Random triggering with configurable rate
///
/// Tweaking guide:
/// - **Heavier boom**: Lower fundamental (40-50Hz), increase droneDuration (6-8s)
/// - **Shorter boom**: Decrease droneDuration (2-3s), increase attack (0.1-0.15s)
/// - **Brighter tone**: Add more 2nd/3rd harmonic amplitude (e.g. [1.0, 0.6, 0.3])
/// - **Darker tone**: Reduce upper harmonics (e.g. [1.0, 0.2, 0.1])
/// - **More pitch drop**: Increase pitchDropAmount (0.2-0.3)
/// - **Less pitch drop**: Decrease pitchDropAmount (0.05-0.1)
public final class BassoonDrone: AudioSource {

    private let state = BassoonState()
    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    /// Initialize BassoonDrone
    /// - Parameters:
    ///   - droneRate: Frequency of boom triggers (per second)
    ///   - droneDuration: Duration of each boom resonance (seconds)
    ///   - fundamental: Base frequency (Hz) - typical sub-bass range 40-80Hz
    public init(
        droneRate: Double = 0.08,      // ~1回/12秒（控えめ）
        droneDuration: Double = 5.0,   // 5秒の長い余韻
        fundamental: Double = 55.0     // 基音55Hz（A1）
    ) {
        print("💥 BassoonDrone (Orchestral Boom) initialized: rate=\(droneRate), duration=\(droneDuration), fundamental=\(fundamental)Hz")

        let sampleRate: Double = 48_000.0
        let twoPi = 2.0 * Double.pi

        // ============================================================
        // HARMONIC STRUCTURE: Simple, fundamental-dominant
        // ============================================================
        // For orchestral boom: emphasize fundamental, add subtle brightness
        let harmonics: [Double] = [1.0, 2.0, 3.0]
        let harmonicAmps: [Double] = [1.0, 0.4, 0.2]  // Fundamental dominant

        var phases: [Double] = Array(repeating: 0, count: harmonics.count)

        // ============================================================
        // ENVELOPE TIMING
        // ============================================================
        // Fast attack for "boom" onset, long decay for sub-bass tail
        let attack: Double = 0.08      // 80ms: quick but not clicky
        let decay: Double = droneDuration - attack  // Rest is smooth decay

        // ============================================================
        // PITCH DROP CONFIGURATION
        // ============================================================
        // Creates the characteristic "bwoooon" falling pitch effect
        // pitchDropAmount: 0.15 means pitch falls to 85% of original
        let pitchDropAmount: Double = 0.15

        let state = self.state

        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            if state.isSuspended {
                for b in abl { memset(b.mData, 0, Int(b.mDataByteSize)) }
                return noErr
            }

            guard let buffer = abl.first else { return noErr }
            let samples = buffer.mData?.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                let currentTime = state.time
                state.time += 1.0 / sampleRate

                // ============================================================
                // TRIGGER LOGIC: Random boom generation
                // ============================================================
                let shouldTriggerDrone = drand48() < droneRate / sampleRate

                if shouldTriggerDrone && (currentTime - state.lastTriggerTime) > droneDuration {
                    // 新しいブームを開始
                    print("💥 Orchestral boom triggered at t=\(currentTime)")
                    state.lastTriggerTime = currentTime
                    state.currentDroneTime = 0.0
                }

                // ============================================================
                // BOOM SYNTHESIS (when active)
                // ============================================================
                var value: Double = 0.0

                if state.currentDroneTime >= 0.0 && state.currentDroneTime < droneDuration {

                    // --------------------------------------------------------
                    // ENVELOPE CALCULATION
                    // --------------------------------------------------------
                    let envelope: Double
                    if state.currentDroneTime < attack {
                        // Attack phase: smooth sin^2 curve (soft onset, not clicky)
                        let attackProgress = state.currentDroneTime / attack
                        let sinValue = sin(attackProgress * Double.pi / 2.0)  // 0 → π/2
                        envelope = sinValue * sinValue  // sin^2 for smooth curve
                    } else {
                        // Decay phase: power curve for long, smooth tail
                        // Uses (1-t)^2.5 instead of pure exponential
                        // This keeps volume longer, then fades smoothly
                        let decayTime = state.currentDroneTime - attack
                        let decayProgress = decayTime / decay  // 0.0 → 1.0
                        let remaining = 1.0 - decayProgress
                        envelope = pow(remaining, 2.5)  // Power curve decay
                    }

                    // --------------------------------------------------------
                    // PITCH DROP CALCULATION
                    // --------------------------------------------------------
                    // Progress through the entire boom duration (0.0 → 1.0)
                    let overallProgress = state.currentDroneTime / droneDuration

                    // Pitch multiplier: starts at 1.0, falls to (1.0 - pitchDropAmount)
                    // Example: pitchDropAmount=0.15 → falls from 100% to 85%
                    let pitchFactor = 1.0 - pitchDropAmount * overallProgress

                    // --------------------------------------------------------
                    // HARMONIC SYNTHESIS with pitch modulation
                    // --------------------------------------------------------
                    for i in 0..<harmonics.count {
                        // Apply pitch drop to each harmonic frequency
                        let baseFreq = fundamental * harmonics[i]
                        let modulatedFreq = baseFreq * pitchFactor

                        // Generate sine wave at modulated frequency
                        value += sin(phases[i]) * harmonicAmps[i] * envelope

                        // Advance phase based on modulated frequency
                        phases[i] += twoPi * modulatedFreq / sampleRate

                        // Phase wrapping (keep in 0-2π range)
                        if phases[i] > twoPi {
                            phases[i] -= twoPi
                        }
                    }

                    // Advance boom time
                    state.currentDroneTime += 1.0 / sampleRate

                    // Stop when duration reached
                    if state.currentDroneTime >= droneDuration {
                        state.currentDroneTime = -1.0
                    }
                }

                // ============================================================
                // OUTPUT GAIN
                // ============================================================
                // Normalize by harmonic count and apply safe output level
                // 0.20 = moderate level, leaving headroom for external limiter
                samples?[frame] = Float(value / Double(harmonics.count) * 0.20)
            }

            return noErr
        }
    }

    public func suspend() { state.isSuspended = true }
    public func resume()  { state.isSuspended = false }

    public func start() throws {}
    public func stop() {}
    public func setVolume(_ volume: Float) {}
}

// ============================================================
// DESIGN NOTES
// ============================================================
//
// Changes from previous "bassoon-like drone" design:
//
// 1. HARMONIC STRUCTURE:
//    OLD: Odd harmonics [1.0, 3.0, 5.0, 7.0, 9.0] for woody, reedy tone
//    NEW: Simple structure [1.0, 2.0, 3.0] with fundamental dominant
//         → Creates cleaner, more sub-bass-like boom
//
// 2. FUNDAMENTAL FREQUENCY:
//    OLD: 80Hz (low E)
//    NEW: 55Hz (A1) - deeper sub-bass range
//         → Feels more like orchestral bass drum / timpani
//
// 3. ENVELOPE:
//    OLD: 300ms quadratic attack, exponential decay
//    NEW: 80ms sin^2 attack, power-curve decay (x^2.5)
//         → Faster onset for "boom" character
//         → Smoother, longer tail for sub-bass sustain
//
// 4. PITCH MODULATION (NEW):
//    Added pitch drop over duration (15% by default)
//    → Creates characteristic "bwoooon" falling effect
//    → Mimics natural resonance behavior of large drums
//
// 5. OUTPUT LEVEL:
//    OLD: 0.35 (test mode)
//    NEW: 0.20 (safer headroom)
//         → Leaves room for external limiter and other layers
//
// ============================================================
