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
    // Future presets:
    // case pinkNoise = "pink_noise_60s"
    // case brownNoise = "brown_noise_60s"
    // case oceanWaves = "ocean_waves_60s"
    // case rain = "rain_60s"

    public var id: String { rawValue }

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .testTone:
            return "Test Tone (440Hz)"
        }
    }

    /// File extension (prefer CAF, fallback to WAV)
    public var fileExtension: String {
        return "caf"
    }

    /// Alternative file extension
    public var fallbackExtension: String {
        return "wav"
    }

    /// Get URL for audio file from bundle
    /// - Returns: URL to audio file, or nil if not found
    public func url() -> URL? {
        // Try CAF first
        if let url = Bundle.main.url(forResource: rawValue, withExtension: fileExtension) {
            return url
        }

        // Fallback to WAV
        if let url = Bundle.main.url(forResource: rawValue, withExtension: fallbackExtension) {
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
            // Currently uses synthesis (ClickSuppressionDrone)
            // Future: Could optionally use pre-recorded pink noise
            return nil
        }
    }
}
