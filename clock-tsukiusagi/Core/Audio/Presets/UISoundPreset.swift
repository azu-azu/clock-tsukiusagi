//
//  UISoundPreset.swift
//  clock-tsukiusagi
//
//  UI display layer for sound presets (separate from technical parameters)
//

import Foundation

/// Sound preset for UI display (decoupled from technical implementation)
/// This enum represents what users see in the app, not how sounds are generated.
public enum UISoundPreset: String, CaseIterable, Identifiable {
    case pentatonic         // ペンタトニックチャイム（PureTone module）
    case softOrgan          // 柔らかなオルガン（PureTone module）
    case pluckedHarp        // 爪弾くハープ（PureTone module）
    case darkShark          // 黒いサメの影
    case midnightTrain      // 夜汽車

    public var id: String { rawValue }

    /// Indicates if this is a test/development preset
    public var isTest: Bool {
        false  // All are production presets
    }

    /// Display name for UI (Japanese with emoji)
    public var displayName: String {
        switch self {
        case .pentatonic:
            return "🎵 ペンタトニックチャイム"
        case .softOrgan:
            return "🎹 大聖堂の静寂"
        case .pluckedHarp:
            return "🎻 深夜の雫"
        case .darkShark:
            return "🦈 黒いサメの影"
        case .midnightTrain:
            return "🚂 夜汽車"
        }
    }

    /// English title for selected display
    public var englishTitle: String {
        switch self {
        case .pentatonic:
            return "Pentatonic Chime"
        case .softOrgan:
            return "Cathedral Stillness"
        case .pluckedHarp:
            return "Midnight Droplets"
        case .darkShark:
            return "Dark Shape Underwater"
        case .midnightTrain:
            return "Midnight Train in the Distance"
        }
    }
}
