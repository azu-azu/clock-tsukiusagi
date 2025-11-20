//
//  DarkSharkSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Dark Shark Shadow — brown noise with wandering LFO
//

import Foundation

/// Dark Shark Shadow — brown noise with wandering presence
///
/// This preset creates a menacing underwater presence:
/// Components:
/// - Brown noise for deep rumbling texture
/// - Wandering LFO with frequency drift (base 0.115 Hz, drift rate 0.0005)
/// - Amplitude range 0.075 to 0.30 (expanded for better presence)
///
/// Original parameters from legacy AudioSource (DarkShark.swift):
/// - noiseAmplitude: 0.4
/// - lfoFrequency: Random 0.05-0.18 Hz (changes every ~5s)
/// - lfoRange: 0.02 to 0.08 (original)
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax, driftAmount)
/// - LFO mapping uses canonical formula
/// - Expanded LFO range to 0.075...0.30 to match other presets' max volume (~0.12)
/// - Wandering LFO implemented using drift modulation
public struct DarkSharkSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let lfoMin = 0.06
        let lfoMax = 0.20
        let lfoFrequency = 0.115  // Mid-point of 0.05-0.18
        let driftRate: Float = 0.0005
        let driftAmount: Float = 0.3

        // 2. Define LFO (wandering with drift)
        let baseLFO = SignalLFO.sine(frequency: lfoFrequency)
        let drift = SignalLFO.drift(rate: driftRate)

        let wanderingLFO = Signal { t in
            let base = baseLFO(t)
            let driftValue = drift(t)
            return base * (1.0 + driftValue * driftAmount)
        }

        // 3. Normalize LFO (0...1)
        // 4. Map amplitude (lfoMin...lfoMax)
        let modulatedAmplitude = Signal { t in
            let lfoValue = wanderingLFO(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(lfoMin + (lfoMax - lfoMin) * Double(normalized))
        }

        // 5. Generate base noise
        let noise = Noise.brown(smoothing: 0.1)

        // 6. Return final signal
        return Signal { t in
            noise(t) * modulatedAmplitude(t)
        }
    }
}
