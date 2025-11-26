//
//  AirLayer.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-26.
//  High-frequency transparency layer for ambient presence
//

import Foundation

/// Air Layer: High-frequency transparency layer
///
/// Adds a subtle "air" presence to audio presets by layering filtered white noise
/// in the high-frequency range (typically 6-10 kHz). This creates transparency
/// and spatial depth without muddying the main sound.
///
/// ## Usage
/// ```swift
/// let airLayer = AirLayer.make(cutoffFrequency: 8000, volume: 0.03)
/// mixer.add(airLayer, gain: 1.0)
/// ```
///
/// ## Design Philosophy
/// - Very low volume (0.02-0.04) - should be barely audible
/// - High cutoff frequency (6-10 kHz) - only the "air" band
/// - Applied after reverb for cohesive spatial integration
public enum AirLayer {

    /// Create an "air" layer signal
    ///
    /// Generates white noise filtered through a high-pass filter to create
    /// a transparent, airy presence in the high-frequency range.
    ///
    /// - Parameters:
    ///   - cutoffFrequency: High-pass cutoff in Hz (default: 8000)
    ///     - 6000 Hz: Warmer, deeper night ambience
    ///     - 8000 Hz: Standard "air" frequency
    ///     - 10000 Hz: Brighter, crystalline presence
    ///   - resonance: Filter Q-factor (default: 0.5)
    ///     - Lower values: Gentler slope, more natural
    ///     - Higher values: Sharper cutoff, more focused
    ///   - volume: Layer amplitude (default: 0.03, approximately -30dB)
    ///     - Should be VERY subtle - barely audible on its own
    ///     - Typical range: 0.02 - 0.05
    /// - Returns: Signal producing filtered white noise for air layer
    public static func make(
        cutoffFrequency: Float = 8000,
        resonance: Float = 0.5,
        volume: Float = 0.03
    ) -> Signal {
        let filter = StateVariableFilter(
            type: .highpass,
            cutoff: cutoffFrequency,
            resonance: resonance,
            sampleRate: 48000
        )

        return Signal { time in
            // Generate white noise
            let noise = Float.random(in: -1...1)

            // Apply high-pass filter and volume
            return filter.process(noise * volume, time: time)
        }
    }
}
