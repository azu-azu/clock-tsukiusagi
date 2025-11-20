//
//  SinkingMoonSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Sinking Moon — fading 432Hz sine tone
//

import Foundation

/// Sinking Moon — softly fading celestial tone
///
/// This preset creates a meditative fading tone:
/// Components:
/// - Pure sine (432 Hz) for calming frequency
/// - Ultra-slow LFO (0.04 Hz) for gentle fade
/// - Moderate depth (25%) for noticeable but gentle variation
///
/// Original parameters from legacy AudioSource (SinkingMoon.swift):
/// - sineFrequency: 432.0 Hz
/// - sineAmplitude: 0.06
/// - lfoFrequency: 0.04 Hz (25 second cycle)
/// - lfoDepth: 0.25 (25% modulation depth)
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax)
/// - LFO mapping converted from depth formula to canonical range formula
/// - Depth 0.25 maps to range: 0.875...1.0 (preserves original behavior)
public struct SinkingMoonSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let baseAmplitude: Float = 0.06
        let lfoMin = 0.875  // Equivalent to depth 0.25 at minimum
        let lfoMax = 1.0    // Equivalent to depth 0.25 at maximum
        let lfoFrequency = 0.04
        let toneFrequency = 432.0

        // 2. Define LFO (simple sine)
        let lfo = SignalLFO.sine(frequency: lfoFrequency)

        // 3. Normalize LFO (0...1)
        // 4. Map amplitude (lfoMin...lfoMax)
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(lfoMin + (lfoMax - lfoMin) * Double(normalized))
        }

        // 5. Generate base tone
        let tone = Osc.sine(frequency: toneFrequency)

        // 6. Return final signal
        return Signal { t in
            tone(t) * baseAmplitude * modulatedAmplitude(t)
        }
    }
}
