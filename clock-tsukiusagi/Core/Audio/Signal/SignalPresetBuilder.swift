//
//  SignalPresetBuilder.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Factory for creating SignalEngine-based audio presets
//

import Foundation
import AVFoundation

/// Factory that creates SignalAudioSource or FinalMixerOutputNode from NaturalSoundPreset ID
///
/// Claude: Simple switch-based builder for SignalEngine presets.
/// This allows easy extension without modifying AudioService or UI code.
///
/// Two methods available:
/// 1. makeSignal() - Legacy method, returns SignalAudioSource (single signal, no effects)
/// 2. makeMixerOutput() - New method, returns FinalMixerOutputNode (supports effects chain)
public struct SignalPresetBuilder {

    private let sampleRate: Double

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// Create a ready-to-use SignalAudioSource for a given preset.
    /// Returns nil if the preset is not yet implemented in SignalEngine.
    public func makeSignal(for preset: NaturalSoundPreset) -> SignalAudioSource? {
        switch preset {

        // ---- Ocean / Water ----
        case .moonlitSea:
            return MoonlitSeaSignal.make(sampleRate: sampleRate)

        case .lunarTide:
            return LunarTideSignal.make(sampleRate: sampleRate)

        case .abyssalBreath:
            return AbyssalBreathSignal.make(sampleRate: sampleRate)

        // ---- Celestial / Ambient ----
        case .lunarPulse:
            return LunarPulseSignal.make(sampleRate: sampleRate)

        // ---- Dark / Atmospheric ----
        case .darkShark:
            return DarkSharkSignal.make(sampleRate: sampleRate)

        case .midnightTrain:
            return MidnightTrainSignal.make(sampleRate: sampleRate)

        // ---- Noise / Atmospheric ----
        case .stardustNoise:
            return StardustNoiseSignal.make(sampleRate: sampleRate)

        case .lunarDustStorm:
            return LunarDustStormSignal.make(sampleRate: sampleRate)

        case .silentLibrary:
            return SilentLibrarySignal.make(sampleRate: sampleRate)

        case .distantThunder:
            return DistantThunderSignal.make(sampleRate: sampleRate)

        case .sinkingMoon:
            return SinkingMoonSignal.make(sampleRate: sampleRate)

        case .dawnHint:
            return DawnHintSignal.make(sampleRate: sampleRate)

        // ---- Tonal / Musical ----
        case .windChime:
            return WindChimeSignal.make(sampleRate: sampleRate)

        case .tibetanBowl:
            return TibetanBowlSignal.make(sampleRate: sampleRate)

        // Not yet implemented in SignalEngine (uses external audio file)
        case .oceanWavesSeagulls:
            return nil
        }
    }

    // MARK: - FinalMixer-based Creation (New Method)

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
    /// This duplicates the signal-building logic from each preset's make() method
    private func createRawSignal(for preset: NaturalSoundPreset) -> Signal? {
        // We need to call the preset builders and extract their Signal
        // The cleanest way is to duplicate the signal creation inline
        // or have each preset provide a makeSignal() method
        //
        // For now, let's use a simpler approach: convert the existing makeSignal
        // return value by calling it again and extracting via asSignal()

        // Since SignalAudioSource wraps a signal, we can create a new signal
        // that calls the same logic. The easiest way is to just inline
        // the signal creation for each preset type.

        // Actually, let's use a simpler approach: create the Signal by
        // calling the existing make() methods and using their output as a Signal function

        switch preset {
        case .moonlitSea:
            let src = MoonlitSeaSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .lunarTide:
            let src = LunarTideSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .abyssalBreath:
            let src = AbyssalBreathSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .lunarPulse:
            let src = LunarPulseSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .darkShark:
            let src = DarkSharkSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .midnightTrain:
            let src = MidnightTrainSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .stardustNoise:
            let src = StardustNoiseSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .lunarDustStorm:
            let src = LunarDustStormSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .silentLibrary:
            let src = SilentLibrarySignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .distantThunder:
            let src = DistantThunderSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .sinkingMoon:
            let src = SinkingMoonSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .dawnHint:
            let src = DawnHintSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .windChime:
            let src = WindChimeSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .tibetanBowl:
            let src = TibetanBowlSignal.make(sampleRate: sampleRate)
            return extractSignalFromAudioSource(src)
        case .oceanWavesSeagulls:
            return nil
        }
    }

    /// Extract Signal from SignalAudioSource using the asSignal() method
    private func extractSignalFromAudioSource(_ source: SignalAudioSource) -> Signal {
        return source.asSignal()
    }

    // MARK: - Effects Application

    /// Apply appropriate effects to a mixer based on the preset type
    private func applyEffectsForPreset(_ preset: NaturalSoundPreset, to mixer: FinalMixer, sampleRate: Float) {
        // Default effects settings (will be tuned in Day 7.5 and Day 9.5)

        switch preset {
        // Ocean/Water presets: Low-pass filter + Medium reverb
        case .moonlitSea, .lunarTide, .abyssalBreath:
            let filter = StateVariableFilter(
                type: .lowpass,
                cutoff: 4000,
                resonance: 0.707,
                sampleRate: sampleRate
            )
            mixer.addEffect(filter)

            let reverb = SchroederReverb(
                roomSize: 1.5,
                damping: 0.6,
                decay: 0.75,
                mix: 0.35,
                predelay: 0.02,
                sampleRate: sampleRate
            )
            mixer.addEffect(reverb)

        // Celestial/Ambient: Band-pass filter + Large reverb
        case .lunarPulse:
            let filter = StateVariableFilter(
                type: .bandpass,
                cutoff: 1000,
                resonance: 1.2,
                sampleRate: sampleRate
            )
            mixer.addEffect(filter)

            let reverb = SchroederReverb(
                roomSize: 2.0,
                damping: 0.4,
                decay: 0.85,
                mix: 0.5,
                predelay: 0.03,
                sampleRate: sampleRate
            )
            mixer.addEffect(reverb)

        // Dark/Atmospheric: Low-pass filter + Dark reverb
        case .darkShark, .midnightTrain:
            let filter = StateVariableFilter(
                type: .lowpass,
                cutoff: 2000,
                resonance: 0.8,
                sampleRate: sampleRate
            )
            mixer.addEffect(filter)

            let reverb = SchroederReverb(
                roomSize: 1.8,
                damping: 0.7,
                decay: 0.8,
                mix: 0.4,
                predelay: 0.025,
                sampleRate: sampleRate
            )
            mixer.addEffect(reverb)

        // Noise/Atmospheric: Minimal filtering + Subtle reverb
        case .stardustNoise, .lunarDustStorm, .silentLibrary, .distantThunder, .sinkingMoon, .dawnHint:
            let filter = StateVariableFilter(
                type: .lowpass,
                cutoff: 8000,
                resonance: 0.707,
                sampleRate: sampleRate
            )
            mixer.addEffect(filter)

            let reverb = SchroederReverb(
                roomSize: 1.2,
                damping: 0.5,
                decay: 0.65,
                mix: 0.25,
                predelay: 0.015,
                sampleRate: sampleRate
            )
            mixer.addEffect(reverb)

        // Tonal/Musical: Minimal filtering + Natural reverb
        case .windChime, .tibetanBowl:
            let reverb = SchroederReverb(
                roomSize: 1.4,
                damping: 0.45,
                decay: 0.7,
                mix: 0.3,
                predelay: 0.02,
                sampleRate: sampleRate
            )
            mixer.addEffect(reverb)

        // No effects for file-based presets
        case .oceanWavesSeagulls:
            break
        }
    }
}
