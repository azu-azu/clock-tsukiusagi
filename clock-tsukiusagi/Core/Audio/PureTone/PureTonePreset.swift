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
    case cathedralStillness // Cathedral organ drone (Signal-based)
    case midnightDroplets   // Sparse arpeggio harp (Signal-based)
    case treeChimeOnly      // TreeChime only (for testing)
    case boomHitOnly        // BoomHit only (for testing)
    case toyPiano           // Toy piano chord progression (Signal-based)
    case gentleFlute        // Gentle flute melody (Signal-based)

    /// Whether this preset uses Signal-based implementation
    public var usesSignalEngine: Bool {
        switch self {
        case .pentatonicChime:
            return true
        case .cathedralStillness:
            return true
        case .midnightDroplets:
            return true
        case .treeChimeOnly:
            return false
        case .boomHitOnly:
            return false
        case .toyPiano:
            return true
        case .gentleFlute:
            return true
        }
    }

    /// Whether this preset includes TreeChime
    public var includesTreeChime: Bool {
        switch self {
        case .treeChimeOnly:
            return true
        case .pentatonicChime:
            return true  // TreeChime overlay included
        case .cathedralStillness:
            return false
        case .midnightDroplets:
            return false
        case .boomHitOnly:
            return false
        case .toyPiano:
            return false
        case .gentleFlute:
            return false
        }
    }
}
