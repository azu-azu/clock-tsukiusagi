//
//  MidnightTrainSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Midnight Train — cute "shupotsu" steam train
//  Based on Fujiko's proposal for warm, rabbit-carriage atmosphere
//

import Foundation

/// Midnight Train — toy train with light "shu, shu, shu" sound
///
/// This preset creates the sound of a cute toy steam train:
/// Components:
/// - 3-layer sound structure optimized for lightness
/// - 4-beat pattern with gentle rhythm (strong, strong, weak, strong)
/// - Random intervals (3-8 seconds) between pattern bursts
///
/// Sound layers (optimized for toy train):
/// 1. Attack ("shu"): White noise burst 80ms, HPF, BOOSTED for emphasis
/// 2. Pop: Sine 180Hz, MINIMIZED (40ms decay) to reduce heavy "boyo~n"
/// 3. Steam: Pink noise, SHORTENED (80ms decay) for quick, light feel
///
/// Rhythm structure:
/// - Random wait 3-8s → 4-beat pattern (0.55s interval) → repeat
/// - Beat 3 has 80% velocity for natural feel
/// - Light, playful "shu, shu, shu" like a toy train
public struct MidnightTrainSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Timing parameters
        let beatInterval: Float = 0.55      // 間隔（BPM 109相当）
        let patternBeats: Int = 4           // 4拍パターン
        let minWaitTime: Float = 3.0        // 最短待機時間
        let maxWaitTime: Float = 8.0        // 最長待機時間

        // Layer 1: Attack ("shu") parameters - ENHANCED for toy train
        let attackDuration: Float = 0.08    // 80ms（longer for clear "shu" sound）
        let attackAttack: Float = 0.003     // 3ms（sharper attack）
        let attackDecay: Float = 0.077      // 77ms（quick fade）

        // Layer 2: Pop ("potsu") parameters - MINIMIZED to reduce "boyo~n"
        let popFreq: Float = 180.0          // 180Hz
        let popWobbleFreq: Float = 3.0      // 3Hz LFO
        let popWobbleDepth: Float = 0.02    // ±2%
        let popAttack: Float = 0.010        // 10ms
        let popDecay: Float = 0.040         // 40ms（much shorter - was 120ms）

        // Layer 3: Steam parameters - SHORTENED for lighter feel
        let steamAttack: Float = 0.020      // 20ms（faster - was 50ms）
        let steamDecay: Float = 0.080       // 80ms（much shorter - was 200ms）
        let steamLevel: Float = 0.10        // reduced volume for lightness

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
                let hpfNoise = rawNoise * 0.8  // High-pass simulation（stronger）
                attackValue = hpfNoise * envelope * 0.55  // BOOSTED for "shu" emphasis
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
                popValue = sin(phase) * envelope * 0.20  // REDUCED to minimize "boyo~n"（was 0.6）
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

            // Mix all layers with velocity（lighter overall）
            return (attackValue + popValue + steamValue) * velocity * 0.7
        }
    }
}
