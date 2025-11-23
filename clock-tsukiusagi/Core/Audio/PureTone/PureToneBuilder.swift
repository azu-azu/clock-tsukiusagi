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

        switch preset {
        case .pentatonicChime:
            // Signal-based implementation with reverb effect
            let signal = PentatonicChimeSignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

            // Add reverb effect (same as NaturalSound was using)
            let reverb = SchroederReverb(
                roomSize: 1.4,
                damping: 0.45,
                decay: 0.7,
                mix: 0.25,
                predelay: 0.02,
                sampleRate: 48000.0
            )
            mixer.addEffect(reverb)

            let outputNode = FinalMixerOutputNode(mixer: mixer)
            sources.append(outputNode)

        case .treeChimeOnly:
            // AudioSource-based implementation
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
