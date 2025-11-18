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
/// - Brown noise for deep room tone
/// - Extremely slow LFO (0.01 Hz) for breath-like movement
/// - Minimal depth (3%) for near-imperceptible variation
///
/// Original parameters from SilentLibrary.swift:
/// - noiseAmplitude: 0.10
/// - lfoFrequency: 0.01 Hz (100 second cycle)
/// - lfoDepth: 0.03 (3% modulation)
public struct SilentLibrarySignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Ultra-slow stillness LFO
        let lfo = SignalLFO.sine(frequency: 0.01)

        // Map LFO with minimal depth
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let depth = 0.03
            let modulation = 1.0 - (depth * (1.0 - Double(lfoValue)) / 2.0)
            return Float(modulation)
        }

        // Brown noise (library room tone)
        let noise = Noise.brown()

        // Compose: noise * baseAmplitude * modulatedAmplitude
        return Signal { t in
            noise(t) * 0.10 * modulatedAmplitude(t)
        }
    }

    /// Create SignalAudioSource (legacy method for direct AudioSource usage)
    public static func make(sampleRate: Double) -> SignalAudioSource {
        return SignalAudioSource(signal: makeSignal())
    }
}
