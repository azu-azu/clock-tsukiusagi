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
    case testTone = "test_tone_440hz"
    case pinkNoise = "pink_noise_60s"
    case oceanWaves = "ocean_waves_60s"
    case rain = "rain_60s"
    case forestAmbience = "forest_ambience_60s"

    public var id: String { rawValue }

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .testTone:
            return "Test Tone (440Hz)"
        case .pinkNoise:
            return "Pink Noise"
        case .oceanWaves:
            return "Ocean Waves"
        case .rain:
            return "Rain"
        case .forestAmbience:
            return "Forest Ambience"
        }
    }

    /// File extension (WAV format)
    public var fileExtension: String {
        return "wav"
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
        case .testTone:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 0.5,
                fadeInDuration: 0.2,
                fadeOutDuration: 0.5
            )
        case .pinkNoise:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 2.0,  // Smooth crossfade for seamless loop
                fadeInDuration: 1.0,
                fadeOutDuration: 2.0
            )
        case .oceanWaves:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 3.0,  // Longer crossfade for natural wave rhythm
                fadeInDuration: 2.0,
                fadeOutDuration: 3.0
            )
        case .rain:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 2.0,
                fadeInDuration: 1.5,
                fadeOutDuration: 2.0
            )
        case .forestAmbience:
            return LoopSettings(
                shouldLoop: true,
                crossfadeDuration: 3.0,  // Longer for natural ambient transition
                fadeInDuration: 2.0,
                fadeOutDuration: 3.0
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
        case .clickSuppression:
            return nil  // Uses synthesis (ClickSuppressionDrone)
        case .pinkNoise:
            return nil  // Uses synthesis (PinkNoise)
        case .brownNoise:
            return nil  // Uses synthesis (BrownNoise)
        case .pleasantDrone:
            return nil  // Uses synthesis (PleasantDrone)
        case .pleasantWarm:
            return nil  // Uses synthesis (DetunedOscillator)
        case .pleasantCalm:
            return nil  // Uses synthesis (DetunedOscillator)
        case .pleasantDeep:
            return nil  // Uses synthesis (DetunedOscillator)
        case .ambientFocus:
            return nil  // Uses synthesis (AmbientDrone)
        case .ambientRelax:
            return nil  // Uses synthesis (AmbientDrone)
        case .ambientSleep:
            return nil  // Uses synthesis (AmbientDrone)
        }
    }
}
