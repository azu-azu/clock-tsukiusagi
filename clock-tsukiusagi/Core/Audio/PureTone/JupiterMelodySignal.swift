//
//  JupiterMelodySignal.swift
//  clock-tsukiusagi
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

    /// Jupiter melody in C Major (transposed from E Major, -4 semitones)
    ///
    /// Original (E Major):
    /// E4  B3  G#4  C#5  B4  A4  G#4
    /// F#4 A3  A4   C#5  B4  A4  F#4
    ///
    /// Transposed to C Major:
    /// C4  G3  E4   A4   G4  F4  E4
    /// D4  F3  F4   A4   G4  F4  D4
    ///
    /// Total duration: ~9.6 seconds
    let melody: [Note] = [
        // First phrase (荘厳な上昇)
        Note(freq: 261.63, duration: 0.8),  // C4 (long)
        Note(freq: 196.00, duration: 0.6),  // G3
        Note(freq: 329.63, duration: 0.6),  // E4
        Note(freq: 440.00, duration: 0.8),  // A4 (long)
        Note(freq: 392.00, duration: 0.6),  // G4
        Note(freq: 349.23, duration: 0.6),  // F4
        Note(freq: 329.63, duration: 0.8),  // E4 (long)

        // Second phrase (呼応する下降)
        Note(freq: 293.66, duration: 0.8),  // D4 (long)
        Note(freq: 174.61, duration: 0.6),  // F3
        Note(freq: 349.23, duration: 0.6),  // F4
        Note(freq: 440.00, duration: 0.8),  // A4 (long)
        Note(freq: 392.00, duration: 0.6),  // G4
        Note(freq: 349.23, duration: 0.6),  // F4
        Note(freq: 293.66, duration: 0.8)   // D4 (final, long)
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

    let attack: Float = 0.050      // 50ms: organ-like soft attack
    let decay: Float = 3.0         // 3.0s: long decay for cathedral space

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

        // Return with moderate volume (0.35) for melody prominence
        return normalized * envelope * 0.35
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
// Source: Holst's "The Planets" - Jupiter (1918, public domain)
// Original Key: E Major
// Transposed: C Major (to match CathedralStillness C/G drone)
// Phrasing: Two phrases - ascending majesty, responding descent
// Duration: Variable (0.6s and 0.8s) for expressive, natural flow
//
// SOUND CHARACTER:
//
// - Organ-style harmonics (45%, 30%, 18%) for rich, majestic tone
// - Long decay (3.0s) for cathedral reverb compatibility
// - Moderate attack (50ms) for organ-like articulation
// - Moderate volume (0.35) for melody prominence in the mix
//
// TECHNICAL IMPLEMENTATION:
//
// - Uses Signal protocol (pure time-based function)
// - Cumulative time array for efficient note lookup
// - Per-note envelope (independent attack/decay)
// - 14-note cycle, ~9.6 second loop
//
// INTEGRATION WITH CATHEDRALSTILLNESS:
//
// Layer architecture:
// 1. Organ drone (C3 + G3, 0.02Hz LFO) - foundation
// 2. Harp arpeggios (MidnightDroplets) - sparse decoration
// 3. Jupiter melody (this) - majestic centerpiece
//
// All layers share the same large reverb (Cathedral atmosphere, 3s decay).
//
// COPYRIGHT:
//
// Gustav Holst died in 1934. Under Japanese copyright law (70 years after death),
// "The Planets" entered public domain in 2004. Using the melody is completely legal.
// This implementation synthesizes the melody from scratch (no existing recordings used).
