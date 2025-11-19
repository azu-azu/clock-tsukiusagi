//
//  TibetanBowlSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Tibetan Bowl — harmonic singing bowl
//

import Foundation

/// Tibetan Bowl — deep harmonic resonance
///
/// This preset creates a meditative singing bowl sound:
/// Components:
/// - Fundamental frequency (220 Hz - A3)
/// - Rich harmonic structure (5 harmonics)
/// - Slow vibrato (5 Hz) for living quality
///
/// Original parameters from legacy AudioSource (TibetanBowl.swift):
/// - fundamentalFrequency: 220 Hz (varies by preset)
/// - amplitude: 0.2
/// - harmonics: Array of (multiplier, amplitude) pairs
/// - vibratoFrequency: 5.0 Hz
/// - vibratoDepth: 0.02 (2% pitch modulation)
///
/// Modifications:
/// - Structure unified to standard pattern
/// - Parameter naming standardized (baseAmplitude, vibratoFreq, vibratoDepth)
/// - Documentation follows standard format
public struct TibetanBowlSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let baseAmplitude: Float = 0.2
        let fundamentalFreq = 220.0  // A3
        let vibratoFreq = 5.0
        let vibratoDepth = 0.02

        // Harmonic structure (multiplier, relative amplitude)
        let harmonics: [(Double, Float)] = [
            (1.0, 1.0),      // Fundamental
            (2.0, 0.5),      // 1st overtone
            (3.0, 0.3),      // 2nd overtone
            (4.0, 0.2),      // 3rd overtone
            (5.0, 0.1)       // 4th overtone
        ]

        // 2. Define vibrato LFO
        let vibrato = SignalLFO.sine(frequency: vibratoFreq)

        // 3-6. Generate and return final signal
        return Signal { t in
            // Calculate pitch modulation from vibrato
            let vibratoValue = vibrato(t)
            let pitchMod = 1.0 + (Double(vibratoValue) * vibratoDepth)

            // Sum all harmonics
            var mixedSample: Float = 0.0

            for (harmonicMultiplier, harmonicAmplitude) in harmonics {
                let harmonicFreq = fundamentalFreq * harmonicMultiplier * pitchMod
                let phase = Float(2.0 * .pi * harmonicFreq) * t
                mixedSample += sin(phase) * harmonicAmplitude
            }

            // Normalize and apply overall amplitude
            let normalizedSample = mixedSample / Float(harmonics.count)
            return normalizedSample * baseAmplitude
        }
    }
}
