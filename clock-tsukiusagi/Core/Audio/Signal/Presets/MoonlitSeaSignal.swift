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
/// This preset uses SignalEngine to create a serene deep-sea ambiance:
/// - Pink noise for water texture
/// - Slow LFO (0.12 Hz) for breathing/wave motion
/// - Deep sine wave (110 Hz) for underwater body
///
/// Original parameters from MoonlitSea.swift:
/// - noiseAmplitude: 0.4
/// - lfoFrequency: 0.25 Hz
/// - lfoRange: 0.03 to 0.10
public struct MoonlitSeaSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {
        // Slow wave LFO (breathing pattern)
        let lfo = SignalLFO.sine(frequency: 0.12)

        // Low deep body (underwater presence)
        let deep = Osc.sine(frequency: 110)

        // Pink noise (water texture)
        let noise = Noise.pink()

        // Compose: (deep * lfo-modulated-amplitude) * 0.6 + noise * 0.08
        return Signal { t in
            // Calculate modulated amplitude inline
            let lfoValue = lfo(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            let modulatedAmp = Float(0.03 + (0.10 - 0.03) * Double(normalized))

            // Mix deep tone and noise
            let deepValue = deep(t) * modulatedAmp * 0.6
            let noiseValue = noise(t) * 0.08
            return deepValue + noiseValue
        }
    }
}
