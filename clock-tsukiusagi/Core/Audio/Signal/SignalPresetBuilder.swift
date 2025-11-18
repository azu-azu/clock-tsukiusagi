//
//  SignalPresetBuilder.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Factory for creating SignalEngine-based audio presets
//

import Foundation
import AVFoundation

/// Factory that creates SignalAudioSource from NaturalSoundPreset ID
///
/// Claude: Simple switch-based builder for SignalEngine presets.
/// This allows easy extension without modifying AudioService or UI code.
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

        // Not yet implemented in SignalEngine
        case .oceanWavesSeagulls,
             .stardustNoise,
             .lunarDustStorm,
             .silentLibrary,
             .distantThunder,
             .sinkingMoon,
             .dawnHint,
             .windChime,
             .tibetanBowl:
            return nil
        }
    }
}
