//
//  StardustNoiseSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Stardust Noise — white noise with micro bursts
//

import Foundation

/// Stardust Noise — twinkling white noise like distant stars
///
/// This preset creates a shimmering white noise texture:
/// - White noise for high-frequency sparkle
/// - Micro burst modulation (toggles between high/low amplitude)
/// - Random burst intervals (0.4-1.2 seconds)
///
/// Original parameters from StardustNoise.swift:
/// - microBurstAmplitude: 0.12
/// - microBurstMinInterval: 0.4 seconds
/// - microBurstMaxInterval: 1.2 seconds
/// - Amplitude toggles between full and 30% on each burst
public struct StardustNoiseSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {
        let generator = StardustNoiseGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

/// Stateful generator for stardust noise with micro bursts
private final class StardustNoiseGenerator {

    // White noise (sparkle texture)
    private let noise = Noise.white

    // Micro burst state (preserved across calls)
    private var lastToggleTime: Float = 0
    private var nextBurstTime: Float = Float.random(in: 0.4...1.2)
    private var burstActive = false

    func sample(at t: Float) -> Float {
        // Check if it's time to toggle
        if t - lastToggleTime >= nextBurstTime {
            burstActive.toggle()
            lastToggleTime = t
            nextBurstTime = Float.random(in: 0.4...1.2)
        }

        let amplitude: Float = burstActive ? 0.12 : 0.12 * 0.3
        return noise(t) * amplitude
    }
}
