//
//  AbyssalBreathSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Abyssal Breath — deep sea breathing with sub-bass
//

import Foundation

/// Abyssal Breath — deep sea breathing with sub-bass presence
///
/// This preset creates the sound of deep ocean breathing:
/// Components:
/// - Brown noise for distant water pressure
/// - Sub-bass sine (48 Hz) for deep underwater body
/// - Ultra-slow LFO (0.05 Hz) for breathing rhythm
/// - Amplitude range based on depth modulation (25% depth)
///
/// Original parameters from legacy AudioSource (AbyssalBreath.swift):
/// - noiseAmplitude: 0.10
/// - subSineFrequency: 48.0 Hz
/// - subSineAmplitude: 0.03
/// - lfoFrequency: 0.05 Hz (20 second cycle)
/// - lfoDepth: 0.25 (25% modulation depth)
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax)
/// - LFO mapping converted from depth formula to canonical range formula
/// - Depth 0.25 maps to range: 0.875...1.0 (preserves original behavior)
public struct AbyssalBreathSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let baseAmplitudeNoise: Float = 0.10
        let baseAmplitudeSubBass: Float = 0.03
        let lfoMin = 0.875  // Equivalent to depth 0.25 at minimum
        let lfoMax = 1.0    // Equivalent to depth 0.25 at maximum
        let lfoFrequency = 0.05
        let subBassFrequency = 48.0

        // 2. Define LFO (simple sine)
        let lfo = SignalLFO.sine(frequency: lfoFrequency)

        // 3. Normalize LFO (0...1)
        // 4. Map amplitude (lfoMin...lfoMax)
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(lfoMin + (lfoMax - lfoMin) * Double(normalized))
        }

        // 5. Generate base sources
        let subBass = Osc.sine(frequency: subBassFrequency)
        let noise = Noise.brown()

        // 6. Return final signal
        return Signal { t in
            let noisePart = noise(t) * baseAmplitudeNoise
            let subPart = subBass(t) * baseAmplitudeSubBass
            return (noisePart + subPart) * modulatedAmplitude(t)
        }
    }
}
