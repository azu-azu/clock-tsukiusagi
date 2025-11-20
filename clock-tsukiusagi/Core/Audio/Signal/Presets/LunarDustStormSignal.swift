//
//  LunarDustStormSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Lunar Dust Storm — ultra-still pink noise
//

import Foundation

/// Lunar Dust Storm — airless moon surface dust
///
/// This preset creates an almost-static dust texture:
/// Components:
/// - Pink noise for dust texture
/// - Ultra-slow LFO (0.02 Hz) for minimal movement
/// - Very shallow depth (5%) for near-stillness
///
/// Original parameters from legacy AudioSource (LunarDustStorm.swift):
/// - noiseAmplitude: 0.10
/// - lfoFrequency: 0.02 Hz (50 second cycle)
/// - lfoDepth: 0.05 (5% modulation depth)
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax)
/// - LFO mapping converted from depth formula to canonical range formula
/// - Depth 0.05 maps to range: 0.975...1.0 (preserves original behavior)
public struct LunarDustStormSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let baseAmplitude: Float = 0.10
        let lfoMin = 0.975  // Equivalent to depth 0.05 at minimum
        let lfoMax = 1.0    // Equivalent to depth 0.05 at maximum
        let lfoFrequency = 0.02

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
