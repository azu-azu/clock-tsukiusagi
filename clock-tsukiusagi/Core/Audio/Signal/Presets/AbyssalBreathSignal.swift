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
/// - Brown noise for distant water pressure
/// - Sub-bass sine (48 Hz) for deep underwater body
/// - Ultra-slow LFO (0.05 Hz) for breathing rhythm
/// - Depth-based amplitude modulation (25% depth)
///
/// Original parameters from AbyssalBreath.swift:
/// - noiseAmplitude: 0.10
/// - subSineFrequency: 48.0 Hz
/// - subSineAmplitude: 0.03
/// - lfoFrequency: 0.05 Hz (20 second cycle)
/// - lfoDepth: 0.25
public struct AbyssalBreathSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {
        // Ultra-slow breathing LFO
        let lfo = SignalLFO.sine(frequency: 0.05)

        // Map LFO with depth modulation
        // Original formula: 1.0 - (depth * (1.0 - lfoValue) / 2.0)
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let depth = 0.25
            let modulation = 1.0 - (depth * (1.0 - Double(lfoValue)) / 2.0)
            return Float(modulation)
        }

        // Sub-bass presence (48 Hz - very low)
        let subBass = Osc.sine(frequency: 48.0)

        // Brown noise (deep water pressure)
        let noise = Noise.brown()

        // Compose: (noise * 0.10 + subBass * 0.03) * modulatedAmplitude
        return Signal { t in
            let noisePart = noise(t) * 0.10
            let subPart = subBass(t) * 0.03
            return (noisePart + subPart) * modulatedAmplitude(t)
        }
    }

    /// Create SignalAudioSource (legacy method for direct AudioSource usage)
    public static func make(sampleRate: Double) -> SignalAudioSource {
        return SignalAudioSource(signal: makeSignal())
    }
}
