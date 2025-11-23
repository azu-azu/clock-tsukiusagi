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
    case toyPiano           // おもちゃピアノ（PureTone module）
    case gentleFlute        // やさしいフルート（PureTone module）
    case darkShark          // 黒いサメの影
    case midnightTrain      // 夜汽車
    case distantThunder     // 遠雷

    public var id: String { rawValue }

    /// Indicates if this is a test/development preset
    public var isTest: Bool {
        false  // All are production presets
    }

    /// Display name for UI (Japanese with emoji)
    public var displayName: String {
        switch self {
        case .pentatonic:
            return "🔔 チャイム"
        case .softOrgan:
            return "🎹 大聖堂の静寂"
        case .toyPiano:
            return "🎹 おもちゃピアノ"
        case .gentleFlute:
            return "🪈 やさしいフルート"
        case .darkShark:
            return "🦈 黒いサメの影"
        case .midnightTrain:
            return "🚂 夜汽車"
        case .distantThunder:
            return "⚡ 遠雷"
        }
    }

    /// English title for selected display
    public var englishTitle: String {
        switch self {
        case .pentatonic:
            return "Pentatonic Chime"
        case .softOrgan:
            return "Cathedral Stillness"
        case .toyPiano:
            return "Toy Piano Dream"
        case .gentleFlute:
            return "Gentle Flute Melody"
        case .darkShark:
            return "Dark Shape Underwater"
        case .midnightTrain:
            return "Midnight Train in the Distance"
        case .distantThunder:
            return "Distant Thunder Rumble"
        }
    }
}
