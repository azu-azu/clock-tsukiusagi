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
        case .moonlitSea:
            return MoonlitSeaSignal.makeSignal()
        case .lunarTide:
            return LunarTideSignal.makeSignal()
        case .abyssalBreath:
            return AbyssalBreathSignal.makeSignal()
        case .lunarPulse:
            return LunarPulseSignal.makeSignal()
        case .darkShark:
            return DarkSharkSignal.makeSignal()
        case .midnightTrain:
            return MidnightTrainSignal.makeSignal()
        case .stardustNoise:
            return StardustNoiseSignal.makeSignal()
        case .lunarDustStorm:
            return LunarDustStormSignal.makeSignal()
        case .silentLibrary:
            return SilentLibrarySignal.makeSignal()
        case .distantThunder:
            return DistantThunderSignal.makeSignal()
        case .sinkingMoon:
            return SinkingMoonSignal.makeSignal()
        case .dawnHint:
            return DawnHintSignal.makeSignal()
        case .oceanWavesSeagulls:
            return nil
        }
    }

    // MARK: - Effects Application

    /// Apply appropriate effects to a mixer based on the preset type
    private func applyEffectsForPreset(_ preset: NaturalSoundPreset, to mixer: FinalMixer, sampleRate: Float) {
        // Default effects settings (will be tuned in Day 7.5 and Day 9.5)

        switch preset {
        // Ocean/Water presets: Low-pass filter + Medium reverb
        case .moonlitSea, .lunarTide, .abyssalBreath:
            let filterParams: (cutoff: Float, resonance: Float) = {
                switch preset {
                case .moonlitSea: return (3500, 0.6)
                case .lunarTide: return (4500, 0.7)
                case .abyssalBreath: return (2500, 0.8)
                default: return (4000, 0.707)
                }
            }()

            let filter = CascadeFilter(
                type: .lowpass,
                cutoff: filterParams.cutoff,
                resonance: filterParams.resonance,
                sampleRate: sampleRate
            )
            mixer.addEffect(filter)

            let reverb = SchroederReverb(
                roomSize: 1.6,
                damping: 0.58,
                decay: 0.78,
                mix: 0.32,      // 少し控えめに
                predelay: 0.02,
                sampleRate: sampleRate
            )
            mixer.addEffect(reverb)

        // Tonal/Musical: Minimal filtering + Natural reverb (same as windChime)
        case .lunarPulse:
            let reverb = SchroederReverb(
                roomSize: 1.4,
                damping: 0.45,
                decay: 0.7,
                mix: 0.25,
                predelay: 0.02,
                sampleRate: sampleRate
            )
            mixer.addEffect(reverb)

        // Dark/Atmospheric: Low-pass filter + Dark reverb
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

        // Noise/Atmospheric: Minimal filtering + Subtle reverb
        case .stardustNoise, .lunarDustStorm, .silentLibrary, .distantThunder, .sinkingMoon, .dawnHint:
            let filter = CascadeFilter(
                type: .lowpass,
                cutoff: 9500,
                resonance: 0.6,
                sampleRate: sampleRate
            )
            mixer.addEffect(filter)

            let reverb = SchroederReverb(
                roomSize: 1.25,
                damping: 0.52,
                decay: 0.68,
                mix: 0.22,          // 少し下げる
                predelay: 0.012,    // 短めで明瞭に
                sampleRate: sampleRate
            )
            mixer.addEffect(reverb)

        // No effects for file-based presets
        case .oceanWavesSeagulls:
            break
        }

        // Add soft limiter at the end for gentle peak control
        mixer.addEffect(SoftLimiter(drive: 1.1, ceiling: 0.98)) // driveわずかに抑制
    }
}
