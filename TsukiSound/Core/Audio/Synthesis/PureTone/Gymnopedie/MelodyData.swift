//
//  MelodyData.swift
//  TsukiSound/Core/Audio/Synthesis/PureTone/Gymnopedie
//
//  Gymnopédie No.1 メロディデータ（純データ分離）
//  楽譜解析 (Ren's transcription - g1 to g5) に基づく
//

import Foundation

// MARK: - Data Structures

/// メロディの1音を表す構造体
struct GymnopedieMelodyNote {
    let freq: Float
    let startBar: Int      // 1-indexed
    let startBeat: Float   // 0, 1, 2
    let durBeats: Float
    let customGain: Float? // nil = use default melodyGain
    let fadeOut: Bool      // true = 後半でフェードアウト（長い持続音用）

    init(
        freq: Float,
        startBar: Int,
        startBeat: Float,
        durBeats: Float,
        customGain: Float? = nil,
        fadeOut: Bool = false
    ) {
        self.freq = freq
        self.startBar = startBar
        self.startBeat = startBeat
        self.durBeats = durBeats
        self.customGain = customGain
        self.fadeOut = fadeOut
    }
}

// MARK: - Frequency Constants (D Major: F#, C#)

/// Gymnopédie用の周波数定数
enum GymnopedieFrequency {
    // Bass
    static let D3:  Float = 146.83
    static let E3:  Float = 164.81
    static let G3:  Float = 196.00

    // Chord
    static let A3:  Float = 220.00
    static let B3:  Float = 246.94
    static let C_4: Float = 277.18   // C#4
    static let D4:  Float = 293.66

    // Melody (wide range)
    static let E4:  Float = 329.63
    static let F_4: Float = 369.99   // F#4
    static let G4:  Float = 392.00
    static let A4:  Float = 440.00
    static let B4:  Float = 493.88
    static let C5:  Float = 523.25   // C5 (ナチュラル)
    static let C_5: Float = 554.37   // C#5
    static let D5:  Float = 587.33
    static let E5:  Float = 659.25
    static let F5:  Float = 698.46   // F5 (ナチュラル)
    static let F_5: Float = 739.99   // F#5
    static let G5:  Float = 783.99
    static let A5:  Float = 880.00
    static let B5:  Float = 987.77   // B5
    static let C6:  Float = 1046.50  // C6 (ナチュラル)
    static let D6:  Float = 1174.66  // D6
    static let E6:  Float = 1318.51  // E6
}

// MARK: - Melody Data Provider

/// Gymnopédieのメロディデータを提供する
/// 構造: 5つのセクション (g1-g5) に分割
/// - g1: Bars 1-12 (Intro + Theme A)
/// - g2: Bars 13-21 (Theme repeat + Development)
/// - g3: Bars 22-26 (Development)
/// - g4: Bars 27-31 (Ascending passage)
/// - g5: Bars 32-39 (Final section + Climax)
enum GymnopedieMelodyData {

    static let melodyNotes: [GymnopedieMelodyNote] =
        sectionG1() + sectionG2() + sectionG3() + sectionG4() + sectionG5()

    // MARK: g1 - Bars 1-12 (Intro + Theme A)
    private static func sectionG1() -> [GymnopedieMelodyNote] {
        typealias F = GymnopedieFrequency
        return [
            // Bar 1-4: Intro (No Melody)

            // Bar 5 (Melody Enters - 1拍休符から)
            GymnopedieMelodyNote(freq: F.F_5, startBar: 5, startBeat: 1, durBeats: 1),   // F#5
            GymnopedieMelodyNote(freq: F.A5, startBar: 5, startBeat: 2, durBeats: 1),    // A5

            // Bar 6
            GymnopedieMelodyNote(freq: F.G5, startBar: 6, startBeat: 0, durBeats: 1),    // G5
            GymnopedieMelodyNote(freq: F.F_5, startBar: 6, startBeat: 1, durBeats: 1),   // F#5
            GymnopedieMelodyNote(freq: F.C_5, startBar: 6, startBeat: 2, durBeats: 1),   // C#5

            // Bar 7
            GymnopedieMelodyNote(freq: F.B4, startBar: 7, startBeat: 0, durBeats: 1),    // B4
            GymnopedieMelodyNote(freq: F.C_5, startBar: 7, startBeat: 1, durBeats: 1),   // C#5
            GymnopedieMelodyNote(freq: F.D5, startBar: 7, startBeat: 2, durBeats: 1),    // D5

            // Bar 8
            GymnopedieMelodyNote(freq: F.A4, startBar: 8, startBeat: 0, durBeats: 3),    // A4 (3拍)

            // Bar 9-12: F#4 持続（フェードアウトで自然に消える）
            GymnopedieMelodyNote(freq: F.F_4, startBar: 9, startBeat: 0, durBeats: 12, fadeOut: true),  // F#4 (12拍)
        ]
    }

    // MARK: g2 - Bars 13-21 (Theme repeat + Development)
    private static func sectionG2() -> [GymnopedieMelodyNote] {
        typealias F = GymnopedieFrequency
        return [
            // Bar 13 (Theme repeat - 1拍休符から)
            GymnopedieMelodyNote(freq: F.F_5, startBar: 13, startBeat: 1, durBeats: 1),  // F#5
            GymnopedieMelodyNote(freq: F.A5, startBar: 13, startBeat: 2, durBeats: 1),   // A5

            // Bar 14
            GymnopedieMelodyNote(freq: F.G5, startBar: 14, startBeat: 0, durBeats: 1),   // G5
            GymnopedieMelodyNote(freq: F.F_5, startBar: 14, startBeat: 1, durBeats: 1),  // F#5
            GymnopedieMelodyNote(freq: F.C_5, startBar: 14, startBeat: 2, durBeats: 1),  // C#5

            // Bar 15
            GymnopedieMelodyNote(freq: F.B4, startBar: 15, startBeat: 0, durBeats: 1),   // B4
            GymnopedieMelodyNote(freq: F.C_5, startBar: 15, startBeat: 1, durBeats: 1),  // C#5
            GymnopedieMelodyNote(freq: F.D5, startBar: 15, startBeat: 2, durBeats: 1),   // D5

            // Bar 16
            GymnopedieMelodyNote(freq: F.A4, startBar: 16, startBeat: 0, durBeats: 3),   // A4 (3拍)

            // Bar 17
            GymnopedieMelodyNote(freq: F.C_5, startBar: 17, startBeat: 0, durBeats: 3),  // C#5 (3拍)

            // Bar 18
            GymnopedieMelodyNote(freq: F.F_5, startBar: 18, startBeat: 0, durBeats: 3),  // F#5 (3拍)

            // Bar 19-21: E5 持続（フェードアウトで自然に消える）
            GymnopedieMelodyNote(freq: F.E5, startBar: 19, startBeat: 0, durBeats: 9, fadeOut: true),   // E5 (9拍)
        ]
    }

    // MARK: g3 - Bars 22-26 (Development)
    private static func sectionG3() -> [GymnopedieMelodyNote] {
        typealias F = GymnopedieFrequency
        return [
            // Bar 22
            GymnopedieMelodyNote(freq: F.A4, startBar: 22, startBeat: 0, durBeats: 1),   // A4
            GymnopedieMelodyNote(freq: F.B4, startBar: 22, startBeat: 1, durBeats: 1),   // B4
            GymnopedieMelodyNote(freq: F.C5, startBar: 22, startBeat: 2, durBeats: 1),   // C5 (ナチュラル)

            // Bar 23
            GymnopedieMelodyNote(freq: F.E5, startBar: 23, startBeat: 0, durBeats: 1),   // E5
            GymnopedieMelodyNote(freq: F.D5, startBar: 23, startBeat: 1, durBeats: 1),   // D5
            GymnopedieMelodyNote(freq: F.B4, startBar: 23, startBeat: 2, durBeats: 1),   // B4

            // Bar 24
            GymnopedieMelodyNote(freq: F.D5, startBar: 24, startBeat: 0, durBeats: 1),   // D5
            GymnopedieMelodyNote(freq: F.C5, startBar: 24, startBeat: 1, durBeats: 1),   // C5 (ナチュラル)
            GymnopedieMelodyNote(freq: F.B4, startBar: 24, startBeat: 2, durBeats: 1),   // B4
            GymnopedieMelodyNote(freq: F.E4, startBar: 24, startBeat: 1, durBeats: 2),   // E4 (Alto)

            // Bar 25-26
            GymnopedieMelodyNote(freq: F.D5, startBar: 25, startBeat: 0, durBeats: 5),   // D5 (5拍)
            GymnopedieMelodyNote(freq: F.D4, startBar: 25, startBeat: 1, durBeats: 2),   // D4 (Alto)
            GymnopedieMelodyNote(freq: F.D5, startBar: 26, startBeat: 2, durBeats: 1),   // D5
            GymnopedieMelodyNote(freq: F.D4, startBar: 26, startBeat: 1, durBeats: 2),   // D4 (Alto)
        ]
    }

    // MARK: g4 - Bars 27-31 (Ascending passage)
    private static func sectionG4() -> [GymnopedieMelodyNote] {
        typealias F = GymnopedieFrequency
        return [
            // Bar 27
            GymnopedieMelodyNote(freq: F.E5, startBar: 27, startBeat: 0, durBeats: 1),   // E5
            GymnopedieMelodyNote(freq: F.F5, startBar: 27, startBeat: 1, durBeats: 1),   // F5 (ナチュラル)
            GymnopedieMelodyNote(freq: F.G5, startBar: 27, startBeat: 2, durBeats: 1),   // G5

            // Bar 28
            GymnopedieMelodyNote(freq: F.A5, startBar: 28, startBeat: 0, durBeats: 1),   // A5
            GymnopedieMelodyNote(freq: F.C5, startBar: 28, startBeat: 1, durBeats: 1),   // C5 (ナチュラル)
            GymnopedieMelodyNote(freq: F.D5, startBar: 28, startBeat: 2, durBeats: 1),   // D5

            // Bar 29
            GymnopedieMelodyNote(freq: F.E5, startBar: 29, startBeat: 0, durBeats: 1),   // E5
            GymnopedieMelodyNote(freq: F.D5, startBar: 29, startBeat: 1, durBeats: 1),   // D5
            GymnopedieMelodyNote(freq: F.B4, startBar: 29, startBeat: 2, durBeats: 1),   // B4
            GymnopedieMelodyNote(freq: F.E4, startBar: 29, startBeat: 1, durBeats: 2),   // E4 (Alto)

            // Bar 30-31
            GymnopedieMelodyNote(freq: F.D5, startBar: 30, startBeat: 0, durBeats: 5),   // D5 (5拍)
            GymnopedieMelodyNote(freq: F.D4, startBar: 30, startBeat: 1, durBeats: 2),   // D4 (Alto)
            GymnopedieMelodyNote(freq: F.D5, startBar: 31, startBeat: 2, durBeats: 1),   // D5
            GymnopedieMelodyNote(freq: F.D4, startBar: 31, startBeat: 1, durBeats: 2),   // D4 (Alto)
        ]
    }

    // MARK: g5 - Bars 32-39 (Final section + Climax)
    private static func sectionG5() -> [GymnopedieMelodyNote] {
        typealias F = GymnopedieFrequency
        return [
            // Bar 32
            GymnopedieMelodyNote(freq: F.G5, startBar: 32, startBeat: 0, durBeats: 3),   // G5 (3拍)

            // Bar 33
            GymnopedieMelodyNote(freq: F.F_5, startBar: 33, startBeat: 0, durBeats: 3),  // F#5 (3拍)

            // Bar 34
            GymnopedieMelodyNote(freq: F.B4, startBar: 34, startBeat: 0, durBeats: 1),   // B4
            GymnopedieMelodyNote(freq: F.A4, startBar: 34, startBeat: 1, durBeats: 1),   // A4
            GymnopedieMelodyNote(freq: F.B4, startBar: 34, startBeat: 2, durBeats: 1),   // B4

            // Bar 35
            GymnopedieMelodyNote(freq: F.C_5, startBar: 35, startBeat: 0, durBeats: 1),  // C#5
            GymnopedieMelodyNote(freq: F.D5, startBar: 35, startBeat: 1, durBeats: 1),   // D5
            GymnopedieMelodyNote(freq: F.E5, startBar: 35, startBeat: 2, durBeats: 1),   // E5

            // Bar 36
            GymnopedieMelodyNote(freq: F.C_5, startBar: 36, startBeat: 0, durBeats: 1),  // C#5
            GymnopedieMelodyNote(freq: F.D5, startBar: 36, startBeat: 1, durBeats: 1),   // D5
            GymnopedieMelodyNote(freq: F.E5, startBar: 36, startBeat: 2, durBeats: 1),   // E5

            // Bar 37
            GymnopedieMelodyNote(freq: F.F_4, startBar: 37, startBeat: 0, durBeats: 3),  // F#4 (3拍)
            GymnopedieMelodyNote(freq: F.D4, startBar: 37, startBeat: 1, durBeats: 1),   // D4 (Alto)
            GymnopedieMelodyNote(freq: F.G4, startBar: 37, startBeat: 2, durBeats: 1),   // G4 (Alto)

            // Bar 38: Am系 - 静かな準備（階段式レイヤー）
            GymnopedieMelodyNote(freq: F.A3, startBar: 38, startBeat: 0.00, durBeats: 3.5, customGain: 0.14),  // Bass A3
            GymnopedieMelodyNote(freq: F.E4, startBar: 38, startBeat: 0.12, durBeats: 3.3, customGain: 0.10),  // Mid E4
            GymnopedieMelodyNote(freq: F.A4, startBar: 38, startBeat: 0.24, durBeats: 3.1, customGain: 0.09),  // High A4 (揺らぎの頂点を前に出す)

            // Bar 39: D Major - 最終クライマックス（階段式レイヤー）
            // Bass → Mid → Color → High の順で積み上げ
            GymnopedieMelodyNote(freq: F.D3, startBar: 39, startBeat: 0.00, durBeats: 6.0, customGain: 0.16),  // Bass D3
            GymnopedieMelodyNote(freq: F.D4, startBar: 39, startBeat: 0.12, durBeats: 5.8, customGain: 0.10),  // Mid D4
            GymnopedieMelodyNote(freq: F.A4, startBar: 39, startBeat: 0.21, durBeats: 5.5, customGain: 0.12),  // Color A4
            GymnopedieMelodyNote(freq: F.D5, startBar: 39, startBeat: 0.30, durBeats: 5.2, customGain: 0.08),  // High D5
        ]
    }
}
