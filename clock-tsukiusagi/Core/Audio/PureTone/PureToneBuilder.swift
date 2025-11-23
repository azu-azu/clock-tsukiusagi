//
//  PureToneBuilder.swift
//  clock-tsukiusagi
//
//  Builder for pure tone audio sources
//

import Foundation

/// Builder for constructing pure tone audio sources from presets
public struct PureToneBuilder {

    /// Build audio sources for a given pure tone preset
    /// - Parameter preset: The preset to build
    /// - Returns: Array of AudioSource instances (may include multiple sources for layered presets)
    public static func build(_ preset: PureTonePreset) -> [AudioSource] {
        var sources: [AudioSource] = []

        // Main pure tone source (LunarPulse) - only if preset includes it
        if preset.includesLunarPulse {
            let p = preset.params
            let pulse = LunarPulse(
                frequency: p.frequency,
                amplitude: p.amplitude,
                lfoFrequency: p.lfoFrequency,
                lfoMinimum: p.lfoMinimum,
                lfoMaximum: p.lfoMaximum
            )
            sources.append(pulse)
        }

        // TreeChime overlay if needed
        if preset.includesChime {
            let chime = TreeChime(
                grainRate: 25.0,       // Sparse grains (not too dense)
                grainDuration: 0.12,   // Longer decay for ethereal feel
                brightness: 7000.0     // High frequency shimmer
            )
            sources.append(chime)
        }

        return sources
    }
}
