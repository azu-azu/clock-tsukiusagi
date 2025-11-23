//
//  MidnightTrainSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Midnight Train — rhythmic brown noise
//

import Foundation

/// Midnight Train — rhythmic rumbling with steam puffs
///
/// This preset creates the sound of a train moving through the night:
/// Components:
/// - Brown noise for deep mechanical rumble
/// - Fast sine LFO (1.0 Hz) for rhythmic "clack-clack" pattern
/// - Random steam puffs (シュポォツ, シュポッ, シュポッ) every 3-8 seconds
/// - Amplitude range 0.10 to 0.40 (expanded for better presence)
///
/// Original parameters from legacy AudioSource (MidnightTrain.swift):
/// - noiseAmplitude: 0.3
/// - lfoFrequency: 1.0 Hz (rhythmic pattern)
/// - lfoRange: 0.03 to 0.12 (original)
///
/// Modifications:
/// - Structure unified to standard 6-step Signal pattern
/// - Parameter naming standardized (baseAmplitude, lfoMin, lfoMax)
/// - LFO mapping uses canonical formula
/// - Expanded LFO range to 0.10...0.40 to match other presets' max volume (~0.12)
/// - Added steam puff bursts for characteristic train sound
public struct MidnightTrainSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // 1. Define constants
        let lfoMin = 0.08
        let lfoMax = 0.25
        let lfoFrequency = 1.0

        // Steam puff parameters
        let puffMinInterval: Float = 3.0
        let puffMaxInterval: Float = 8.0
        let puffDuration: Float = 0.4      // シュポォツの長さ
        let puffAmplitude: Float = 0.35    // 蒸気の音量

        // 2. Define LFO (simple sine)
        let lfo = SignalLFO.sine(frequency: lfoFrequency)

        // 3. Normalize LFO (0...1)
        // 4. Map amplitude (lfoMin...lfoMax)
        let modulatedAmplitude = Signal { t in
            let lfoValue = lfo(t)
            let normalized = (lfoValue + 1) * 0.5  // 0...1
            return Float(lfoMin + (lfoMax - lfoMin) * Double(normalized))
        }

        // 5. Generate base noise
        let noise = Noise.brown(smoothing: 0.1)
        let steamNoise = Noise.white  // 蒸気用ホワイトノイズ

        // 6. Return final signal with steam puffs
        return Signal { t in
            let baseSound = noise(t) * modulatedAmplitude(t)

            // Steam puff calculation (random intervals)
            let puffIndex = Int(t / puffMinInterval)
            var randomState = UInt64(puffIndex * 9973)  // 素数でシード
            randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
            let randomOffset = Float(randomState % 10000) / 10000.0 * (puffMaxInterval - puffMinInterval)
            let puffStartTime = Float(puffIndex) * puffMinInterval + randomOffset

            // Check if we're in a puff
            let timeSincePuff = t - puffStartTime
            if timeSincePuff >= 0.0 && timeSincePuff < puffDuration {
                // Envelope: quick attack, exponential decay
                let envelope = exp(-timeSincePuff / (puffDuration * 0.3))
                let puffValue = steamNoise(t)  // ホワイトノイズでシュッという音
                return baseSound + puffValue * envelope * puffAmplitude
            }

            return baseSound
        }
    }
}
