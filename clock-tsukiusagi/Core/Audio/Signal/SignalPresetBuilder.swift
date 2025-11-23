//
//  SignalPresetBuilder.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Factory for creating SignalEngine-based audio presets
//

import Foundation
import AVFoundation

/// Factory that creates FinalMixerOutputNode from NaturalSoundPreset ID
///
/// Claude: Simple switch-based builder for SignalEngine presets.
/// This allows easy extension without modifying AudioService or UI code.
///
/// Creates FinalMixerOutputNode with full effects chain (filters, reverb, limiter).
public struct SignalPresetBuilder {

    private let sampleRate: Double

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    // MARK: - FinalMixer-based Creation

    /// Create a ready-to-use FinalMixerOutputNode for a given preset with effects support.
    /// Returns nil if the preset is not yet implemented in SignalEngine.
    ///
    /// This method creates a FinalMixer with the preset's signal and applies appropriate effects.
    public func makeMixerOutput(for preset: NaturalSoundPreset) -> FinalMixerOutputNode? {
        // Extract the signal by creating it through the individual builders
        let signal = createRawSignal(for: preset)
        guard let signal = signal else { return nil }

        // Create FinalMixer and add the signal
        let mixer = FinalMixer()
        mixer.add(signal, gain: 1.0)

        // Add effects based on preset characteristics
        applyEffectsForPreset(preset, to: mixer, sampleRate: Float(sampleRate))

        // Wrap in FinalMixerOutputNode
        return FinalMixerOutputNode(mixer: mixer)
    }

    // MARK: - Raw Signal Creation

    /// Create the raw Signal (not wrapped in AudioSource) for a preset
    /// Uses the makeSignal() factory method from each preset builder
    private func createRawSignal(for preset: NaturalSoundPreset) -> Signal? {
        switch preset {
        case .darkShark:
            return DarkSharkSignal.makeSignal()
        case .midnightTrain:
            return MidnightTrainSignal.makeSignal()
        }
    }

    // MARK: - Effects Application

    /// Apply appropriate effects to a mixer based on the preset type
    private func applyEffectsForPreset(_ preset: NaturalSoundPreset, to mixer: FinalMixer, sampleRate: Float) {
        // Dark/Atmospheric: Low-pass filter + Dark reverb
        switch preset {
        case .darkShark, .midnightTrain:
            let filter = CascadeFilter(
                type: .lowpass,
                cutoff: 1600,
                resonance: 0.85,
                sampleRate: sampleRate
            )
            mixer.addEffect(filter)

            let reverb = SchroederReverb(
                roomSize: 1.8,
                damping: 0.7,
                decay: 0.82,
                mix: 0.42,
                predelay: 0.028,
                sampleRate: sampleRate
            )
            mixer.addEffect(reverb)
        }

        // Add soft limiter at the end for gentle peak control
        mixer.addEffect(SoftLimiter(drive: 1.1, ceiling: 0.98))
    }
}
