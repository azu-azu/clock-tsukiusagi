//
//  PureTonePreset.swift
//  TsukiSound
//
//  Pure tone preset definitions (separate from NaturalSound)
//

import Foundation

/// Pure tone presets (sine wave based, highly sensitive to parameter changes)
public enum PureTonePreset {
    case cathedralStillness // Jupiter melody (pre-rendered audio file)
    case midnightDroplets   // Sparse arpeggio harp (Signal-based)
    case moonlitGymnopedie  // Satie Gymnopédie No.1 melody (Signal-based)
}
