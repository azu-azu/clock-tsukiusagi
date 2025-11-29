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
    case jupiter                // ジュピター（PureTone module）
    case moonlitGymnopedie      // Moonlit Gymnopédie（PureTone module）

    public var id: String { rawValue }

    /// Display name for UI (Japanese with emoji)
    public var displayName: String {
        switch self {
        case .jupiter:
            return "🪐 ジュピターの響き"
        case .moonlitGymnopedie:
            return "🌖 月明かりのジムノペディ"
        }
    }

    /// English title for selected display
    public var englishTitle: String {
        switch self {
        case .jupiter:
            return "Jupiter (Holst)"
        case .moonlitGymnopedie:
            return "Moonlit Gymnopédie"
        }
    }
}
