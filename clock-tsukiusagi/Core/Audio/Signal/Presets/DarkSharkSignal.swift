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
/// - Brown noise for deep rumbling texture
/// - Random LFO that changes frequency (0.05-0.18 Hz)
/// - Amplitude range 0.075 to 0.30 (expanded for better presence)
///
/// Original parameters from DarkShark.swift:
/// - noiseAmplitude: 0.4
/// - lfoFrequency: Random 0.05-0.18 Hz (changes every ~5s)
/// - lfoRange: 0.075 to 0.30 (expanded from original 0.02-0.08)
public struct DarkSharkSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Random wandering LFO (frequency drifts)
        // Combine slow sine with drift to mimic the frequency-changing behavior
        let baseLFO = SignalLFO.sine(frequency: 0.115)  // Mid-point of 0.05-0.18
        let drift = SignalLFO.drift(rate: 0.0005)  // Very slow drift

        let wanderingLFO = Signal { t in
            let base = baseLFO(t)
            let driftAmount = drift(t)
            return base * (1.0 + driftAmount * 0.3)  // Modulate the LFO itself
        }

        // Map LFO from -1...1 to 0.075...0.30 (amplitude range)
        // Expanded range for better volume presence (0.4 * 0.30 = 0.12 max)
        // Wider dynamics enhance the "shadow wavering" effect
        let modulatedAmplitude = Signal { t in
            let lfoValue = wanderingLFO(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(0.075 + (0.30 - 0.075) * Double(normalized))
        }

        // Brown noise (deep rumbling texture)
        let noise = Noise.brown()

        // Compose: noise * baseAmplitude * modulatedAmplitude
        return Signal { t in
            noise(t) * 0.4 * modulatedAmplitude(t)
        }
    }
}
