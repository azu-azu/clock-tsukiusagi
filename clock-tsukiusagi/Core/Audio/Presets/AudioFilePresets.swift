//
//  AudioFilePresets.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025/11/11.
//  Audio file presets for TrackPlayer
//

import Foundation

/// Audio file presets for TrackPlayer
public enum AudioFilePreset: String, CaseIterable, Identifiable {
    case oceanWaves = "ocean_waves_60s"
    case forestAmbience = "forest_ambience_60s"
    case bubblesSoft = "bubbles_soft"
    case forestBirdsSoft = "forest_birds_soft"
    case forestWindLeavesSoft = "forest_wind_leaves_soft"
    case forestWindLeaves = "forest_wind_leaves"

    public var id: String { rawValue }

    /// Indicates if this is a test/development preset
    public var isTest: Bool {
        [
            .oceanWaves,
            .forestAmbience,
            .bubblesSoft,
            .forestBirdsSoft,
            .forestWindLeavesSoft,
            .forestWindLeaves
        ].contains(self)
    }

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .oceanWaves:
            return "Ocean Waves"
        case .forestAmbience:
            return "Forest Ambience"
        case .bubblesSoft:
            return "Bubbles (Soft)"
        case .forestBirdsSoft:
            return "Forest Birds (Soft)"
        case .forestWindLeavesSoft:
            return "Forest Wind & Leaves (Soft)"
        case .forestWindLeaves:
            return "Forest Wind & Leaves"
        }
    }

    /// File extension (CAF format - Core Audio Format for optimal iOS playback)
    public var fileExtension: String {
        return "caf"
    }

    /// Get URL for audio file from bundle
    /// - Returns: URL to audio file, or nil if not found
    public func url() -> URL? {
        if let url = Bundle.main.url(forResource: rawValue, withExtension: fileExtension) {
            return url
        }

        print("⚠️ [AudioFilePreset] File not found: \(rawValue).\(fileExtension)")
        return nil
    }

    /// Recommended loop settings
    public var loopSettings: LoopSettings {
        switch self {
        case .oceanWaves:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 0.0,  // No crossfade needed - seamless loop
                fadeInDuration: 1.0,
                fadeOutDuration: 2.0
            )
        case .forestAmbience:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 0.0,  // No crossfade needed - seamless loop
                fadeInDuration: 1.0,
                fadeOutDuration: 2.0
            )
        case .bubblesSoft:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 0.0,  // No crossfade needed - seamless loop
                fadeInDuration: 1.0,
                fadeOutDuration: 1.5
            )
        case .forestBirdsSoft:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 0.0,  // No crossfade needed - seamless loop
                fadeInDuration: 1.0,
                fadeOutDuration: 1.5
            )
        case .forestWindLeavesSoft:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 0.0,  // No crossfade needed - seamless loop
                fadeInDuration: 1.2,
                fadeOutDuration: 2.0
            )
        case .forestWindLeaves:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 0.0,  // No crossfade needed - seamless loop
                fadeInDuration: 1.0,
                fadeOutDuration: 1.8
            )
        }
    }
}

/// Loop settings for audio file playback
public struct LoopSettings {
    /// Enable seamless looping
    public let shouldLoop: Bool

    /// Crossfade duration for loop point (seconds)
    public let crossfadeDuration: TimeInterval

    /// Fade in duration when starting playback (seconds)
    public let fadeInDuration: TimeInterval

    /// Fade out duration when stopping playback (seconds)
    public let fadeOutDuration: TimeInterval

    public init(
        shouldLoop: Bool = true,
        crossfadeDuration: TimeInterval = 2.0,
        fadeInDuration: TimeInterval = 0.5,
        fadeOutDuration: TimeInterval = 0.5
    ) {
        self.shouldLoop = shouldLoop
        self.crossfadeDuration = crossfadeDuration
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
    }
}

// MARK: - NaturalSoundPreset Extension

extension NaturalSoundPreset {
    /// Optional audio file preset (if using file-based playback instead of synthesis)
    public var audioFilePreset: AudioFilePreset? {
        switch self {
        case .windChime:
            return nil  // Uses synthesis (WindChime)
        case .tibetanBowl:
            return nil  // Uses synthesis (TibetanBowl)
        case .oceanWavesSeagulls:
            return nil  // Uses synthesis (OceanWaves + Seagulls)
        case .moonlitSea:
            return nil  // Uses synthesis (MoonlitSea)
        case .lunarPulse:
            return nil  // Uses synthesis (LunarPulse)
        case .darkShark:
            return nil  // Uses synthesis (DarkShark)
        case .midnightTrain:
            return nil  // Uses synthesis (MidnightTrain)
        case .lunarTide:
            return nil  // Uses synthesis (LunarTide)
        case .abyssalBreath:
            return nil  // Uses synthesis (AbyssalBreath)
        case .stardustNoise:
            return nil  // Uses synthesis (StardustNoise)
        case .lunarDustStorm:
            return nil  // Uses synthesis (LunarDustStorm)
        case .silentLibrary:
            return nil  // Uses synthesis (SilentLibrary)
        case .distantThunder:
            return nil  // Uses synthesis (DistantThunder)
        case .sinkingMoon:
            return nil  // Uses synthesis (SinkingMoon)
        case .dawnHint:
            return nil  // Uses synthesis (DawnHint)
        }
    }
}
