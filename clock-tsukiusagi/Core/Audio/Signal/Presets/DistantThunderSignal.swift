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
/// Components:
/// - Brown noise for rumble base
/// - Random pulses (2-7 second intervals)
/// - Slow decay for realistic thunder fade
///
/// Original parameters from legacy AudioSource (DistantThunder.swift):
/// - noiseAmplitude: 0.15
/// - pulseAmplitude: 0.08
/// - pulseMinInterval: 2.0 seconds
/// - pulseMaxInterval: 7.0 seconds
/// - Pulse decay: 0.9999 per sample
///
/// Modifications:
/// - Structure unified to standard pattern with stateful generator
/// - Parameter naming standardized (baseAmplitude, pulseAmplitude, etc.)
/// - Documentation follows standard format
/// - Stateful generator with reset() method
public struct DistantThunderSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {
        let generator = DistantThunderGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

/// Stateful generator for distant thunder with random pulses
private final class DistantThunderGenerator {

    // Constants
    private let baseAmplitude: Float = 0.15
    private let pulseAmplitude: Float = 0.08
    private let pulseMinInterval: Float = 2.0
    private let pulseMaxInterval: Float = 7.0
    private let pulseDecayRate: Float = 0.9999

    // Brown noise (rumble base)
    private let noise = Noise.brown()

    // Pulse state (preserved across calls)
    private var lastPulseTime: Float = 0
    private var nextPulseTime: Float = Float.random(in: 2.0...7.0)
    private var pulseDecay: Float = 0.0
    private var pulseActive = false

    /// Reset generator state to initial values
    func reset() {
        lastPulseTime = 0
        nextPulseTime = Float.random(in: pulseMinInterval...pulseMaxInterval)
        pulseDecay = 0.0
        pulseActive = false
    }

    func sample(at t: Float) -> Float {
        // Check if it's time for a new pulse
        if t - lastPulseTime >= nextPulseTime {
            pulseActive = true
            pulseDecay = 1.0
            lastPulseTime = t
            nextPulseTime = Float.random(in: pulseMinInterval...pulseMaxInterval)
        }

        // Update pulse decay
        if pulseActive {
            pulseDecay *= pulseDecayRate
            if pulseDecay < 0.01 {
                pulseActive = false
            }
        }

        let pulseAmp: Float = pulseActive ? pulseAmplitude * pulseDecay : 0.0
        let totalAmplitude = baseAmplitude + pulseAmp

        return noise(t) * totalAmplitude
    }
}
