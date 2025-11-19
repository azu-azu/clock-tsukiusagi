//
//  LunarDustStormSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Lunar Dust Storm — ultra-still pink noise
//

import Foundation

/// Lunar Dust Storm — airless moon surface dust
///
/// This preset creates an almost-static dust texture:
/// - Pink noise for dust texture
/// - Ultra-slow LFO (0.02 Hz) for minimal movement
/// - Very shallow depth (5%) for near-stillness
///
/// Original parameters from LunarDustStorm.swift:
/// - noiseAmplitude: 0.10
/// - lfoFrequency: 0.02 Hz (50 second cycle)
/// - lfoDepth: 0.05 (very minimal modulation)
public struct LunarDustStormSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Ultra-slow stillness LFO
        let lfo = SignalLFO.sine(frequency: 0.02)

        // Map LFO with very shallow depth
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let depth = 0.05
            let modulation = 1.0 - (depth * (1.0 - Double(lfoValue)) / 2.0)
            return Float(modulation)
        }

        // Pink noise (lunar dust)
        let noise = Noise.pink()

        // Compose: noise * baseAmplitude * modulatedAmplitude
        return Signal { t in
            noise(t) * 0.10 * modulatedAmplitude(t)
        }
    }
}
