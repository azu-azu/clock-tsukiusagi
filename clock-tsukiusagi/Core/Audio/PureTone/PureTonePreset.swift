//
//  PureTonePreset.swift
//  clock-tsukiusagi
//
//  Pure tone preset definitions (separate from NaturalSound)
//

import Foundation

/// Pure tone presets (sine wave based, highly sensitive to parameter changes)
public enum PureTonePreset {
    case pentatonicChime    // Pentatonic chime bells (Signal-based)
    case treeChimeOnly      // TreeChime only (for testing)

    /// Whether this preset uses Signal-based implementation
    public var usesSignalEngine: Bool {
        switch self {
        case .pentatonicChime:
            return true
        case .treeChimeOnly:
            return false
        }
    }

    /// Whether this preset includes TreeChime
    public var includesTreeChime: Bool {
        switch self {
        case .treeChimeOnly:
            return true
        case .pentatonicChime:
            return false
        }
    }
}
