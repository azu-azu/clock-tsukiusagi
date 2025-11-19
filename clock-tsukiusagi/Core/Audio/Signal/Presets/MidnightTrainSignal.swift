//
//  MidnightTrainSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Midnight Train — rhythmic brown noise
//

import Foundation

/// Midnight Train — rhythmic rumbling of a night train
///
/// This preset creates the sound of a train moving through the night:
/// - Brown noise for deep mechanical rumble
/// - Fast sine LFO (1.0 Hz) for rhythmic "clack-clack" pattern
/// - Amplitude range 0.03 to 0.12 for pronounced rhythm
///
/// Original parameters from MidnightTrain.swift:
/// - noiseAmplitude: 0.3
/// - lfoFrequency: 1.0 Hz (rhythmic pattern)
/// - lfoRange: 0.03 to 0.12
public struct MidnightTrainSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Rhythmic LFO (train clack-clack pattern)
        let lfo = SignalLFO.sine(frequency: 1.0)

        // Map LFO from -1...1 to 0.03...0.12 (amplitude range)
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(0.03 + (0.12 - 0.03) * Double(normalized))
        }

        // Brown noise (deep mechanical rumble)
        let noise = Noise.brown()

        // Compose: noise * baseAmplitude * modulatedAmplitude
        return Signal { t in
            noise(t) * 0.3 * modulatedAmplitude(t)
        }
    }
}
