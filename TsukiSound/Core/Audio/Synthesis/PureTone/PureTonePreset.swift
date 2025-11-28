//
//  PureTonePreset.swift
//  TsukiSound
//
//  Pure tone preset definitions (separate from NaturalSound)
//

import Foundation

/// Pure tone presets (sine wave based, highly sensitive to parameter changes)
public enum PureTonePreset {
    case cathedralStillness // Cathedral organ drone (Signal-based)
    case midnightDroplets   // Sparse arpeggio harp (Signal-based)
    case moonlitGymnopedie      // Satie Gymnopédie No.1 melody (Signal-based)

    /// Whether this preset uses Signal-based implementation
    public var usesSignalEngine: Bool {
        switch self {
        case .cathedralStillness:
            return true
        case .midnightDroplets:
            return true
        case .moonlitGymnopedie:
            return true
        }
    }

    /// Whether this preset includes TreeChime
    public var includesTreeChime: Bool {
        switch self {
        case .cathedralStillness:
            return false
        case .midnightDroplets:
            return false
        case .moonlitGymnopedie:
            return false
        }
    }
}
