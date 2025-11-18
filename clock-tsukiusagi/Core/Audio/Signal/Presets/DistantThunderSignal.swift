//
//  DistantThunderSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Distant Thunder — random rumble pulses
//

import Foundation

/// Distant Thunder — far-off storm rumbling
///
/// This preset creates distant thunder sounds:
/// - Brown noise for rumble base
/// - Random pulses (2-7 second intervals)
/// - Slow decay for realistic thunder fade
///
/// Original parameters from DistantThunder.swift:
/// - noiseAmplitude: 0.15
/// - pulseAmplitude: 0.08
/// - pulseMinInterval: 2.0 seconds
/// - pulseMaxInterval: 7.0 seconds
/// - Pulse decay: 0.9999 per sample
public struct DistantThunderSignal {

    public static func make(sampleRate: Double) -> SignalAudioSource {

        // Brown noise (rumble base)
        let noise = Noise.brown()

        // Pulse state
        var lastPulseTime: Float = 0
        var nextPulseTime: Float = Float.random(in: 2.0...7.0)
        var pulseDecay: Float = 0.0
        var pulseActive = false

        let thunderModulated = Signal { t in
            // Check if it's time for a new pulse
            if t - lastPulseTime >= nextPulseTime {
                pulseActive = true
                pulseDecay = 1.0
                lastPulseTime = t
                nextPulseTime = Float.random(in: 2.0...7.0)
            }

            // Update pulse decay
            if pulseActive {
                pulseDecay *= 0.9999
                if pulseDecay < 0.01 {
                    pulseActive = false
                }
            }

            let baseAmplitude: Float = 0.15
            let pulseAmplitude: Float = pulseActive ? 0.08 * pulseDecay : 0.0
            let totalAmplitude = baseAmplitude + pulseAmplitude

            return noise(t) * totalAmplitude
        }

        return SignalAudioSource(signal: thunderModulated)
    }
}
