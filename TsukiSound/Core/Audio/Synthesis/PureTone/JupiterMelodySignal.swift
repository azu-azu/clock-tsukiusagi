//
//  JupiterMelodySignal.swift
//  TsukiSound
//
//  Jupiter Melody - Holst's "The Planets" Jupiter theme in C Major
//  Organ-style melody with rich harmonics for cathedral atmosphere
//

import Foundation

/// JupiterMelodySignal - Holst's Jupiter theme adapted for organ
///
/// Produces a majestic, solemn melody based on Holst's "Jupiter" (public domain).
/// Transposed from E Major to C Major to harmonize with CathedralStillness drone (C/G).
///
/// Characteristics:
/// - Organ-style melody with rich harmonics
/// - C Major key (transposed from original E Major)
/// - Variable duration (0.6s and 0.8s notes) for expressive phrasing
/// - Long decay (3.0s) for cathedral reverb compatibility
/// - Cycle: 14 notes, ~9.6 seconds total
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

    // MARK: - Data Structures

    /// Single note with frequency and duration
    struct Note {
        let freq: Float
        let duration: Float
    }

    // MARK: - Melody Definition

    /// Jupiter chorale melody in C major (Holst "Thaxted" opening 3 measures)
    ///
    /// Based on Holst's own C-major setting of the Jupiter chorale
    /// ("Thaxted" / "I Vow to Thee, My Country" first 3 measures),
    /// arranged to sit over CathedralStillness (C/G drone).
    ///
    /// Extended to full 3-measure phrase for complete musical statement.
    /// Measure 1: Introduction (ascent)
    /// Measure 2: First response (gentle descent)
    /// Measure 3: Climax (secondary ascent — the emotional peak)
    ///
    /// Notation (in C major, 3/4):
    /// Measure 1: e8( g) a4. c8  b8. g16  c8( d) c4  b4  a8 b  a4  g4
    /// Measure 2: c8 d e4 d8 c b a g
    /// Measure 3: e8 g a4 c8 d8 c b a g (with extended final G for loop smoothing)
    ///
    /// Total duration: ~52-54 seconds (2x slower, 3-measure complete phrase)
    let melody: [Note] = [
        // === Measure 1 ===
        Note(freq: 329.63, duration: 0.80), // E4 - eighth (2x)
        Note(freq: 392.00, duration: 0.80), // G4 - eighth (2x)
        Note(freq: 440.00, duration: 2.40), // A4 - dotted quarter (2x)
        Note(freq: 523.25, duration: 0.80), // C5 - eighth (2x)
        Note(freq: 493.88, duration: 1.20), // B4 - dotted eighth (2x)
        Note(freq: 392.00, duration: 0.40), // G4 - sixteenth (2x)
        Note(freq: 523.25, duration: 0.80), // C5 - eighth (2x)
        Note(freq: 587.33, duration: 0.80), // D5 - eighth (2x)
        Note(freq: 523.25, duration: 1.60), // C5 - quarter (2x)
        Note(freq: 493.88, duration: 1.60), // B4 - quarter (2x)
        Note(freq: 440.00, duration: 0.80), // A4 - eighth (2x)
        Note(freq: 493.88, duration: 0.80), // B4 - eighth (2x)
        Note(freq: 440.00, duration: 1.60), // A4 - quarter (2x)
        Note(freq: 392.00, duration: 1.60), // G4 - quarter (2x)

        // === Measure 2 ===
        Note(freq: 523.25, duration: 0.80), // C5 - eighth (2x)
        Note(freq: 587.33, duration: 0.80), // D5 - eighth (2x)
        Note(freq: 659.25, duration: 1.60), // E5 - quarter (2x)
        Note(freq: 587.33, duration: 0.80), // D5 - eighth (2x)
        Note(freq: 523.25, duration: 0.80), // C5 - eighth (2x)
        Note(freq: 493.88, duration: 0.80), // B4 - eighth (2x)
        Note(freq: 440.00, duration: 0.80), // A4 - eighth (2x)
        Note(freq: 392.00, duration: 0.80), // G4 - eighth (2x)

        // === Measure 3 (Climax — the emotional peak) ===
        Note(freq: 329.63, duration: 0.80), // E4 - eighth (2x)
        Note(freq: 392.00, duration: 0.80), // G4 - eighth (2x)
        Note(freq: 440.00, duration: 1.60), // A4 - quarter (2x)
        Note(freq: 523.25, duration: 0.80), // C5 - eighth (2x)
        Note(freq: 587.33, duration: 0.80), // D5 - eighth (2x)
        Note(freq: 523.25, duration: 0.80), // C5 - eighth (2x)
        Note(freq: 493.88, duration: 0.80), // B4 - eighth (2x)
        Note(freq: 440.00, duration: 0.80), // A4 - eighth (2x)
        Note(freq: 392.00, duration: 1.80)  // G4 - extended for smooth loop transition (2x + extra)
    ]

    // MARK: - Timing Calculations

    /// Cumulative times for efficient note indexing
    /// Example: [0.0, 0.8, 1.4, 2.0, ..., 9.6]
    lazy var cumulativeTimes: [Float] = {
        var times: [Float] = [0.0]
        for note in melody {
            times.append(times.last! + note.duration)
        }
        return times
    }()

    /// Total cycle duration
    lazy var cycleDuration: Float = {
        cumulativeTimes.last!
    }()

    // MARK: - Envelope Parameters

    let attack: Float = 0.080      // 80ms: slower, more majestic organ attack
    let decay: Float = 4.0         // 4.0s: extended decay for cathedral grandeur

    // MARK: - Harmonic Structure

    /// Organ-style harmonics: fundamental + 3 overtones
    /// Rich harmonic content for majestic character
    let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0]

    /// Harmonic amplitudes: organ-like (fundamental strong, rich overtones)
    let harmonicAmps: [Float] = [1.0, 0.45, 0.30, 0.18]

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        // Get time within current cycle
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)

        // Find which note is currently playing
        guard let noteIndex = findNoteIndex(at: cycleTime) else {
            return 0.0
        }

        let note = melody[noteIndex]
        let noteStartTime = cumulativeTimes[noteIndex]
        let timeSinceNoteStart = cycleTime - noteStartTime

        // Calculate envelope for this note
        let envelope = calculateEnvelope(timeSinceNoteStart)

        // Generate harmonic content
        var value: Float = 0.0
        for h in 0..<harmonics.count {
            let freq = note.freq * harmonics[h]
            let phase = 2.0 * Float.pi * freq * t
            value += sin(phase) * harmonicAmps[h]
        }

        // Normalize by harmonic count and apply envelope
        let normalized = value / Float(harmonics.count)

        // Return with softer volume (0.30) for meditative, majestic character
        return normalized * envelope * 0.30
    }

    // MARK: - Helper Methods

    /// Find index of note playing at given time
    /// - Parameter time: Time within cycle
    /// - Returns: Note index, or nil if out of bounds
    private func findNoteIndex(at time: Float) -> Int? {
        for i in 0..<melody.count {
            if time >= cumulativeTimes[i] && time < cumulativeTimes[i + 1] {
                return i
            }
        }
        return nil
    }

    /// Calculate envelope for note
    /// - Parameter t: Time since note start
    /// - Returns: Envelope value (0.0-1.0)
    private func calculateEnvelope(_ t: Float) -> Float {
        if t < attack {
            // Attack phase: smooth rise using sine curve
            let progress = t / attack
            let sinValue = sin(progress * Float.pi / 2.0)
            return sinValue * sinValue  // sin^2 for smooth curve
        } else {
            // Decay phase: exponential decay
            let decayTime = t - attack
            return exp(-decayTime / decay)
        }
    }
}

// MARK: - Design Notes
//
// MELODY DESIGN:
//
// Source: Holst's "Thaxted" chorale from Jupiter (1918, public domain)
// Also known as: "I Vow to Thee, My Country" hymn tune
// Key: C Major (Holst's own C-major setting, fits CathedralStillness C/G drone)
// Time Signature: 3/4 (mapped to seconds: 0.4s = eighth note)
// Phrasing: First 2 measures of the famous Jupiter chorale (complete opening phrase)
// Duration: Variable note lengths (0.2s to 1.2s) for expressive, natural flow
//
// DESIGN PHILOSOPHY:
//
// Extended from 1 measure to 3 measures, and slowed 2x to:
// - Reduce loop perception (52-54s cycle vs 9s original)
// - Create complete musical phrase with emotional arc:
//   * Measure 1: Ascending introduction
//   * Measure 2: Gentle descent (first response)
//   * Measure 3: Secondary ascent (emotional climax — the "big tune" moment)
// - Match Calm Technology philosophy (very slow, breathing, cosmic rhythm)
// - Better fit CathedralStillness atmosphere (long, deeply meditative cycles)
// - Enhance majestic, solemn character through slower tempo
// - Provide satisfying musical completeness and resolution
//
// REFERENCE:
//
// This is the same melody used in:
// - Ayaka Hirahara's "Jupiter" (everyday I listen to my heart~)
// - Traditional hymn "I Vow to Thee, My Country"
// - The famous "big tune" from Holst's Jupiter movement
//
// SOUND CHARACTER:
//
// - Organ-style harmonics (45%, 30%, 18%) for rich, majestic tone
// - Extended decay (4.0s) for cathedral grandeur and spaciousness
// - Slower attack (80ms) for majestic, solemn organ articulation
// - Softer volume (0.30) for meditative, reverent atmosphere
//
// TECHNICAL IMPLEMENTATION:
//
// - Uses Signal protocol (pure time-based function)
// - Cumulative time array for efficient note lookup
// - Per-note envelope (independent attack/decay)
// - 31-note cycle, ~52-54 second loop (3 measures, 2x slower)
// - Final note (G4) extended (1.8s) to smooth loop transition
//
// INTEGRATION WITH CATHEDRALSTILLNESS:
//
// Layer architecture:
// 1. Organ drone (C3 + G3, 0.02Hz LFO) - foundation
// 2. Harp arpeggios (MidnightDroplets) - sparse decoration
// 3. Jupiter chorale (this) - majestic centerpiece
//
// All layers share the same large reverb (Cathedral atmosphere, 3s decay).
//
// LOOP HIDING TECHNIQUE:
//
// - 3-measure phrase creates complete musical arc with climax
// - Final G4 extended to 1.8s (vs standard 0.8s eighth note)
// - Extremely long cycle (52-54s) makes loop virtually imperceptible
// - Reverb tail (4s decay) smooths transition between cycles
// - Slow tempo creates timeless, meditative quality
// - Measure 3 provides emotional resolution before loop restart
//
// COPYRIGHT:
//
// Gustav Holst died in 1934. Under Japanese copyright law (70 years after death),
// "The Planets" entered public domain in 2004. Using the melody is completely legal.
// This implementation synthesizes the melody from scratch (no existing recordings used).
