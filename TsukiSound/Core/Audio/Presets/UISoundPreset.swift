//
//  UISoundPreset.swift
//  TsukiSound
//
//  UI display layer for sound presets (separate from technical parameters)
//

import Foundation

/// Sound preset for UI display (decoupled from technical implementation)
/// This enum represents what users see in the app, not how sounds are generated.
public enum UISoundPreset: String, CaseIterable, Identifiable {
    case softOrgan          // 柔らかなオルガン（PureTone module）
    case toyPiano           // トイピアノ（PureTone module）
    case moonlitGymnopedie      // Moonlit Gymnopédie（PureTone module）
    case midnightGnossienne     // Midnight Gnossienne（PureTone module）

    public var id: String { rawValue }

    /// Display name for UI (Japanese with emoji)
    public var displayName: String {
        switch self {
        case .softOrgan:
            return "🪐 ジュピターの響き"
        case .toyPiano:
            return "⭐ 消えゆく星"
        case .moonlitGymnopedie:
            return "🎹 月明かりのジムノペディ"
        case .midnightGnossienne:
            return "🌑 真夜中のグノシエンヌ"
        }
    }

    /// English title for selected display
    public var englishTitle: String {
        switch self {
        case .softOrgan:
            return "Jupiter (Holst)"
        case .toyPiano:
            return "Fading Star Piano"
        case .moonlitGymnopedie:
            return "Moonlit Gymnopédie"
        case .midnightGnossienne:
            return "Midnight Gnossienne"
        }
    }
}
