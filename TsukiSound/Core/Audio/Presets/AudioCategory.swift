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
    case tsukiSound  // TsukiSound original tracks
    case canon       // Canon variations (Pachelbel)

    public var id: String { rawValue }

    /// Emoji icon for this category
    public var icon: String {
        switch self {
        case .tsukiSound:
            return "🌙"
        case .canon:
            return "🎻"
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
        case .canon:
            return "category.canon"
        }
    }

    /// Get all presets in this category
    public var presets: [UISoundPreset] {
        switch self {
        case .tsukiSound:
            return [
                .jupiter, .moonlitGymnopedie, .acousticGymnopedie,
                .gnossienne1, .gnossienne3, .gnossienne4Jazz,
                .clairDeLune, .moonlightSonataHipHop,
                .bachAirOnGString, .bachMinuet, .chopinNocturneRain
            ]
        case .canon:
            return [
                .canonOriginal, .canonAmbient, .canonAmbient2,
                .canonSaxophone, .canonClassic, .canonPiano,
                .canonPiano2, .canonPianoStrings, .canon2, .canon3
            ]
        }
    }
}
