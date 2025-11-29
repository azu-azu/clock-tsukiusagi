//
//  JupiterMelodyData.swift
//  TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter
//
//  Jupiter メロディデータ（純データ分離）
//  Holst's "The Planets" Jupiter theme (Public Domain)
//

import Foundation

// MARK: - Data Structures

/// BPM Control: 50 BPM (slower, more majestic tempo)
/// Quarter note = 1.2s (60.0 / 50.0 = 1.2)
let jupiterBeatDuration: Float = 1.2

/// Note length abstraction to avoid magic numbers
enum JupiterDuration: Float {
    case thirtySecond  = 0.125 // 32分音符
    case sixteenth     = 0.25  // 16分音符
    case eighth        = 0.5   // 8分音符
    case dottedEighth  = 0.75  // 付点8分
    case quarter       = 1.0   // 4分音符
    case dottedQuarter = 1.5   // 付点4分
    case half          = 2.0   // 2分音符
    case dottedHalf    = 3.0   // 付点2分
    case whole         = 4.0   // 全音符

    var seconds: Float { self.rawValue * jupiterBeatDuration }
}

/// Note pitch abstraction with frequency values
enum JupiterPitch: Float {
    case E4 = 329.63
    case G4 = 392.00
    case A4 = 440.00
    case B4 = 493.88
    case C5 = 523.25
    case D5 = 587.33
    case E5 = 659.25
    case F5 = 698.46
    case G5 = 783.99
    case A5 = 880.00
    case B5 = 987.77
    case C6 = 1046.50
}

/// Single note with frequency and duration
struct JupiterMelodyNote {
    let freq: Float
    let duration: Float

    /// Create note with Pitch and Duration enums
    init(_ pitch: JupiterPitch, _ len: JupiterDuration) {
        self.freq = pitch.rawValue
        self.duration = len.seconds
    }

    /// Create note with manual duration (for special cases like final note)
    init(_ pitch: JupiterPitch, seconds: Float) {
        self.freq = pitch.rawValue
        self.duration = seconds
    }
}

// MARK: - Melody Data Provider

/// Jupiterのメロディデータを提供する
///
/// Jupiter chorale melody (25 measures, 3/4 time)
/// Based on Holst's Jupiter theme from the score (pianojuku.info).
/// Transposed to C Major. 3/4 time signature.
///
/// MELODIC STRUCTURE:
/// - Phrase 1-2: Introduction and Response
/// - Phrase 3:   Development (ascending to E5)
/// - Phrase 4:   Bridge to Climax
/// - Phrase 5:   THE CLIMAX (G5 peak) → Descent → Resolution (C5)
enum JupiterMelodyData {

    static let melody: [JupiterMelodyNote] = [

        // === 1小節目 ===
        JupiterMelodyNote(.E4, .eighth),           // ミ (8分)
        JupiterMelodyNote(.G4, .eighth),           // ソ (8分)
        JupiterMelodyNote(.A4, .quarter),          // ラ (4分)

        // === 2小節目 ===
        JupiterMelodyNote(.A4, .eighth),           // ラ (8分)
        JupiterMelodyNote(.C5, .eighth),           // ド (8分)
        JupiterMelodyNote(.B4, .dottedEighth),     // シ (付点8分)
        JupiterMelodyNote(.G4, .sixteenth),        // ソ (16分)
        JupiterMelodyNote(.C5, .eighth),           // ド (8分)
        JupiterMelodyNote(.D5, .eighth),           // レ (8分)
        JupiterMelodyNote(.C5, .quarter),          // ド (4分)

        // === 3小節目 ===
        JupiterMelodyNote(.B4, .quarter),          // シ (4分)
        JupiterMelodyNote(.A4, .eighth),           // ラ (8分)
        JupiterMelodyNote(.B4, .eighth),           // シ (8分)
        JupiterMelodyNote(.A4, .quarter),          // ラ (4分)

        // === 4小節目 ===
        JupiterMelodyNote(.G4, .quarter),          // ソ (4分)
        JupiterMelodyNote(.E4, .half),             // ミ (2分)

        // === 5小節目 ===
        JupiterMelodyNote(.E4, .eighth),           // ミ (8分)
        JupiterMelodyNote(.G4, .eighth),           // ソ (8分)
        JupiterMelodyNote(.A4, .quarter),          // ラ (4分)

        // === 6小節目 ===
        JupiterMelodyNote(.A4, .eighth),           // ラ (8分)
        JupiterMelodyNote(.C5, .eighth),           // ド (8分)
        JupiterMelodyNote(.B4, .dottedEighth),     // シ (付点8分)
        JupiterMelodyNote(.G4, .sixteenth),        // ソ (16分)
        JupiterMelodyNote(.C5, .eighth),           // ド (8分)
        JupiterMelodyNote(.D5, .eighth),           // レ (8分)
        JupiterMelodyNote(.E5, .quarter),          // ミ (4分)

        // === 7小節目 ===
        JupiterMelodyNote(.E5, .quarter),          // ミ (4分)
        JupiterMelodyNote(.E5, .eighth),           // ミ (8分)
        JupiterMelodyNote(.D5, .eighth),           // レ (8分)
        JupiterMelodyNote(.C5, .quarter),          // ド (4分)
        JupiterMelodyNote(.D5, .quarter),          // レ (4分)
        JupiterMelodyNote(.C5, .half),             // ド (2分)

        // === 8小節目 ===
        JupiterMelodyNote(.G5, .eighth),           // ソ (8分) 上
        JupiterMelodyNote(.E5, .eighth),           // ミ (8分) 上
        JupiterMelodyNote(.D5, .quarter),          // レ (4分) 上

        // === 9小節目 ===
        JupiterMelodyNote(.D5, .quarter),          // レ (4分) 上
        JupiterMelodyNote(.C5, .eighth),           // ド (8分)
        JupiterMelodyNote(.E5, .eighth),           // ミ (8分) 上
        JupiterMelodyNote(.D5, .quarter),          // レ (4分) 上
        JupiterMelodyNote(.G4, .quarter),          // ソ (4分) 下

        // === 10小節目 ===
        JupiterMelodyNote(.G5, .eighth),           // ソ (8分) 上
        JupiterMelodyNote(.E5, .eighth),           // ミ (8分) 上
        JupiterMelodyNote(.D5, .quarter),          // レ (4分) 上

        // === 11小節目 ===
        JupiterMelodyNote(.D5, .quarter),          // レ (4分) 上
        JupiterMelodyNote(.E5, .eighth),           // ミ (8分) 上
        JupiterMelodyNote(.G5, .eighth),           // ソ (8分) 上
        JupiterMelodyNote(.A5, .half),             // ラ (2分) 上

        // === 12小節目 ===
        JupiterMelodyNote(.A5, .eighth),           // ラ (8分) 上
        JupiterMelodyNote(.B5, .eighth),           // シ (8分) 上
        JupiterMelodyNote(.C6, .quarter),          // ド (4分) 上
        JupiterMelodyNote(.B5, .quarter),          // シ (4分) 上

        // === 13小節目 ===
        JupiterMelodyNote(.A5, .quarter),          // ラ (4分) 上
        JupiterMelodyNote(.G5, .quarter),          // ソ (4分) 上
        JupiterMelodyNote(.C6, .quarter),          // ド (4分) 上
        JupiterMelodyNote(.E5, .quarter),          // ミ (4分) 上

        // === 14小節目 ===
        JupiterMelodyNote(.D5, .eighth),           // レ (8分) 上
        JupiterMelodyNote(.C5, .eighth),           // ド (8分) 上
        JupiterMelodyNote(.D5, .quarter),          // レ (4分) 上
        JupiterMelodyNote(.E5, .quarter),          // ミ (4分) 上

        // === 15小節目 ===
        JupiterMelodyNote(.G5, .half),             // ソ (2分) 上
        JupiterMelodyNote(.E5, .quarter),          // ミ (4分) - 終止へ

        // === 終止 ===
        JupiterMelodyNote(.C5, .dottedHalf)        // ド (付点2分)
    ]
}
