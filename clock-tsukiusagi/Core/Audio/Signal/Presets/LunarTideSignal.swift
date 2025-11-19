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
/// - Pink noise for water texture
/// - Sine LFO (0.18 Hz) for gentle wave motion
/// - Depth-based amplitude modulation (35% depth)
///
/// Original parameters from LunarTide.swift:
/// - noiseAmplitude: 0.12
/// - lfoFrequency: 0.18 Hz
/// - lfoDepth: 0.35 (modulation depth)
public struct LunarTideSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {
        // Wave motion LFO
        let lfo = SignalLFO.sine(frequency: 0.18)

        // Map LFO with depth modulation
        // Original formula: 1.0 - (depth * (1.0 - lfoValue) / 2.0)
        // where lfoValue is -1...1 from sin
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let depth = 0.35
            let modulation = 1.0 - (depth * (1.0 - Double(lfoValue)) / 2.0)
            return Float(modulation)
        }

        // Pink noise (water texture)
        let noise = Noise.pink()

        // Compose: noise * baseAmplitude * modulatedAmplitude
        return Signal { t in
            noise(t) * 0.12 * modulatedAmplitude(t)
        }
    }
}
