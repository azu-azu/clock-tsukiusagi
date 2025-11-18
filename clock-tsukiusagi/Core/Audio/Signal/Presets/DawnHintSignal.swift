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
/// - Pink noise for warm morning air
/// - Moderate LFO (0.10 Hz) for gentle breathing
/// - Deeper modulation (40%) for noticeable brightness variation
///
/// Original parameters from DawnHint.swift:
/// - noiseAmplitude: 0.08
/// - lfoFrequency: 0.10 Hz (10 second cycle)
/// - lfoDepth: 0.40 (40% modulation)
public struct DawnHintSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Brightening LFO
        let lfo = SignalLFO.sine(frequency: 0.10)

        // Map LFO with deeper modulation for brightness
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let depth = 0.40
            let modulation = 1.0 - (depth * (1.0 - Double(lfoValue)) / 2.0)
            return Float(modulation)
        }

        // Pink noise (morning warmth)
        let noise = Noise.pink()

        // Compose: noise * baseAmplitude * modulatedAmplitude
        return Signal { t in
            noise(t) * 0.08 * modulatedAmplitude(t)
        }
    }

    /// Create SignalAudioSource (legacy method for direct AudioSource usage)
    public static func make(sampleRate: Double) -> SignalAudioSource {
        return SignalAudioSource(signal: makeSignal())
    }
}
