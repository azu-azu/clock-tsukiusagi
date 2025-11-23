//
//  MidnightTrainSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Midnight Train — cute "shupotsu" steam train
//  Based on Fujiko's proposal for warm, rabbit-carriage atmosphere
//

import Foundation

/// Midnight Train — cute steam train with "shupotsu" sound
///
/// This preset creates the sound of a small steam locomotive:
/// Components:
/// - 3-layer sound structure (Attack/Pop/Steam)
/// - 4-beat pattern with gentle rhythm (strong, strong, weak, strong)
/// - Random intervals (3-8 seconds) between pattern bursts
///
/// Sound layers:
/// 1. Attack ("shu"): White noise burst 10-30ms, HPF 300Hz
/// 2. Pop ("potsu"): Sine 180Hz with ±2% wobble, warm and round
/// 3. Steam: Pink noise -24dB, LPF 800Hz, gentle lingering
///
/// Rhythm structure:
/// - Random wait 3-8s → 4-beat pattern (0.55s interval) → repeat
/// - Beat 3 has 80% velocity for natural feel
/// - Creates "rabbit carriage" atmosphere suitable for Azu world
public struct MidnightTrainSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Timing parameters
        let beatInterval: Float = 0.55      // 間隔（BPM 109相当）
        let patternBeats: Int = 4           // 4拍パターン
        let minWaitTime: Float = 3.0        // 最短待機時間
        let maxWaitTime: Float = 8.0        // 最長待機時間

        // Layer 1: Attack ("shu") parameters
        let attackDuration: Float = 0.03    // 30ms
        let attackAttack: Float = 0.005     // 5ms
        let attackDecay: Float = 0.025      // 25ms

        // Layer 2: Pop ("potsu") parameters
        let popFreq: Float = 180.0          // 180Hz
        let popWobbleFreq: Float = 3.0      // 3Hz LFO
        let popWobbleDepth: Float = 0.02    // ±2%
        let popAttack: Float = 0.010        // 10ms
        let popDecay: Float = 0.120         // 120ms

        // Layer 3: Steam parameters
        let steamAttack: Float = 0.050      // 50ms
        let steamDecay: Float = 0.200       // 200ms
        let steamLevel: Float = 0.15        // -24dB相当

        // Generate noise sources
        let whiteNoise = Noise.white
        let pinkNoise = Noise.pink()

        return Signal { t in
            // Calculate current pattern index
            let patternDuration = Float(patternBeats) * beatInterval
            let cycleDuration = minWaitTime + patternDuration  // 最小サイクル

            // Determine wait time for this cycle using deterministic random
            let cycleIndex = Int(t / cycleDuration)
            var randomState = UInt64(cycleIndex * 7919)
            randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
            let waitTime = minWaitTime + Float(randomState % 10000) / 10000.0 * (maxWaitTime - minWaitTime)

            // Calculate pattern start time
            let patternStartTime = Float(cycleIndex) * cycleDuration + waitTime

            // Check if we're in pattern
            let timeSincePatternStart = t - patternStartTime
            guard timeSincePatternStart >= 0.0 && timeSincePatternStart < patternDuration else {
                return 0.0  // Silent during wait period
            }

            // Determine which beat we're in (0-3)
            let beatIndex = Int(timeSincePatternStart / beatInterval)
            guard beatIndex < patternBeats else {
                return 0.0
            }

            // Time since this beat started
            let timeSinceBeat = timeSincePatternStart - Float(beatIndex) * beatInterval

            // Velocity (beat 2 is weak, 80%)
            let velocity: Float = (beatIndex == 2) ? 0.8 : 1.0

            // === Layer 1: Attack ("shu") ===
            var attackValue: Float = 0.0
            if timeSinceBeat < attackDuration {
                let envelope: Float
                if timeSinceBeat < attackAttack {
                    // Attack phase
                    envelope = timeSinceBeat / attackAttack
                } else {
                    // Decay phase
                    let decayTime = timeSinceBeat - attackAttack
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
            if timeSinceBeat < popDuration {
                let envelope: Float
                if timeSinceBeat < popAttack {
                    // Attack phase
                    envelope = timeSinceBeat / popAttack
                } else {
                    // Decay phase
                    let decayTime = timeSinceBeat - popAttack
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
            if timeSinceBeat < steamDuration {
                let envelope: Float
                if timeSinceBeat < steamAttack {
                    // Attack phase
                    envelope = timeSinceBeat / steamAttack
                } else {
                    // Decay phase
                    let decayTime = timeSinceBeat - steamAttack
                    envelope = exp(-decayTime / steamDecay)
                }
                // Pink noise with simple LPF simulation
                let rawSteam = pinkNoise(t)
                let lpfSteam = rawSteam * 0.5  // Low-pass simulation
                steamValue = lpfSteam * envelope * steamLevel
            }

            // Mix all layers with velocity
            return (attackValue + popValue + steamValue) * velocity * 0.8
        }
    }
}
