//
//  LunarPulseSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Lunar Pulse — soft light breathing with pure tone
//

import Foundation

/// Lunar Pulse — soft light breathing with pure tone
///
/// This preset creates a gentle pulsing tone like moonlight breathing:
/// - Pure sine tone (528 Hz) for celestial quality
/// - Ultra-slow LFO (0.06 Hz) for breathing rhythm
/// - Very quiet amplitude range (0.02 to 0.12)
///
/// Original parameters from LunarPulse.swift:
/// - frequency: 528 Hz (Solfeggio frequency)
/// - amplitude: 0.2
/// - lfoFrequency: 0.06 Hz (16.7 second cycle)
/// - lfoRange: 0.02 to 0.12
public struct LunarPulseSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {
        // Ultra-slow breathing LFO
        let lfo = SignalLFO.sine(frequency: 0.06)

        // Map LFO from -1...1 to 0.02...0.12 (amplitude range)
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(0.02 + (0.12 - 0.02) * Double(normalized))
        }

        // Pure tone at 528 Hz (Solfeggio frequency)
        let tone = Osc.sine(frequency: 528.0)

        // Compose: tone * baseAmplitude * modulatedAmplitude
        return Signal { t in
            tone(t) * 0.2 * modulatedAmplitude(t)
        }
    }

    /// Create SignalAudioSource (legacy method for direct AudioSource usage)
    public static func make(sampleRate: Double) -> SignalAudioSource {
        return SignalAudioSource(signal: makeSignal())
    }
}
