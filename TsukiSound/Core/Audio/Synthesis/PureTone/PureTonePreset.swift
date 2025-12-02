//
//  PureTonePreset.swift
//  TsukiSound
//
//  Pure tone preset definitions (separate from NaturalSound)
//

import Foundation

/// Pure tone presets (sine wave based, highly sensitive to parameter changes)
/// Note: cathedralStillness and moonlitGymnopedie now use pre-rendered audio files
public enum PureTonePreset {
    case cathedralStillness // Jupiter melody (pre-rendered audio file: cathedral_stillness.caf)
    case midnightDroplets   // Sparse arpeggio harp (Signal-based)
    case moonlitGymnopedie  // Satie Gymnopédie No.1 melody (pre-rendered audio file: moonlit_gymnopedie.caf)
}
