//
//  LunarTideSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Lunar Tide — moonlit ocean surface
//

import Foundation

/// Lunar Tide — moonlit ocean surface with gentle waves
///
/// This preset creates the sound of moonlight reflecting on water:
/// Components:
/// - Pink noise for water texture
/// - Sine LFO (0.18 Hz) for gentle wave motion
/// - Amplitude range based on depth modulation (35% depth)
///
/// Original parameters from legacy AudioSource (LunarTide.swift):
/// - noiseAmplitude: 0.12
/// - lfoFrequency: 0.18 Hz
/// - lfoDepth: 0.35 (35% modulation depth)
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax)
/// - LFO mapping converted from depth formula to canonical range formula
/// - Depth 0.35 maps to range: 0.825...1.0 (preserves original behavior)
public struct LunarTideSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let baseAmplitude: Float = 0.12
        let lfoMin = 0.825  // Equivalent to depth 0.35 at minimum
        let lfoMax = 1.0    // Equivalent to depth 0.35 at maximum
        let lfoFrequency = 0.18

        // 2. Define LFO (simple sine)
        let lfo = SignalLFO.sine(frequency: lfoFrequency)

        // 3. Normalize LFO (0...1)
        // 4. Map amplitude (lfoMin...lfoMax)
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(lfoMin + (lfoMax - lfoMin) * Double(normalized))
        }

        // 5. Generate base noise
        let noise = Noise.pink()

        // 6. Return final signal
        return Signal { t in
            noise(t) * baseAmplitude * modulatedAmplitude(t)
        }
    }
}
