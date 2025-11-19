//
//  DawnHintSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Dawn Hint — brightening pink noise
//

import Foundation

/// Dawn Hint — the first light of morning
///
/// This preset creates a gradually brightening atmosphere:
/// Components:
/// - Pink noise for warm morning air
/// - Moderate LFO (0.10 Hz) for gentle breathing
/// - Deeper modulation (40%) for noticeable brightness variation
///
/// Original parameters from legacy AudioSource (DawnHint.swift):
/// - noiseAmplitude: 0.08
/// - lfoFrequency: 0.10 Hz (10 second cycle)
/// - lfoDepth: 0.40 (40% modulation depth)
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax)
/// - LFO mapping converted from depth formula to canonical range formula
/// - Depth 0.40 maps to range: 0.80...1.0 (preserves original behavior)
public struct DawnHintSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let baseAmplitude: Float = 0.08
        let lfoMin = 0.80   // Equivalent to depth 0.40 at minimum
        let lfoMax = 1.0    // Equivalent to depth 0.40 at maximum
        let lfoFrequency = 0.10

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
