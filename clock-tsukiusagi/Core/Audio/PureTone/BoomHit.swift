//
//  BoomHit.swift
//  clock-tsukiusagi
//
//  One-shot "DOOON" boom hit generator
//  Creates a single cinematic bass drum / sub-bass impact when triggered
//
//  Design:
//  - Manual trigger (not random/continuous)
//  - Three-layer synthesis: noise attack + sub-bass body + pitch drop
//  - Single-shot envelope: fast attack, smooth decay
//

import AVFoundation
import Foundation

private final class BoomHitState {
    var isSuspended = false
    var isActive = false        // Whether a hit is currently playing
    var currentTime: Double = 0.0  // Time within current hit
}

/// BoomHit - One-shot bass drum / cinematic boom generator
///
/// Produces a single "DOOON" impact when `trigger()` is called.
///
/// Sound layers:
/// 1. **Noise attack** (5-20ms) - Creates initial impact "D"
/// 2. **Sub-bass body** - Deep sine harmonics for the "OOO"
/// 3. **Pitch drop** - Falling pitch over duration for "N" tail
///
/// Usage:
/// ```
/// let boom = BoomHit(duration: 3.0, fundamental: 55.0)
/// // ... register with audio engine ...
/// boom.trigger()  // Play one hit
/// ```
///
/// Tweaking guide:
/// - **Heavier impact**: Lower fundamental (40-50Hz), longer duration (4-5s)
/// - **Shorter hit**: Decrease duration (1-2s), reduce pitch drop (0.05-0.1)
/// - **More attack**: Increase noise level in code (0.3 → 0.5)
/// - **Deeper tone**: Lower fundamental, reduce upper harmonics
/// - **Brighter tone**: Increase 2nd/3rd harmonic amplitudes
public final class BoomHit: AudioSource {

    private let state = BoomHitState()
    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    /// Initialize BoomHit
    /// - Parameters:
    ///   - duration: Duration of the boom hit (seconds)
    ///   - fundamental: Base frequency (Hz) - typical sub-bass range 40-80Hz
    ///   - pitchDropAmount: How much pitch drops over duration (0.1 = 10% drop)
    public init(
        duration: Double = 3.0,
        fundamental: Double = 55.0,
        pitchDropAmount: Double = 0.15
    ) {
        let sampleRate: Double = 48_000.0
        let twoPi = 2.0 * Double.pi

        // ============================================================
        // HARMONIC STRUCTURE: Simple, fundamental-dominant
        // ============================================================
        let harmonics: [Double] = [1.0, 2.0, 3.0]
        let harmonicAmps: [Double] = [1.0, 0.4, 0.2]  // Fundamental dominant

        var phases: [Double] = Array(repeating: 0, count: harmonics.count)

        // ============================================================
        // ENVELOPE TIMING
        // ============================================================
        let attack: Double = 0.03      // 30ms: fast but smooth attack
        let noiseDuration: Double = 0.015  // 15ms: very short noise burst

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

                // ============================================================
                // INACTIVE STATE: Output silence
                // ============================================================
                if !state.isActive {
                    samples?[frame] = 0.0
                    continue
                }

                // ============================================================
                // ACTIVE HIT SYNTHESIS
                // ============================================================
                var value: Double = 0.0

                // --------------------------------------------------------
                // LAYER 1: Noise attack (initial impact "D")
                // --------------------------------------------------------
                if state.currentTime < noiseDuration {
                    let noise = Double.random(in: -1.0 ... 1.0)
                    let noiseEnv = exp(-state.currentTime * 300.0)  // Fast exponential decay
                    value += noise * 0.3 * noiseEnv
                }

                // --------------------------------------------------------
                // LAYER 2: Sub-bass body envelope
                // --------------------------------------------------------
                let envelope: Double
                if state.currentTime < attack {
                    // Attack phase: smooth sin^2 curve (no click)
                    let attackProgress = state.currentTime / attack
                    let sinValue = sin(attackProgress * Double.pi / 2.0)  // 0 → π/2
                    envelope = sinValue * sinValue  // sin^2 for smooth curve
                } else {
                    // Decay phase: power curve for long, smooth tail
                    let decayTime = state.currentTime - attack
                    let decayDuration = duration - attack
                    let decayProgress = decayTime / decayDuration  // 0.0 → 1.0
                    let remaining = max(0.0, 1.0 - decayProgress)
                    envelope = pow(remaining, 2.5)  // Power curve decay
                }

                // --------------------------------------------------------
                // LAYER 3: Pitch drop calculation
                // --------------------------------------------------------
                let progress = min(max(state.currentTime / duration, 0.0), 1.0)
                let pitchFactor = 1.0 - pitchDropAmount * progress  // Falls to (1.0 - amount)

                // --------------------------------------------------------
                // Sub-bass harmonic synthesis with pitch modulation
                // --------------------------------------------------------
                for i in 0..<harmonics.count {
                    // Apply pitch drop to each harmonic
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

                // ============================================================
                // OUTPUT GAIN
                // ============================================================
                // Normalize by harmonic count and apply safe output level
                let normalized = value / Double(harmonics.count)
                samples?[frame] = Float(normalized * 0.2)  // Conservative gain

                // ============================================================
                // TIME ADVANCEMENT & DEACTIVATION
                // ============================================================
                state.currentTime += 1.0 / sampleRate

                // Deactivate when hit duration is reached
                if state.currentTime >= duration {
                    state.isActive = false
                    state.currentTime = 0.0
                    // Reset phases for next hit
                    for i in 0..<phases.count {
                        phases[i] = 0.0
                    }
                }
            }

            return noErr
        }
    }

    /// Trigger a single boom hit
    ///
    /// Starts a new "DOOON" impact immediately. If a previous hit is still
    /// playing, it will be interrupted and restarted from the beginning.
    public func trigger() {
        guard !state.isSuspended else { return }
        state.currentTime = 0.0
        state.isActive = true
    }

    public func suspend() { state.isSuspended = true }
    public func resume()  { state.isSuspended = false }

    public func start() throws {}
    public func stop() {
        state.isActive = false
        state.currentTime = 0.0
    }
    public func setVolume(_ volume: Float) {}
}

// ============================================================
// DESIGN NOTES
// ============================================================
//
// Sound character: Single cinematic bass drum / sub-bass impact
//
// THREE-LAYER SYNTHESIS:
//
// 1. NOISE ATTACK (0-15ms):
//    - Wideband random noise
//    - Fast exponential decay (300 Hz decay rate)
//    - Creates initial "D" impact
//    - Level: 0.3 (30% of full scale before normalization)
//
// 2. SUB-BASS BODY:
//    - Fundamental: 55Hz (A1) default
//    - Harmonics: [1x, 2x, 3x] with amps [1.0, 0.4, 0.2]
//    - Provides deep "OOO" resonance
//    - Shaped by main envelope (see below)
//
// 3. PITCH DROP:
//    - Pitch falls by pitchDropAmount over duration
//    - Default: 15% drop (100% → 85%)
//    - Applied continuously to all harmonics
//    - Creates "DOOON" falling effect
//
// ENVELOPE DESIGN:
//
// - Attack: 30ms sin^2 curve (smooth, no click)
// - Decay: Power curve (1-t)^2.5 for long tail
// - Total duration: Configurable (default 3s)
// - When duration reached: isActive = false, output silence
//
// TRIGGER BEHAVIOR:
//
// - Manual activation via trigger() method
// - NOT random/continuous like BassoonDrone
// - One-shot: plays once per trigger, then stops
// - Retriggerable: calling trigger() again restarts from beginning
//
// TWEAKING PARAMETERS:
//
// Heavier impact:
// - Lower fundamental (40-50Hz)
// - Longer duration (4-5s)
// - Higher pitch drop (0.2-0.3)
//
// Shorter hit:
// - Decrease duration (1-2s)
// - Reduce pitch drop (0.05-0.1)
// - Shorter attack (0.02s)
//
// More attack punch:
// - Increase noise level (0.3 → 0.5 in code)
// - Extend noiseDuration (0.015 → 0.025)
//
// Darker tone:
// - Lower fundamental (40-45Hz)
// - Reduce upper harmonics: [1.0, 0.2, 0.1]
//
// Brighter tone:
// - Higher fundamental (70-80Hz)
// - Increase upper harmonics: [1.0, 0.6, 0.3]
//
// ============================================================
