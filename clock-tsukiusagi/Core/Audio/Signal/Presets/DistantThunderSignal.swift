//
//  DistantThunderSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-23.
//  SignalEngine: Distant Thunder — powerful "DON!" rumble
//  Extracted from Midnight Train's impactful first beat
//

import Foundation

/// Distant Thunder — powerful thunder rumble
///
/// This preset creates the sound of distant thunder:
/// Components:
/// - 3-layer impact sound (same as Midnight Train's "DON!" beat)
/// - Random intervals (5-12 seconds) for unpredictable thunder
/// - No repeating pattern, just single powerful strikes
///
/// Sound layers (from Midnight Train):
/// 1. Attack: White noise burst for initial crack
/// 2. Rumble: Low sine 120Hz with wobble for deep bass
/// 3. Resonance: Brown noise for atmospheric lingering
///
/// Timing:
/// - Random wait 5-12s → single "DON!" → repeat
/// - Creates realistic distant thunder atmosphere
public struct DistantThunderSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Timing parameters
        let minWaitTime: Float = 5.0        // 最短待機時間
        let maxWaitTime: Float = 12.0       // 最長待機時間

        // Layer 1: Attack (crack) parameters
        let attackDuration: Float = 0.05    // 50ms（雷は少し長め）
        let attackAttack: Float = 0.003     // 3ms（鋭い立ち上がり）
        let attackDecay: Float = 0.047      // 47ms

        // Layer 2: Rumble (deep bass) parameters
        let rumbleFreq: Float = 120.0       // 120Hz（より低く）
        let rumbleWobbleFreq: Float = 2.5   // 2.5Hz LFO
        let rumbleWobbleDepth: Float = 0.03 // ±3%（少し大きめ）
        let rumbleAttack: Float = 0.015     // 15ms
        let rumbleDecay: Float = 0.35       // 350ms（長い余韻）

        // Layer 3: Resonance (atmospheric) parameters
        let resonanceAttack: Float = 0.080  // 80ms
        let resonanceDecay: Float = 0.45    // 450ms（長い余韻）
        let resonanceLevel: Float = 0.25    // 雷は蒸気より強め

        // Generate noise sources
        let whiteNoise = Noise.white
        let brownNoise = Noise.brown(smoothing: 0.15)  // 雷は低域重視

        return Signal { t in
            // Calculate maximum thunder duration
            let maxDuration = max(attackDuration, rumbleAttack + rumbleDecay, resonanceAttack + resonanceDecay)

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

            // === Layer 1: Attack (crack) ===
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
                // White noise for sharp crack
                let rawNoise = whiteNoise(t)
                attackValue = rawNoise * envelope * 0.5  // 雷は強め
            }

            // === Layer 2: Rumble (deep bass) ===
            var rumbleValue: Float = 0.0
            let rumbleDuration = rumbleAttack + rumbleDecay
            if timeSinceThunder < rumbleDuration {
                let envelope: Float
                if timeSinceThunder < rumbleAttack {
                    // Attack phase
                    envelope = timeSinceThunder / rumbleAttack
                } else {
                    // Decay phase
                    let decayTime = timeSinceThunder - rumbleAttack
                    envelope = exp(-decayTime / rumbleDecay)
                }
                // Low sine with pitch wobble for rumble
                let wobble = sin(2.0 * Float.pi * rumbleWobbleFreq * t) * rumbleWobbleDepth
                let freq = rumbleFreq * (1.0 + wobble)
                let phase = 2.0 * Float.pi * freq * t
                rumbleValue = sin(phase) * envelope * 0.7  // 低音を強調
            }

            // === Layer 3: Resonance (atmospheric lingering) ===
            var resonanceValue: Float = 0.0
            let resonanceDuration = resonanceAttack + resonanceDecay
            if timeSinceThunder < resonanceDuration {
                let envelope: Float
                if timeSinceThunder < resonanceAttack {
                    // Attack phase
                    envelope = timeSinceThunder / resonanceAttack
                } else {
                    // Decay phase
                    let decayTime = timeSinceThunder - resonanceAttack
                    envelope = exp(-decayTime / resonanceDecay)
                }
                // Brown noise for deep atmospheric resonance
                let rawResonance = brownNoise(t)
                resonanceValue = rawResonance * envelope * resonanceLevel
            }

            // Mix all layers for powerful thunder
            return (attackValue + rumbleValue + resonanceValue) * 1.0
        }
    }
}
