//
//  SilentLibrarySignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Silent Library — ultra-quiet brown noise
//

import Foundation

/// Silent Library — the sound of complete stillness
///
/// This preset creates the quietest ambient texture:
/// Components:
/// - Brown noise for deep room tone
/// - Extremely slow LFO (0.01 Hz) for breath-like movement
/// - Minimal depth (3%) for near-imperceptible variation
///
/// Original parameters from legacy AudioSource (SilentLibrary.swift):
/// - noiseAmplitude: 0.10
/// - lfoFrequency: 0.01 Hz (100 second cycle)
/// - lfoDepth: 0.03 (3% modulation depth)
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax)
/// - LFO mapping converted from depth formula to canonical range formula
/// - Depth 0.03 maps to range: 0.985...1.0 (preserves original behavior)
public struct SilentLibrarySignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let baseAmplitude: Float = 0.10
        let lfoMin = 0.985  // Equivalent to depth 0.03 at minimum
        let lfoMax = 1.0    // Equivalent to depth 0.03 at maximum
        let lfoFrequency = 0.01

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
        let noise = Noise.brown()

        // 6. Return final signal
        return Signal { t in
            noise(t) * baseAmplitude * modulatedAmplitude(t)
        }
    }
}
