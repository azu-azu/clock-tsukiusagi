//
//  MoonlitSeaSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Moonlit Silent Sea — deep slow breathing ocean
//

import Foundation

/// Moonlit Silent Sea — deep slow breathing ocean
///
/// This preset creates a serene deep-sea ambiance with rhythmic breathing:
/// Components:
/// - Pink noise for water texture
/// - Slow LFO (0.12 Hz) for breathing/wave motion
/// - Deep sine wave (110 Hz) for underwater body
///
/// Original parameters from legacy AudioSource (MoonlitSea.swift):
/// - noiseAmplitude: 0.4 (split: deep tone base 0.6, noise 0.08)
/// - lfoFrequency: 0.25 Hz (adjusted to 0.12 Hz for slower breathing)
/// - lfoRange: 0.03 to 0.10 (for deep tone modulation)
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax)
/// - LFO mapping uses canonical formula
public struct MoonlitSeaSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let baseAmplitudeDeep: Float = 0.6
        let baseAmplitudeNoise: Float = 0.08
        let lfoMin = 0.03
        let lfoMax = 0.10
        let lfoFrequency = 0.12
        let deepFrequency = 110.0

        // 2. Define LFO (simple sine)
        let lfo = SignalLFO.sine(frequency: lfoFrequency)

        // 3. Normalize LFO (0...1)
        // 4. Map amplitude (lfoMin...lfoMax)
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(lfoMin + (lfoMax - lfoMin) * Double(normalized))
        }

        // 5. Generate base sources
        let deep = Osc.sine(frequency: deepFrequency)
        let noise = Noise.pink()

        // 6. Return final signal
        return Signal { t in
            let deepValue = deep(t) * baseAmplitudeDeep * modulatedAmplitude(t)
            let noiseValue = noise(t) * baseAmplitudeNoise
            return deepValue + noiseValue
        }
    }
}
