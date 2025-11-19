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
/// Components:
/// - Pure sine tone (528 Hz) for celestial quality
/// - Ultra-slow LFO (0.06 Hz) for breathing rhythm
/// - Quiet amplitude range (0.02 to 0.12)
///
/// Original parameters from legacy AudioSource (LunarPulse.swift):
/// - frequency: 528 Hz (Solfeggio frequency)
/// - amplitude: 0.2
/// - lfoFrequency: 0.06 Hz (16.7 second cycle)
/// - lfoRange: 0.02 to 0.12
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax)
/// - LFO mapping uses canonical formula
public struct LunarPulseSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let baseAmplitude: Float = 0.2
        let lfoMin = 0.02
        let lfoMax = 0.12
        let lfoFrequency = 0.06
        let toneFrequency = 528.0

        // 2. Define LFO (simple sine)
        let lfo = SignalLFO.sine(frequency: lfoFrequency)

        // 3. Normalize LFO (0...1)
        // 4. Map amplitude (lfoMin...lfoMax)
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(lfoMin + (lfoMax - lfoMin) * Double(normalized))
        }

        // 5. Generate base tone
        let tone = Osc.sine(frequency: toneFrequency)

        // 6. Return final signal
        return Signal { t in
            tone(t) * baseAmplitude * modulatedAmplitude(t)
        }
    }
}
