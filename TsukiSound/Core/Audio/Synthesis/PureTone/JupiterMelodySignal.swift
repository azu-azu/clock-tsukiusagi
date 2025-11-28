//
//  JupiterMelodySignal.swift
//  TsukiSound
//
//  Jupiter Melody - Holst's "The Planets" Jupiter theme in C Major
//  Organ-style melody with ASR envelope for cathedral atmosphere
//
//  Refactored with Ren's suggestions:
//  - ASR envelope (Attack-Sustain-Release) instead of Decay
//  - Readable note definitions using Pitch and Duration enums
//  - Added 8th harmonic (Mixture stop) for brilliance
//

import Foundation

/// JupiterMelodySignal - Holst's Jupiter theme adapted for organ
///
/// Produces a majestic, solemn melody based on Holst's "Jupiter" (public domain).
/// Transposed from E Major to C Major to harmonize with CathedralStillness drone (C/G).
///
/// Characteristics:
/// - Syllabic phrasing for natural vocal-style articulation
/// - Climax with G5 peak and resolution
/// - Organ-style ASR envelope (Attack-Sustain-Release)
/// - Rich harmonics with 8th overtone (Mixture stop)
///
/// Legal: Holst's "The Planets" (1918) is public domain (composer died 1934, >70 years).
public struct JupiterMelodySignal {

    /// Create Jupiter melody signal
    /// - Returns: Signal generating the Jupiter melody
    public static func makeSignal() -> Signal {
        let generator = JupiterMelodyGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

// MARK: - Private Implementation

private final class JupiterMelodyGenerator {

    // MARK: - Constants & Configuration

    /// BPM Control: 75 BPM
    /// Quarter note = 0.8s (60.0 / 75.0)
    private static let beatDuration: Float = 0.8

    // MARK: - Data Structures

    /// Note length abstraction to avoid magic numbers
    /// All values are multiplied by beatDuration (0.8s)
    enum Duration: Float {
        case thirtySecond  = 0.125 // 32分音符
        case sixteenth     = 0.25  // 16分音符
        case eighth        = 0.5   // 8分音符
        case dottedEighth  = 0.75  // 付点8分
        case quarter       = 1.0   // 4分音符
        case dottedQuarter = 1.5   // 付点4分
        case half          = 2.0   // 2分音符
        case dottedHalf    = 3.0   // 付点2分
        case whole         = 4.0   // 全音符

        var seconds: Float { self.rawValue * JupiterMelodyGenerator.beatDuration }
    }

    /// Note pitch abstraction with frequency values
    /// Added F5 and G5 for the climax (the emotional peak)
    enum Pitch: Float {
        case E4 = 329.63
        case G4 = 392.00
        case A4 = 440.00
        case B4 = 493.88
        case C5 = 523.25
        case D5 = 587.33
        case E5 = 659.25
        case F5 = 698.46  // High F - for descent from peak
        case G5 = 783.99  // High G - THE PEAK (most emotional point)
    }

    /// Single note with frequency and duration
    struct Note {
        let freq: Float
        let duration: Float

        /// Create note with Pitch and Duration enums
        init(_ pitch: Pitch, _ len: Duration) {
            self.freq = pitch.rawValue
            self.duration = len.seconds
        }

        /// Create note with manual duration (for special cases like final note)
        init(_ pitch: Pitch, seconds: Float) {
            self.freq = pitch.rawValue
            self.duration = seconds
        }
    }

    // MARK: - Melody Definition

    /// Jupiter chorale melody (First 20 measures)
    ///
    /// Based on Holst's Jupiter theme, adjusted for precise score rhythm (d=75 BPM).
    /// Transposed to C Major.
    let melody: [Note] = [

        // === Measures 1-4 (木星の有名なフレーズ) ===
        // 1小節目: ミソ ララドシソ
        Note(.E4, .eighth),           // ミ
        Note(.G4, .eighth),           // ソ
        Note(.A4, .dottedEighth),     // ラ
        Note(.C5, .sixteenth),        // ラ -> C5
        Note(.B4, .eighth),           // ド -> B4
        Note(.G4, .eighth),           // シ -> G4

        // 2小節目: ドレドシ ラシラソ
        Note(.C5, .sixteenth),        // ド
        Note(.D5, .sixteenth),        // レ
        Note(.C5, .sixteenth),        // ド
        Note(.B4, .sixteenth),        // シ
        Note(.A4, .dottedEighth),     // ラ
        Note(.B4, .sixteenth),        // シ

        // 3小節目: ミミソ
        Note(.A4, .eighth),           // ラ
        Note(.G4, .eighth),           // ソ
        Note(.E4, .eighth),           // ミ
        Note(.E4, .eighth),           // ミ
        Note(.G4, .quarter),          // ソ

        // 4小節目: ミソ (次のフレーズへの準備)
        Note(.E4, .dottedQuarter),    // ミ
        Note(.G4, .eighth),           // ソ

        // === Measures 5-8 (2回目のフレーズ) ===
        // 5小節目: ララドシソ
        Note(.A4, .dottedEighth),     // ラ
        Note(.C5, .sixteenth),        // ラ
        Note(.B4, .eighth),           // ド
        Note(.G4, .eighth),           // シ

        // 6小節目: ドレミミ
        Note(.C5, .eighth),           // ソ
        Note(.D5, .eighth),           // ド
        Note(.E5, .eighth),           // レ
        Note(.E5, .eighth),           // ミ

        // 7小節目: ミレドレ
        Note(.E5, .eighth),           // ミ
        Note(.D5, .eighth),           // レ
        Note(.C5, .eighth),           // ド
        Note(.D5, .eighth),           // レ

        // 8小節目: ド (長めの音)
        Note(.C5, .half),             // ド

        // === Measures 9-12 (展開フレーズ) ===
        // 9小節目: レレドミラ
        Note(.D5, .quarter),          // レ
        Note(.E5, .eighth),           // レ
        Note(.C5, .eighth),           // ド
        Note(.A4, .quarter),          // ミ

        // 10小節目: ソソミレ
        Note(.G4, .eighth),           // ソ
        Note(.G4, .eighth),           // ソ
        Note(.E5, .eighth),           // ミ
        Note(.D5, .eighth),           // レ

        // 11小節目: レレミソラ
        Note(.D5, .eighth),           // レ
        Note(.E5, .eighth),           // レ
        Note(.G4, .eighth),           // ミ
        Note(.A4, .eighth),           // ソ

        // 12小節目: ラシ
        Note(.A4, .quarter),          // ラ
        Note(.B4, .half),             // シ

        // === Measures 13-16 (下降フレーズ) ===
        // 13小節目: ドシラソ
        Note(.C5, .eighth),           // ド
        Note(.B4, .eighth),           // シ
        Note(.A4, .eighth),           // ラ
        Note(.G4, .eighth),           // ソ

        // 14小節目: ドレミ
        Note(.C5, .eighth),           // ド
        Note(.D5, .eighth),           // レ
        Note(.E5, .eighth),           // ミ

        // 15小節目: レドレミソ
        Note(.D5, .eighth),           // レ
        Note(.C5, .eighth),           // ド
        Note(.D5, .eighth),           // レ
        Note(.E5, .eighth),           // ミ

        // 16小節目: ミソ (繰り返しへの準備)
        Note(.E5, .quarter),          // ソ
        Note(.G4, .half),             // ミ

        // === 最終解決 (Climax and Resolution) ===
        Note(.C5, .quarter),
        Note(.D5, .quarter),
        Note(.E5, .quarter),
        Note(.G5, .dottedQuarter),
        Note(.F5, .eighth),
        Note(.E5, .eighth),
        Note(.D5, .quarter),
        Note(.C5, .eighth),
        Note(.B4, .eighth),
        Note(.C5, .whole)             // 全音符
    ]

    // MARK: - Timing & Optimization

    /// Cumulative times for efficient note indexing
    /// Calculated once and cached
    lazy var cumulativeTimes: [Float] = {
        var times: [Float] = [0.0]
        for note in melody {
            times.append(times.last! + note.duration)
        }
        return times
    }()

    /// Total cycle duration
    lazy var cycleDuration: Float = cumulativeTimes.last!

    // MARK: - Sound Design (Organ Characteristics)

    /// Organ-style harmonics with Mixture stop (8th harmonic)
    /// The 8.0 harmonic adds "brilliance" typical of cathedral organs
    let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0, 8.0]

    /// Harmonic amplitudes: rich organ tone with subtle Mixture
    let harmonicAmps: [Float] = [1.0, 0.5, 0.3, 0.1, 0.05]

    /// ASR Envelope Parameters (Organ-style)
    /// - Attack: Slow rise for cathedral feel
    /// - Sustain: Full volume held during note
    /// - Release: Smooth fade to prevent clicks
    let attackTime: Float = 0.1   // 100ms: slow attack for organ feel
    let releaseTime: Float = 0.2  // 200ms: smooth release to prevent clicks

    /// Master gain for balance with other layers
    let masterGain: Float = 0.30

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)

        guard let index = findNoteIndex(at: cycleTime) else { return 0.0 }

        let note = melody[index]
        let noteStartTime = cumulativeTimes[index]
        let localTime = cycleTime - noteStartTime

        // 1. Calculate ASR Envelope (Attack, Sustain, Release)
        let envelope = calculateOrganEnvelope(time: localTime, duration: note.duration)

        // 2. Generate Organ Tone (Additive Synthesis)
        var signal: Float = 0.0
        for i in 0..<harmonics.count {
            let hFreq = note.freq * harmonics[i]
            let phase = 2.0 * Float.pi * hFreq * t
            signal += sin(phase) * harmonicAmps[i]
        }

        // Normalize by harmonic count
        signal /= Float(harmonics.count)

        return signal * envelope * masterGain
    }

    // MARK: - Helper Methods

    /// Find index of note playing at given time
    private func findNoteIndex(at time: Float) -> Int? {
        for i in 0..<melody.count {
            if time >= cumulativeTimes[i] && time < cumulativeTimes[i + 1] {
                return i
            }
        }
        return nil
    }

    /// Generates a trapezoidal ASR envelope (Attack -> Sustain -> Release)
    /// This is crucial for organ sounds - they sustain while key is pressed.
    ///
    /// Shape:
    /// ```
    /// 1.0 ┌───────────────────┐
    ///     │  Attack  Sustain  │ Release
    ///     │   /               │\
    /// 0.0 └───────────────────┴────
    ///     0   attackTime    end-releaseTime  end
    /// ```
    private func calculateOrganEnvelope(time: Float, duration: Float) -> Float {
        // Attack Phase: smooth rise
        if time < attackTime {
            return time / attackTime
        }
        // Release Phase: smooth fade at end of note
        else if time > (duration - releaseTime) {
            let releaseStart = duration - releaseTime
            let timeInRelease = time - releaseStart
            // Clamp to prevent negative values for very short notes
            let releaseProgress = min(timeInRelease / releaseTime, 1.0)
            return max(1.0 - releaseProgress, 0.0)
        }
        // Sustain Phase: full volume
        else {
            return 1.0
        }
    }
}

// MARK: - Design Notes
//
// REFACTORING SUMMARY (2025-11-27):
//
// Based on Ren's code review suggestions:
//
// 1. ENVELOPE CHANGE: Decay → ASR (Attack-Sustain-Release)
//    - Before: exp(-decayTime / decay) - bell/piano-like decay
//    - After: Trapezoidal ASR - organ-like sustain
//    - Result: Sound sustains during note, then releases smoothly
//
// 2. READABLE NOTE DEFINITIONS:
//    - Before: Note(freq: 329.63, duration: 0.80)
//    - After: Note(.E4, .eighth)
//    - Result: Melody is now human-readable and music-theory aligned
//
// 3. HARMONIC ENRICHMENT:
//    - Before: [1.0, 2.0, 3.0, 4.0]
//    - After: [1.0, 2.0, 3.0, 4.0, 8.0] with amp 0.05
//    - Result: Added "Mixture stop" brilliance typical of cathedral organs
//
// 4. CLICK PREVENTION:
//    - Added 200ms release time at end of each note
//    - Prevents "pop" noise at note transitions
//
// 5. MELODY REWRITE (2025-11-28):
//    - Rewrote melody for syllabic phrasing (vocal-style articulation)
//    - More even eighth notes for clear syllable separation
//    - Added climax: G5 (the emotional peak)
//    - Resolution: landing on C5 with long sustain
//
// MELODY DESIGN:
//
// Source: Holst's "Thaxted" chorale from Jupiter (1918, public domain)
// Key: C Major (fits CathedralStillness C/G drone)
// Phrasing: Syllabic rhythm for natural vocal flow
//
// MELODIC STRUCTURE:
//
// Phrase 1-2: Introduction and Response
// Phrase 3:   Development (ascending to E5)
// Phrase 4:   Bridge to Climax
// Phrase 5:   THE CLIMAX (G5 peak) → Descent → Resolution (C5)
//
// INTEGRATION WITH CATHEDRALSTILLNESS:
//
// Layer architecture:
// 1. Organ drone (C3 + G3, 0.02Hz LFO) - foundation
// 2. Harp arpeggios (MidnightDroplets) - sparse decoration
// 3. Jupiter chorale (this) - majestic centerpiece
//
// COPYRIGHT:
//
// Gustav Holst died in 1934. Under Japanese copyright law (70 years after death),
// "The Planets" entered public domain in 2004. Using the melody is completely legal.
