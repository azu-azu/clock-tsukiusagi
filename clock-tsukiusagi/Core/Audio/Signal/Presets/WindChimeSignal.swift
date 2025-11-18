//
//  WindChimeSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Wind Chime — pentatonic random bells
//

import Foundation

/// Wind Chime — healing pentatonic tones
///
/// This preset creates gentle chime sounds:
/// - Random pentatonic frequencies (C, D, E, G, A at different octaves)
/// - Random trigger intervals (2-8 seconds)
/// - ADSR envelope (fast attack, slow decay)
///
/// Original parameters from WindChime.swift:
/// - frequencies: Pentatonic scale array
/// - amplitude: 0.3
/// - minInterval: 2.0 seconds
/// - maxInterval: 8.0 seconds
/// - attackTime: 0.01, decayTime: 3.0
/// - sustainLevel: 0.0, releaseTime: 1.0
public struct WindChimeSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {

        // Pentatonic scale (C major pentatonic across 2 octaves)
        let pentatonicFrequencies: [Double] = [
            261.63,  // C4
            293.66,  // D4
            329.63,  // E4
            392.00,  // G4
            440.00,  // A4
            523.25,  // C5
            587.33,  // D5
            659.25   // E5
        ]

        // State for random chiming
        enum ChimeStage {
            case idle, attack, decay
        }

        var activeChimes: [(frequency: Double, envelope: Float, stage: ChimeStage, time: Float)] = []
        var lastTriggerTime: Float = 0
        var nextTriggerTime: Float = Float.random(in: 2.0...8.0)

        return Signal { t in
            // Check if it's time for a new chime
            if t - lastTriggerTime >= nextTriggerTime {
                let randomFreq = pentatonicFrequencies.randomElement() ?? 440.0
                activeChimes.append((frequency: randomFreq, envelope: 0.0, stage: .attack, time: 0.0))
                lastTriggerTime = t
                nextTriggerTime = Float.random(in: 2.0...8.0)
            }

            // Update and mix all active chimes
            var mixedSample: Float = 0.0
            let deltaTime: Float = 1.0 / 48000.0

            for i in 0..<activeChimes.count {
                var chime = activeChimes[i]
                chime.time += deltaTime

                // Update envelope (ADSR)
                switch chime.stage {
                case .attack:
                    chime.envelope = min(chime.time / 0.01, 1.0)
                    if chime.time >= 0.01 {
                        chime.stage = .decay
                        chime.time = 0.0
                    }
                case .decay:
                    chime.envelope = 1.0 * exp(-chime.time / 3.0)  // Exponential decay
                    if chime.envelope < 0.001 {
                        chime.stage = .idle
                    }
                default:
                    chime.envelope = 0.0
                }

                if chime.envelope > 0.001 {
                    let phase = Float(2.0 * .pi * chime.frequency) * t
                    mixedSample += sin(phase) * chime.envelope * 0.3
                }

                activeChimes[i] = chime
            }

            // Remove inactive chimes
            activeChimes.removeAll { $0.stage == .idle }

            return mixedSample / Float(max(activeChimes.count, 1))
        }
    }

    /// Create SignalAudioSource (legacy method for direct AudioSource usage)
    public static func make(sampleRate: Double) -> SignalAudioSource {
        return SignalAudioSource(signal: makeSignal())
    }
}
