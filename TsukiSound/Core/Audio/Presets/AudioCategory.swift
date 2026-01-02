//
//  AudioCategory.swift
//  TsukiSound
//
//  Category grouping for audio presets (UI layer)
//

import Foundation

/// Audio category for grouping presets (UI presentation layer)
/// Categories don't affect audio processing - pure presentation concept.
public enum AudioCategory: String, CaseIterable, Identifiable, Codable {
    case tsukiSound  // All tracks (initial category)
    // Future: case classical, case jazz, case ambient, etc.

    public var id: String { rawValue }

    /// Emoji icon for this category
    public var icon: String {
        switch self {
        case .tsukiSound:
            return "🌙"
        }
    }

    /// Display name for UI (localized)
    public var displayName: String {
        localizationKey.localized
    }

    /// Localization key for display name
    private var localizationKey: String {
        switch self {
        case .tsukiSound:
            return "category.tsukiSound"
        }
    }

    /// Get all presets in this category
    public var presets: [UISoundPreset] {
        switch self {
        case .tsukiSound:
            return Array(UISoundPreset.allCases)
        }
    }
}
