//
//  JupiterMelodyData.swift
//  TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter
//
//  Jupiter メロディデータ（純データ分離）
//  Holst's "The Planets" Jupiter theme (Public Domain)
//  楽譜: pianojuku.info (F Major → C Major に移調)
//

import Foundation

// MARK: - Data Structures

/// BPM Control: 60 BPM (slower, more majestic)
/// Quarter note = 1.0s (60.0 / 60.0 = 1.0)
let jupiterBeatDuration: Float = 1.0

/// メロディの1音を表す構造体（Gymnopédie方式）
struct JupiterMelodyNote {
    let freq: Float
    let startBar: Int      // 1-indexed
    let startBeat: Float   // 0, 1, 2 (3/4拍子)
    let durBeats: Float

    init(
        _ pitch: JupiterPitch,
        bar: Int,
        beat: Float,
        dur: JupiterDuration
    ) {
        self.freq = pitch.rawValue
        self.startBar = bar
        self.startBeat = beat
        self.durBeats = dur.rawValue
    }

    init(
        _ pitch: JupiterPitch,
        bar: Int,
        beat: Float,
        durBeats: Float
    ) {
        self.freq = pitch.rawValue
        self.startBar = bar
        self.startBeat = beat
        self.durBeats = durBeats
    }
}

/// Note length abstraction (in beats)
enum JupiterDuration: Float {
    case sixteenth     = 0.25  // 16分音符
    case eighth        = 0.5   // 8分音符
    case dottedEighth  = 0.75  // 付点8分
    case quarter       = 1.0   // 4分音符
    case half          = 2.0   // 2分音符
    case dottedHalf    = 3.0   // 付点2分
}

/// Note pitch abstraction with frequency values (C Major)
enum JupiterPitch: Float {
    // Low octave
    case C4  = 261.63
    case D4  = 293.66
    case E4  = 329.63
    case F4  = 349.23
    case G4  = 392.00
    case A4  = 440.00
    case B4  = 493.88

    // High octave
    case C5  = 523.25
    case D5  = 587.33
    case E5  = 659.25
    case F5  = 698.46
    case G5  = 783.99
    case A5  = 880.00
    case B5  = 987.77
    case C6  = 1046.50
    case D6  = 1174.66
    case E6  = 1318.51
}

// MARK: - Melody Data Provider

/// Jupiterのメロディデータを提供する
///
/// Jupiter chorale melody (25 measures, 3/4 time)
/// Based on Holst's Jupiter theme from pianojuku.info score.
/// Original: F Major → Transposed to C Major
///
/// 3/4拍子: 1小節 = 3拍 (beat 0, 1, 2)
/// 8分音符 = 0.5拍, 4分音符 = 1拍, 付点8分 = 0.75拍, 16分 = 0.25拍
enum JupiterMelodyData {

    static let melody: [JupiterMelodyNote] = [

        // === Bar 1 === 休符(2拍) + ミソ(8分+8分)
        JupiterMelodyNote(.E4, bar: 1, beat: 2.0, dur: .eighth),   // ミ
        JupiterMelodyNote(.G4, bar: 1, beat: 2.5, dur: .eighth),   // ソ

        // === Bar 2 === ラ(4分) ラドシ.ソ(8+8+付点8+16)
        // ラ=1拍, ラ=0.5, ド=0.5, シ.=0.75, ソ=0.25 → 合計3拍 ✓
        JupiterMelodyNote(.A4, bar: 2, beat: 0.0, dur: .quarter),  // ラ (1拍)
        JupiterMelodyNote(.A4, bar: 2, beat: 1.0, dur: .eighth),   // ラ (0.5拍)
        JupiterMelodyNote(.C5, bar: 2, beat: 1.5, dur: .eighth),   // ド (0.5拍)
        JupiterMelodyNote(.B4, bar: 2, beat: 2.0, dur: .dottedEighth), // シ (0.75拍)
        JupiterMelodyNote(.G4, bar: 2, beat: 2.75, dur: .sixteenth),   // ソ (0.25拍)

        // === Bar 3 === ドレド シ
        // 楽譜: ド(8分)レ(8分)ド(4分) シ(4分) → 0.5+0.5+1+1 = 3拍 ✓
        JupiterMelodyNote(.C5, bar: 3, beat: 0.0, dur: .eighth),   // ド
        JupiterMelodyNote(.D5, bar: 3, beat: 0.5, dur: .eighth),   // レ
        JupiterMelodyNote(.C5, bar: 3, beat: 1.0, dur: .quarter),  // ド
        JupiterMelodyNote(.B4, bar: 3, beat: 2.0, dur: .quarter),  // シ

        // === Bar 4 === ラシラ ソ
        // ラ(8分)シ(8分)ラ(4分) ソ(4分) → 0.5+0.5+1+1 = 3拍 ✓
        JupiterMelodyNote(.A4, bar: 4, beat: 0.0, dur: .eighth),   // ラ
        JupiterMelodyNote(.B4, bar: 4, beat: 0.5, dur: .eighth),   // シ
        JupiterMelodyNote(.A4, bar: 4, beat: 1.0, dur: .quarter),  // ラ
        JupiterMelodyNote(.G4, bar: 4, beat: 2.0, dur: .quarter),  // ソ

        // === Bar 5 === ミ(2分) ミソ
        // ミ(2分) ミ(8分)ソ(8分) → 2+0.5+0.5 = 3拍 ✓
        JupiterMelodyNote(.E4, bar: 5, beat: 0.0, dur: .half),     // ミ
        JupiterMelodyNote(.E4, bar: 5, beat: 2.0, dur: .eighth),   // ミ
        JupiterMelodyNote(.G4, bar: 5, beat: 2.5, dur: .eighth),   // ソ

        // === Bar 6 === ラ ラドシ.ソ (Bar 2と同じパターン)
        JupiterMelodyNote(.A4, bar: 6, beat: 0.0, dur: .quarter),  // ラ
        JupiterMelodyNote(.A4, bar: 6, beat: 1.0, dur: .eighth),   // ラ
        JupiterMelodyNote(.C5, bar: 6, beat: 1.5, dur: .eighth),   // ド
        JupiterMelodyNote(.B4, bar: 6, beat: 2.0, dur: .dottedEighth), // シ
        JupiterMelodyNote(.G4, bar: 6, beat: 2.75, dur: .sixteenth),   // ソ

        // === Bar 7 === ドレ ミ ミ
        // ド(8分)レ(8分) ミ(4分) ミ(4分) → 0.5+0.5+1+1 = 3拍 ✓
        JupiterMelodyNote(.C5, bar: 7, beat: 0.0, dur: .eighth),   // ド
        JupiterMelodyNote(.D5, bar: 7, beat: 0.5, dur: .eighth),   // レ
        JupiterMelodyNote(.E5, bar: 7, beat: 1.0, dur: .quarter),  // ミ
        JupiterMelodyNote(.E5, bar: 7, beat: 2.0, dur: .quarter),  // ミ

        // === Bar 8 === ミレド レ
        // ミ(8分)レ(8分)ド(4分) レ(4分) → 0.5+0.5+1+1 = 3拍 ✓
        JupiterMelodyNote(.E5, bar: 8, beat: 0.0, dur: .eighth),   // ミ
        JupiterMelodyNote(.D5, bar: 8, beat: 0.5, dur: .eighth),   // レ
        JupiterMelodyNote(.C5, bar: 8, beat: 1.0, dur: .quarter),  // ド
        JupiterMelodyNote(.D5, bar: 8, beat: 2.0, dur: .quarter),  // レ

        // === Bar 9 === ド(2分) ソミ
        // ド(2分) ソ(8分)ミ(8分) → 2+0.5+0.5 = 3拍 ✓
        JupiterMelodyNote(.C5, bar: 9, beat: 0.0, dur: .half),     // ド
        JupiterMelodyNote(.G4, bar: 9, beat: 2.0, dur: .eighth),   // ソ
        JupiterMelodyNote(.E4, bar: 9, beat: 2.5, dur: .eighth),   // ミ

        // === Bar 10 === レ レ ドミ
        // レ(4分) レ(4分) ド(8分)ミ(8分) → 1+1+0.5+0.5 = 3拍 ✓
        JupiterMelodyNote(.D5, bar: 10, beat: 0.0, dur: .quarter), // レ
        JupiterMelodyNote(.D5, bar: 10, beat: 1.0, dur: .quarter), // レ
        JupiterMelodyNote(.C5, bar: 10, beat: 2.0, dur: .eighth),  // ド
        JupiterMelodyNote(.E5, bar: 10, beat: 2.5, dur: .eighth),  // ミ

        // === Bar 11 === レ ソソミ
        // 楽譜確認: レ(4分) ソ(8分)ソ(8分)ミ(4分) → 1+0.5+0.5+1 = 3拍 ✓
        JupiterMelodyNote(.D5, bar: 11, beat: 0.0, dur: .quarter), // レ
        JupiterMelodyNote(.G5, bar: 11, beat: 1.0, dur: .eighth),  // ソ (上)
        JupiterMelodyNote(.G5, bar: 11, beat: 1.5, dur: .eighth),  // ソ
        JupiterMelodyNote(.E5, bar: 11, beat: 2.0, dur: .quarter), // ミ

        // === Bar 12 === レ レミソ
        // レ(4分) レ(8分)ミ(8分)ソ(4分) → 1+0.5+0.5+1 = 3拍 ✓
        JupiterMelodyNote(.D5, bar: 12, beat: 0.0, dur: .quarter), // レ
        JupiterMelodyNote(.D5, bar: 12, beat: 1.0, dur: .eighth),  // レ
        JupiterMelodyNote(.E5, bar: 12, beat: 1.5, dur: .eighth),  // ミ
        JupiterMelodyNote(.G5, bar: 12, beat: 2.0, dur: .quarter), // ソ

        // === Bar 13 === ラ(2分) ラシ
        JupiterMelodyNote(.A5, bar: 13, beat: 0.0, dur: .half),    // ラ
        JupiterMelodyNote(.A5, bar: 13, beat: 2.0, dur: .eighth),  // ラ
        JupiterMelodyNote(.B5, bar: 13, beat: 2.5, dur: .eighth),  // シ

        // === Bar 14 === ド シ ラ
        JupiterMelodyNote(.C6, bar: 14, beat: 0.0, dur: .quarter), // ド
        JupiterMelodyNote(.B5, bar: 14, beat: 1.0, dur: .quarter), // シ
        JupiterMelodyNote(.A5, bar: 14, beat: 2.0, dur: .quarter), // ラ

        // === Bar 15 === ソ ド ミ
        JupiterMelodyNote(.G5, bar: 15, beat: 0.0, dur: .quarter), // ソ
        JupiterMelodyNote(.C6, bar: 15, beat: 1.0, dur: .quarter), // ド (高)
        JupiterMelodyNote(.E5, bar: 15, beat: 2.0, dur: .quarter), // ミ

        // === Bar 16 === レド レ ミ
        JupiterMelodyNote(.D5, bar: 16, beat: 0.0, dur: .eighth),  // レ
        JupiterMelodyNote(.C5, bar: 16, beat: 0.5, dur: .eighth),  // ド
        JupiterMelodyNote(.D5, bar: 16, beat: 1.0, dur: .quarter), // レ
        JupiterMelodyNote(.E5, bar: 16, beat: 2.0, dur: .quarter), // ミ

        // === Bar 17 === ソ(2分) ミソ
        JupiterMelodyNote(.G5, bar: 17, beat: 0.0, dur: .half),    // ソ
        JupiterMelodyNote(.E5, bar: 17, beat: 2.0, dur: .eighth),  // ミ
        JupiterMelodyNote(.G5, bar: 17, beat: 2.5, dur: .eighth),  // ソ

        // === Bar 18 === ラ ラドシ.ソ (Bar 2, 6と同じパターン)
        JupiterMelodyNote(.A5, bar: 18, beat: 0.0, dur: .quarter), // ラ
        JupiterMelodyNote(.A5, bar: 18, beat: 1.0, dur: .eighth),  // ラ
        JupiterMelodyNote(.C6, bar: 18, beat: 1.5, dur: .eighth),  // ド
        JupiterMelodyNote(.B5, bar: 18, beat: 2.0, dur: .dottedEighth), // シ
        JupiterMelodyNote(.G5, bar: 18, beat: 2.75, dur: .sixteenth),   // ソ

        // === Bar 19 === ドレド シ (Bar 3と同じパターン)
        JupiterMelodyNote(.C6, bar: 19, beat: 0.0, dur: .eighth),  // ド
        JupiterMelodyNote(.D6, bar: 19, beat: 0.5, dur: .eighth),  // レ
        JupiterMelodyNote(.C6, bar: 19, beat: 1.0, dur: .quarter), // ド
        JupiterMelodyNote(.B5, bar: 19, beat: 2.0, dur: .quarter), // シ

        // === Bar 20 === ラシラ ソ (Bar 4と同じパターン)
        JupiterMelodyNote(.A5, bar: 20, beat: 0.0, dur: .eighth),  // ラ
        JupiterMelodyNote(.B5, bar: 20, beat: 0.5, dur: .eighth),  // シ
        JupiterMelodyNote(.A5, bar: 20, beat: 1.0, dur: .quarter), // ラ
        JupiterMelodyNote(.G5, bar: 20, beat: 2.0, dur: .quarter), // ソ

        // === Bar 21 === ミ(2分) ミソ (Bar 5と同じパターン)
        JupiterMelodyNote(.E5, bar: 21, beat: 0.0, dur: .half),    // ミ
        JupiterMelodyNote(.E5, bar: 21, beat: 2.0, dur: .eighth),  // ミ
        JupiterMelodyNote(.G5, bar: 21, beat: 2.5, dur: .eighth),  // ソ

        // === Bar 22 === ラ ラドシ.ソ (Bar 2, 6, 18と同じパターン)
        JupiterMelodyNote(.A5, bar: 22, beat: 0.0, dur: .quarter), // ラ
        JupiterMelodyNote(.A5, bar: 22, beat: 1.0, dur: .eighth),  // ラ
        JupiterMelodyNote(.C6, bar: 22, beat: 1.5, dur: .eighth),  // ド
        JupiterMelodyNote(.B5, bar: 22, beat: 2.0, dur: .dottedEighth), // シ
        JupiterMelodyNote(.G5, bar: 22, beat: 2.75, dur: .sixteenth),   // ソ

        // === Bar 23 === ドレ ミ ミ (Bar 7と同じパターン)
        JupiterMelodyNote(.C6, bar: 23, beat: 0.0, dur: .eighth),  // ド
        JupiterMelodyNote(.D6, bar: 23, beat: 0.5, dur: .eighth),  // レ
        JupiterMelodyNote(.E6, bar: 23, beat: 1.0, dur: .quarter), // ミ
        JupiterMelodyNote(.E6, bar: 23, beat: 2.0, dur: .quarter), // ミ

        // === Bar 24 === ミレド レ (Bar 8と同じパターン)
        JupiterMelodyNote(.E6, bar: 24, beat: 0.0, dur: .eighth),  // ミ
        JupiterMelodyNote(.D6, bar: 24, beat: 0.5, dur: .eighth),  // レ
        JupiterMelodyNote(.C6, bar: 24, beat: 1.0, dur: .quarter), // ド
        JupiterMelodyNote(.D6, bar: 24, beat: 2.0, dur: .quarter), // レ

        // === Bar 25 === ド (付点2分 = 終止)
        JupiterMelodyNote(.C6, bar: 25, beat: 0.0, dur: .dottedHalf), // ド
    ]

    /// Total number of bars
    static let totalBars: Int = 25
}
