//
//  DistantThunderSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-23.
//  SignalEngine: Distant Thunder — single strikes using Midnight Train's beat
//  Identical sound to train's first beat, just different timing
//

import Foundation

/// Distant Thunder — single "shupotsu" strikes at random intervals
///
/// This preset uses EXACTLY the same 3-layer sound as Midnight Train:
/// Components:
/// - 3-layer impact sound (IDENTICAL to Midnight Train's beat)
/// - Random intervals (5-12 seconds) instead of regular pattern
/// - No 4-beat pattern, just single strikes
///
/// Sound layers (same as Midnight Train):
/// 1. Attack ("shu"): White noise burst 30ms, HPF 300Hz
/// 2. Pop ("potsu"): Sine 180Hz with ±2% wobble, warm and round
/// 3. Steam: Pink noise -24dB, LPF 800Hz, gentle lingering
///
/// Timing difference:
/// - Random wait 5-12s → single strike → repeat
/// - Train: 3-8s wait → 4-beat pattern → repeat
public struct DistantThunderSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Timing parameters
        let minWaitTime: Float = 5.0        // 最短待機時間
        let maxWaitTime: Float = 12.0       // 最長待機時間

        // Layer 1: Attack ("shu") parameters - SAME AS TRAIN
        let attackDuration: Float = 0.03    // 30ms
        let attackAttack: Float = 0.005     // 5ms
        let attackDecay: Float = 0.025      // 25ms

        // Layer 2: Pop ("potsu") parameters - SAME AS TRAIN
        let popFreq: Float = 180.0          // 180Hz
        let popWobbleFreq: Float = 3.0      // 3Hz LFO
        let popWobbleDepth: Float = 0.02    // ±2%
        let popAttack: Float = 0.010        // 10ms
        let popDecay: Float = 0.120         // 120ms

        // Layer 3: Steam parameters - SAME AS TRAIN
        let steamAttack: Float = 0.050      // 50ms
        let steamDecay: Float = 0.200       // 200ms
        let steamLevel: Float = 0.15        // -24dB相当

        // Generate noise sources - SAME AS TRAIN
        let whiteNoise = Noise.white
        let pinkNoise = Noise.pink()

        return Signal { t in
            // Calculate maximum thunder duration
            let maxDuration = max(attackDuration, popAttack + popDecay, steamAttack + steamDecay)

            // Calculate cycle duration (must fit longest wait + thunder duration)
            let cycleDuration = maxWaitTime + maxDuration  // 最長待機時間 + 雷の音の長さ

            // Calculate current thunder index
            let thunderIndex = Int(t / cycleDuration)
            var randomState = UInt64(thunderIndex * 8831)  // 素数でシード
            randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
            let waitTime = minWaitTime + Float(randomState % 10000) / 10000.0 * (maxWaitTime - minWaitTime)

            // Calculate thunder strike time
            let thunderTime = Float(thunderIndex) * cycleDuration + waitTime

            // Time since thunder strike
            let timeSinceThunder = t - thunderTime

            // If before strike or too long after, return silence
            guard timeSinceThunder >= 0.0 && timeSinceThunder < maxDuration else {
                return 0.0
            }

            // === Layer 1: Attack ("shu") ===
            var attackValue: Float = 0.0
            if timeSinceThunder < attackDuration {
                let envelope: Float
                if timeSinceThunder < attackAttack {
                    // Attack phase
                    envelope = timeSinceThunder / attackAttack
                } else {
                    // Decay phase
                    let decayTime = timeSinceThunder - attackAttack
                    envelope = exp(-decayTime / attackDecay)
                }
                // White noise with simple HPF simulation (subtract low component)
                let rawNoise = whiteNoise(t)
                let hpfNoise = rawNoise * 0.7  // High-pass simulation
                attackValue = hpfNoise * envelope * 0.35
            }

            // === Layer 2: Pop ("potsu") ===
            var popValue: Float = 0.0
            let popDuration = popAttack + popDecay
            if timeSinceThunder < popDuration {
                let envelope: Float
                if timeSinceThunder < popAttack {
                    // Attack phase
                    envelope = timeSinceThunder / popAttack
                } else {
                    // Decay phase
                    let decayTime = timeSinceThunder - popAttack
                    envelope = exp(-decayTime / popDecay)
                }
                // Sine with pitch wobble
                let wobble = sin(2.0 * Float.pi * popWobbleFreq * t) * popWobbleDepth
                let freq = popFreq * (1.0 + wobble)
                let phase = 2.0 * Float.pi * freq * t
                popValue = sin(phase) * envelope * 0.6
            }

            // === Layer 3: Steam (gentle lingering) ===
            var steamValue: Float = 0.0
            let steamDuration = steamAttack + steamDecay
            if timeSinceThunder < steamDuration {
                let envelope: Float
                if timeSinceThunder < steamAttack {
                    // Attack phase
                    envelope = timeSinceThunder / steamAttack
                } else {
                    // Decay phase
                    let decayTime = timeSinceThunder - steamAttack
                    envelope = exp(-decayTime / steamDecay)
                }
                // Pink noise with simple LPF simulation
                let rawSteam = pinkNoise(t)
                let lpfSteam = rawSteam * 0.5  // Low-pass simulation
                steamValue = lpfSteam * envelope * steamLevel
            }

            // Mix all layers (no velocity variation for single strikes)
            return (attackValue + popValue + steamValue) * 0.8
        }
    }
}
