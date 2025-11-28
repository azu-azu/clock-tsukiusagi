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

    /// BPM Control: 54 BPM (majestic, solemn tempo)
    /// Quarter note = 1.1s (60.0 / 54.0 ≈ 1.11)
    private static let beatDuration: Float = 1.1

    // MARK: - Data Structures

    /// Note length abstraction to avoid magic numbers
    /// All values are multiplied by beatDuration (1.1s)
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
        // 1小節目: ミソ ラ ラ ド シ ソ (4/4拍子)
        Note(.E4, .eighth),           // ミ (8分)
        Note(.G4, .eighth),           // ソ (8分)
        Note(.A4, .eighth),           // ラ (8分)
        Note(.A4, .eighth),           // ラ (8分)
        Note(.C5, .sixteenth),        // ド (16分)
        Note(.B4, .sixteenth),        // シ (16分)
        Note(.G4, .quarter),          // ソ (4分)

        // 2小節目: ドレドシ ラシラ ソ (4/4拍子)
        Note(.C5, .sixteenth),        // ド (16分)
        Note(.D5, .sixteenth),        // レ (16分)
        Note(.C5, .sixteenth),        // ド (16分)
        Note(.B4, .sixteenth),        // シ (16分)
        Note(.A4, .quarter),          // ラ (4分)
        Note(.B4, .eighth),           // シ (8分)
        Note(.A4, .eighth),           // ラ (8分)
        Note(.G4, .quarter),          // ソ (4分)

        // 3小節目: ミミソ (4/4拍子)
        Note(.E4, .quarter),          // ミ (4分)
        Note(.E4, .quarter),          // ミ (4分)
        Note(.G4, .half),             // ソ (2分)

        // 4小節目: ミ ソ (4/4拍子)
        Note(.E4, .dottedQuarter),    // ミ (付点4分)
        Note(.G4, .eighth),           // ソ (8分)
        Note(.A4, .eighth),           // 次のフレーズへの橋渡しとしてA4を挿入

        // === Measures 5-8 (2回目のフレーズ: 6小節目から) ===
        // 5小節目: ラ ラ ド シ ソ (4/4拍子)
        Note(.A4, .eighth),           // ラ (8分)
        Note(.A4, .eighth),           // ラ (8分)
        Note(.C5, .sixteenth),        // ド (16分)
        Note(.B4, .sixteenth),        // シ (16分)
        Note(.G4, .quarter),          // ソ (4分)
        Note(.C5, .quarter),          // ド (4分)

        // 6小節目: ド レ ミ ミ (4/4拍子)
        Note(.D5, .eighth),           // レ (8分)
        Note(.E5, .eighth),           // ミ (8分)
        Note(.E5, .half),             // ミ (2分)

        // 7小節目: ミ レ ド レ (4/4拍子)
        Note(.E5, .eighth),           // ミ (8分)
        Note(.D5, .eighth),           // レ (8分)
        Note(.C5, .eighth),           // ド (8分)
        Note(.D5, .eighth),           // レ (8分)
        Note(.C5, .half),             // ド (2分)

        // 8小節目: ド (長めの音) (4/4拍子)
        Note(.C5, .whole),            // ド (全音符)

        // === Measures 9-12 (展開フレーズ: 10小節目から) ===
        // 9小節目: レ レ ド ミ レ レ ソ ソ ミ レ (4/4拍子)
        Note(.D5, .eighth),           // レ (8分)
        Note(.E5, .eighth),           // レ (8分)
        Note(.C5, .eighth),           // ド (8分)
        Note(.E5, .eighth),           // ミ (8分)
        Note(.D5, .eighth),           // レ (8分)
        Note(.E5, .eighth),           // レ (8分)
        Note(.G4, .eighth),           // ソ (8分)
        Note(.G4, .eighth),           // ソ (8分)

        // 10小節目: ミ レ レ レ ミ ソ ラ (4/4拍子)
        Note(.E5, .eighth),           // ミ (8分)
        Note(.D5, .eighth),           // レ (8分)
        Note(.D5, .eighth),           // レ (8分)
        Note(.E5, .eighth),           // レ (8分)
        Note(.G4, .eighth),           // ミ (8分)
        Note(.A4, .eighth),           // ソ (8分)
        Note(.A4, .half),             // ラ (2分)

        // 11小節目: ラ シ ド (4/4拍子)
        Note(.B4, .half),             // シ (2分)
        Note(.C5, .half),             // ド (2分)

        // 12小節目: シ ソ (4/4拍子)
        Note(.B4, .whole),            // シ (全音符)

        // === Measures 13-16 (下降フレーズ: 14小節目から) ===
        // 13小節目: ド シ ラ ソ (4/4拍子)
        Note(.C5, .eighth),           // ド (8分)
        Note(.B4, .eighth),           // シ (8分)
        Note(.A4, .eighth),           // ラ (8分)
        Note(.G4, .eighth),           // ソ (8分)
        Note(.C5, .quarter),          // ド (4分)

        // 14小節目: レ ド レ ミ (4/4拍子)
        Note(.D5, .eighth),           // レ (8分)
        Note(.C5, .eighth),           // ド (8分)
        Note(.D5, .eighth),           // レ (8分)
        Note(.E5, .eighth),           // ミ (8分)
        Note(.G4, .quarter),          // ソ (4分)

        // 15小節目: ミ ソ ミ ソ (4/4拍子)
        Note(.E5, .eighth),           // ミ (8分)
        Note(.G4, .eighth),           // ソ (8分)
        Note(.E5, .eighth),           // ミ (8分)
        Note(.G4, .eighth),           // ソ (8分)
        Note(.E5, .half),             // ミ (2分)

        // 16小節目: ソ ミ (4/4拍子)
        Note(.G4, .half),             // ソ (2分)
        Note(.E4, .quarter),          // ミ (4分)
        Note(.C5, .quarter),          // C5を終止として追加

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

    /// Organ-style harmonics with warm foundation
    /// Emphasizing fundamental and lower harmonics for majestic warmth
    let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0, 6.0]

    /// Harmonic amplitudes: warm, full organ tone
    /// Reduced higher harmonics for smoother, more solemn character
    let harmonicAmps: [Float] = [1.0, 0.45, 0.25, 0.12, 0.03]

    /// ASR Envelope Parameters (Organ-style, slower for majesty)
    /// - Attack: Slow rise for cathedral feel
    /// - Sustain: Full volume held during note
    /// - Release: Smooth fade to prevent clicks
    let attackTime: Float = 0.15  // 150ms: slower attack for grandeur
    let releaseTime: Float = 0.3  // 300ms: longer release for legato feel

    /// Master gain for balance with other layers
    let masterGain: Float = 0.28

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
