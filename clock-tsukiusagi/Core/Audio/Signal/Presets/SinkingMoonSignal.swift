//
//  SinkingMoonSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Sinking Moon — fading 432Hz sine tone
//

import Foundation

/// Sinking Moon — softly fading celestial tone
///
/// This preset creates a meditative fading tone:
/// - Pure sine (432 Hz) for calming frequency
/// - Ultra-slow LFO (0.04 Hz) for gentle fade
/// - Moderate depth (25%) for noticeable but gentle variation
///
/// Original parameters from SinkingMoon.swift:
/// - sineFrequency: 432.0 Hz
/// - sineAmplitude: 0.06
/// - lfoFrequency: 0.04 Hz (25 second cycle)
/// - lfoDepth: 0.25
public struct SinkingMoonSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Ultra-slow fade LFO
        let lfo = SignalLFO.sine(frequency: 0.04)

        // Map LFO with depth modulation
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let depth = 0.25
            let modulation = 1.0 - (depth * (1.0 - Double(lfoValue)) / 2.0)
            return Float(modulation)
        }

        // Pure sine tone (432 Hz)
        let tone = Osc.sine(frequency: 432.0)

        // Compose: tone * baseAmplitude * modulatedAmplitude
        return Signal { t in
            tone(t) * 0.06 * modulatedAmplitude(t)
        }
    }

    /// Create SignalAudioSource (legacy method for direct AudioSource usage)
    public static func make(sampleRate: Double) -> SignalAudioSource {
        return SignalAudioSource(signal: makeSignal())
    }
}
