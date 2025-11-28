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
    enum Pitch: Float {
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

    /// Jupiter chorale melody (25 measures, 3/4 time)
    ///
    /// Based on Holst's Jupiter theme from the score (pianojuku.info).
    /// Transposed to C Major. 3/4 time signature.
    let melody: [Note] = [

        // === 1小節目 ===
        Note(.E4, .eighth),           // ミ (8分)
        Note(.G4, .eighth),           // ソ (8分)
        Note(.A4, .quarter),          // ラ (4分)

        // === 2小節目 ===
        Note(.A4, .eighth),           // ラ (8分)
        Note(.C5, .eighth),           // ド (8分)
        Note(.B4, .dottedEighth),     // シ (付点8分)
        Note(.G4, .sixteenth),        // ソ (16分)
        Note(.C5, .eighth),           // ド (8分)
        Note(.D5, .eighth),           // レ (8分)
        Note(.C5, .quarter),          // ド (4分)

        // === 3小節目 ===
        Note(.B4, .quarter),          // シ (4分)
        Note(.A4, .eighth),           // ラ (8分)
        Note(.B4, .eighth),           // シ (8分)
        Note(.A4, .quarter),          // ラ (4分)

        // === 4小節目 ===
        Note(.G4, .quarter),          // ソ (4分)
        Note(.E4, .half),             // ミ (2分)

        // === 5小節目 ===
        Note(.E4, .eighth),           // ミ (8分)
        Note(.G4, .eighth),           // ソ (8分)
        Note(.A4, .quarter),          // ラ (4分)

        // === 6小節目 ===
        Note(.A4, .eighth),           // ラ (8分)
        Note(.C5, .eighth),           // ド (8分)
        Note(.B4, .dottedEighth),     // シ (付点8分)
        Note(.G4, .sixteenth),        // ソ (16分)
        Note(.C5, .eighth),           // ド (8分)
        Note(.D5, .eighth),           // レ (8分)
        Note(.E5, .quarter),          // ミ (4分)

        // === 7小節目 ===
        Note(.E5, .quarter),          // ミ (4分)
        Note(.E5, .eighth),           // ミ (8分)
        Note(.D5, .eighth),           // レ (8分)
        Note(.C5, .quarter),          // ド (4分)
        Note(.D5, .quarter),          // レ (4分)
        Note(.C5, .half),             // ド (2分)

        // === 8小節目 ===
        Note(.G5, .eighth),           // ソ (8分) 上
        Note(.E5, .eighth),           // ミ (8分) 上
        Note(.D5, .quarter),          // レ (4分) 上

        // === 9小節目 ===
        Note(.D5, .quarter),          // レ (4分) 上
        Note(.C5, .eighth),           // ド (8分)
        Note(.E5, .eighth),           // ミ (8分) 上
        Note(.D5, .quarter),          // レ (4分) 上
        Note(.G4, .quarter),          // ソ (4分) 下

        // === 10小節目 ===
        Note(.G5, .eighth),           // ソ (8分) 上
        Note(.E5, .eighth),           // ミ (8分) 上
        Note(.D5, .quarter),          // レ (4分) 上

        // === 11小節目 ===
        Note(.D5, .quarter),          // レ (4分) 上
        Note(.E5, .eighth),           // ミ (8分) 上
        Note(.G5, .eighth),           // ソ (8分) 上
        Note(.A5, .half),             // ラ (2分) 上

        // === 12小節目 ===
        Note(.A5, .eighth),           // ラ (8分) 上
        Note(.B5, .eighth),           // シ (8分) 上
        Note(.C6, .quarter),          // ド (4分) 上
        Note(.B5, .quarter),          // シ (4分) 上

        // === 13小節目 ===
        Note(.A5, .quarter),          // ラ (4分) 上
        Note(.G5, .quarter),          // ソ (4分) 上
        Note(.C6, .quarter),          // ド (4分) 上
        Note(.E5, .quarter),          // ミ (4分) 上

        // === 14小節目 ===
        Note(.D5, .eighth),           // レ (8分) 上
        Note(.C5, .eighth),           // ド (8分) 上
        Note(.D5, .quarter),          // レ (4分) 上
        Note(.E5, .quarter),          // ミ (4分) 上

        // === 15小節目 ===
        Note(.G5, .half),             // ソ (2分) 上
        Note(.E5, .quarter),          // ミ (4分) - 終止へ

        // === 終止 ===
        Note(.C5, .dottedHalf)        // ド (付点2分)
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

    // MARK: - Cathedral Organ Stops (Layered Voices)

    /// 16' Principal (Sub-octave): Deep foundation, one octave below
    /// Creates the gravitas and depth of a cathedral organ
    let subOctaveRatio: Float = 0.5    // freq * 0.5 = one octave down
    let subOctaveGain: Float = 0.4     // Strong but not overpowering

    /// Quint (2-2/3'): Fifth above, adds brilliance and richness
    /// Classic organ stop for majestic sound
    let quintRatio: Float = 1.5        // freq * 1.5 = perfect fifth above
    let quintGain: Float = 0.15        // Subtle, blends into the sound

    /// 4' Octave: One octave above for clarity and presence
    let octaveAboveRatio: Float = 2.0  // freq * 2.0 = one octave up
    let octaveAboveGain: Float = 0.2   // Moderate, adds brightness

    /// Legato Envelope Parameters (smooth, connected notes)
    /// - Attack: Gentle rise for smooth entry
    /// - Release: Extends beyond note boundary for overlap
    let attackTime: Float = 0.12   // 120ms: smooth but not sluggish
    let releaseTime: Float = 0.5   // 500ms: long tail for legato overlap

    /// Legato overlap: how much the release extends into next note
    /// This creates smooth connections between notes
    let legatoOverlap: Float = 0.35  // 350ms overlap with next note

    /// Master gain for balance with other layers
    let masterGain: Float = 0.22  // Reduced to compensate for added voices

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)

        var totalSignal: Float = 0.0

        // Find current note and potentially overlapping previous note
        if let index = findNoteIndex(at: cycleTime) {
            let note = melody[index]
            let noteStartTime = cumulativeTimes[index]
            let localTime = cycleTime - noteStartTime

            // Current note with legato envelope
            let envelope = calculateLegatoEnvelope(time: localTime, duration: note.duration)
            totalSignal += generateTone(freq: note.freq, t: t) * envelope

            // Check if previous note is still releasing (legato overlap)
            if index > 0 && localTime < legatoOverlap {
                let prevNote = melody[index - 1]
                let prevDuration = prevNote.duration
                let timeIntoRelease = prevDuration + localTime  // time since prev note started

                let prevEnvelope = calculateLegatoEnvelope(time: timeIntoRelease, duration: prevDuration)
                if prevEnvelope > 0 {
                    totalSignal += generateTone(freq: prevNote.freq, t: t) * prevEnvelope
                }
            }
        }

        return totalSignal * masterGain
    }

    /// Generate cathedral organ tone with layered voices (stops)
    /// Combines: 8' Principal (main) + 16' Sub-octave + Quint + 4' Octave
    private func generateTone(freq: Float, t: Float) -> Float {
        // 8' Principal: Main melody voice
        let mainTone = generateSingleVoice(freq: freq, t: t)

        // 16' Principal: Sub-octave for depth and gravitas
        let subOctaveTone = generateSingleVoice(freq: freq * subOctaveRatio, t: t) * subOctaveGain

        // Quint (2-2/3'): Perfect fifth for richness
        let quintTone = generateSingleVoice(freq: freq * quintRatio, t: t) * quintGain

        // 4' Octave: Octave above for clarity
        let octaveAboveTone = generateSingleVoice(freq: freq * octaveAboveRatio, t: t) * octaveAboveGain

        // Blend all voices
        return mainTone + subOctaveTone + quintTone + octaveAboveTone
    }

    /// Generate a single organ voice with harmonics
    private func generateSingleVoice(freq: Float, t: Float) -> Float {
        var signal: Float = 0.0
        for i in 0..<harmonics.count {
            let hFreq = freq * harmonics[i]
            let phase = 2.0 * Float.pi * hFreq * t
            signal += sin(phase) * harmonicAmps[i]
        }
        // Normalize
        signal /= Float(harmonics.count)
        return signal
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

    /// Generates a smooth legato envelope with cosine interpolation
    /// Release extends beyond note boundary for smooth overlap
    ///
    /// Shape (with overlap):
    /// ```
    /// 1.0     ╭───────────────╮
    ///        ╱                 ╲
    ///       ╱                   ╲  (extends into next note)
    /// 0.0 ─╯                     ╲─────
    ///     0   attack    release-start   release-end
    /// ```
    private func calculateLegatoEnvelope(time: Float, duration: Float) -> Float {
        let releaseStart = duration - legatoOverlap
        let totalReleaseDuration = legatoOverlap + releaseTime

        // Attack Phase: smooth cosine rise
        if time < attackTime {
            let progress = time / attackTime
            // Cosine interpolation: smoother than linear
            return (1.0 - cos(progress * Float.pi)) * 0.5
        }
        // Release Phase: starts before note ends, extends beyond
        else if time > releaseStart {
            let timeInRelease = time - releaseStart
            let releaseProgress = min(timeInRelease / totalReleaseDuration, 1.0)
            // Cosine interpolation for smooth fade
            return (1.0 + cos(releaseProgress * Float.pi)) * 0.5
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
