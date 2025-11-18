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
/// - Fundamental frequency (220 Hz - A3)
/// - Rich harmonic structure (5 harmonics)
/// - Slow vibrato (5 Hz) for living quality
///
/// Original parameters from TibetanBowl.swift:
/// - fundamentalFrequency: 220 Hz (varies by preset)
/// - amplitude: 0.2
/// - harmonics: Array of (multiplier, amplitude) pairs
/// - vibratoFrequency: 5.0 Hz
/// - vibratoDepth: 0.02 (2% pitch modulation)
public struct TibetanBowlSignal {

    public static func make(sampleRate: Double) -> SignalAudioSource {

        let fundamentalFreq = 220.0  // A3

        // Harmonic structure (multiplier, relative amplitude)
        let harmonics: [(Double, Float)] = [
            (1.0, 1.0),      // Fundamental
            (2.0, 0.5),      // 1st overtone
            (3.0, 0.3),      // 2nd overtone
            (4.0, 0.2),      // 3rd overtone
            (5.0, 0.1)       // 4th overtone
        ]

        // Vibrato LFO (5 Hz)
        let vibrato = SignalLFO.sine(frequency: 5.0)

        let bowlSignal = Signal { t in
            // Calculate pitch modulation from vibrato
            let vibratoValue = vibrato(t)
            let pitchMod = 1.0 + (Double(vibratoValue) * 0.02)  // ±2% pitch variation

            // Sum all harmonics
            var mixedSample: Float = 0.0

            for (harmonicMultiplier, harmonicAmplitude) in harmonics {
                let harmonicFreq = fundamentalFreq * harmonicMultiplier * pitchMod
                let phase = Float(2.0 * .pi * harmonicFreq) * t
                mixedSample += sin(phase) * harmonicAmplitude
            }

            // Normalize and apply overall amplitude
            let normalizedSample = mixedSample / Float(harmonics.count)
            return normalizedSample * 0.2
        }

        return SignalAudioSource(signal: bowlSignal)
    }
}
