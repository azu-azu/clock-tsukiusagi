//
//  FinalMixer.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Multi-signal mixer with effects chain support
//

import Foundation

/// FinalMixer: Central mixing hub for multiple Signal sources with effects chain.
///
/// Architecture:
/// ```
/// Signal1 ─┐
/// Signal2 ─┼─→ Mix ─→ Effect1 ─→ Effect2 ─→ ... ─→ MasterGain ─→ Output
/// Signal3 ─┘
/// ```
///
/// Claude:
/// This is the core of the 3-layer SignalEngine architecture.
/// - Layer 1: Individual signals with per-signal gain
/// - Layer 2: Effects chain (filters, reverb, limiter)
/// - Layer 3: Master gain control
///
/// All processing is sample-rate independent and based on time.
public final class FinalMixer {

    // MARK: - Signal Storage

    /// Individual signals with their respective gain levels
    private var signals: [(signal: Signal, gain: Float)] = []

    // MARK: - Effects Chain

    /// Ordered array of effects to apply to the mixed signal
    /// Effects are applied in the order they appear in this array
    private var effects: [AudioEffect] = []

    // MARK: - Master Controls

    /// Master gain applied after all effects (0.0 to 1.0)
    public var masterGain: Float = 1.0

    // MARK: - Initialization

    public init() {
        // Empty mixer, ready to receive signals and effects
    }

    // MARK: - Signal Management

    /// Add a signal to the mixer with optional gain
    /// - Parameters:
    ///   - signal: The Signal function to add
    ///   - gain: Individual gain for this signal (default: 1.0)
    public func add(_ signal: Signal, gain: Float = 1.0) {
        signals.append((signal: signal, gain: gain))
    }

    /// Remove all signals from the mixer
    public func clearSignals() {
        signals.removeAll()
    }

    /// Update the gain for a specific signal by index
    /// - Parameters:
    ///   - index: Signal index (0-based)
    ///   - gain: New gain value (0.0 to 1.0)
    public func setGain(for index: Int, gain: Float) {
        guard index >= 0 && index < signals.count else { return }
        signals[index].gain = max(0, min(1, gain))
    }

    // MARK: - Effects Management

    /// Add an effect to the effects chain
    /// Effects are applied in the order they are added
    /// - Parameter effect: The AudioEffect to add
    public func addEffect(_ effect: AudioEffect) {
        effects.append(effect)
    }

    /// Remove all effects from the chain
    public func clearEffects() {
        effects.removeAll()
    }

    /// Remove a specific effect by index
    /// - Parameter index: Effect index (0-based)
    public func removeEffect(at index: Int) {
        guard index >= 0 && index < effects.count else { return }
        effects.remove(at: index)
    }

    // MARK: - Output

    /// Generate the final mixed output at a given time
    /// - Parameter time: Current time in seconds
    /// - Returns: Mixed and processed audio sample (-1.0 to 1.0)
    public func output(time: Float) -> Float {
        // Step 1: Mix all signals
        var mixed: Float = 0.0
        for (signal, gain) in signals {
            mixed += signal(time) * gain
        }

        // Step 2: Apply effects chain
        var processed = mixed
        for effect in effects {
            processed = effect.process(processed, time: time)
        }

        // Step 3: Apply master gain
        let final = processed * masterGain

        // Step 4: Safety clipping (in case effects boost the signal)
        return max(-1.0, min(1.0, final))
    }

    /// Convert this FinalMixer to a Signal function
    /// - Returns: Signal that outputs the mixed result
    public func asSignal() -> Signal {
        return Signal { [weak self] time in
            guard let self = self else { return 0 }
            return self.output(time: time)
        }
    }
}

// MARK: - AudioEffect Protocol

/// Protocol for audio effects that can be added to FinalMixer
///
/// Effects process audio sample-by-sample in real-time.
/// All effects must be stateless or manage their own internal state.
public protocol AudioEffect {

    /// Process a single audio sample
    /// - Parameters:
    ///   - input: Input sample value
    ///   - time: Current time in seconds (for time-varying effects)
    /// - Returns: Processed output sample
    func process(_ input: Float, time: Float) -> Float

    /// Reset the effect's internal state (if any)
    /// Called when playback stops or switches presets
    func reset()
}
