//
//  MoonlightFlowSignal.swift
//  TsukiSound
//
//  Moonlight Flow - Impressionist-inspired original melody in Db Major
//  Single-note sequential melody with soft, dreamy character
//  Features subtle random variations like clouds moving across the moon
//

import Foundation

// MARK: - Seeded Random Number Generator

/// Simple Linear Congruential Generator for reproducible randomness
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // LCG parameters (from Numerical Recipes)
        state = state &* 1664525 &+ 1013904223
        return state
    }

    /// Generate random Float in 0.0...1.0
    mutating func nextFloat() -> Float {
        Float(next() & 0xFFFFFF) / Float(0x1000000)
    }
}

/// MoonlightFlowSignal - Impressionist-style melody generator
///
/// Produces a gentle, flowing melody inspired by impressionist music.
/// Uses D♭ Major scale with variable note durations for natural phrasing.
///
/// Characteristics:
/// - Single-note melody (sequential, not chords)
/// - Variable duration (0.6s and 0.8s notes)
/// - Soft harmonics for transparent, moonlight-like quality
/// - Long decay (2.0s) for shimmering sustain
/// - Cycle: 15 notes, ~9.8 seconds total
public struct MoonlightFlowSignal {

    /// Create moonlight flow signal
    /// - Returns: Signal generating the moonlight melody
    public static func makeSignal() -> Signal {
        let generator = MoonlightFlowGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

// MARK: - Private Implementation

private final class MoonlightFlowGenerator {

    // MARK: - Data Structures

    /// Single note with frequency and duration
    struct Note {
        var freq: Float
        var duration: Float
    }

    // MARK: - Melody Definition

    /// Original melody in D♭ Major with added low notes for depth
    /// Total duration: ~19.6 seconds (2x slower tempo)
    /// Low notes (Db3, Ab3) added at positions 0, 3, 9, 13 for spatial depth
    let melody: [Note] = [
        Note(freq: 138.59, duration: 1.2),  // Db3 (low root - spatial depth)
        Note(freq: 349.23, duration: 1.2),  // F4
        Note(freq: 415.30, duration: 1.2),  // Ab4
        Note(freq: 207.65, duration: 1.2),  // Ab3 (low fifth - stability)
        Note(freq: 311.13, duration: 1.2),  // Eb4
        Note(freq: 369.99, duration: 1.2),  // Gb4
        Note(freq: 554.37, duration: 1.6),  // Db5 (longer)
        Note(freq: 523.25, duration: 1.2),  // C5
        Note(freq: 349.23, duration: 1.2),  // F4
        Note(freq: 207.65, duration: 1.2),  // Ab3 (low fifth - mid-phrase depth)
        Note(freq: 554.37, duration: 1.6),  // Db5 (longer)
        Note(freq: 415.30, duration: 1.2),  // Ab4
        Note(freq: 369.99, duration: 1.2),  // Gb4
        Note(freq: 138.59, duration: 1.2),  // Db3 (low root - pre-ending emphasis)
        Note(freq: 277.18, duration: 1.6)   // Db4 (final, longer)
    ]

    // MARK: - Timing Calculations

    /// Cumulative times for efficient note indexing
    /// Example: [0.0, 0.6, 1.2, 1.8, ..., 9.8]
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

    let attack: Float = 0.070      // 70ms: slow, majestic attack
    let decay: Float = 4.0         // 4.0s: cathedral-like long decay

    // MARK: - Harmonic Structure

    /// Harmonics: fundamental + 3 overtones for richer sound
    let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0]

    /// Harmonic amplitudes: richer, deeper, heavier sound
    let harmonicAmps: [Float] = [1.0, 0.55, 0.35, 0.20]  // Stronger harmonics for weight

    // MARK: - Random Variation State

    /// Cache for varied melody per cycle
    private var currentCycle: Int = -1
    private var variedMelody: [Note] = []

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        // Get time within current cycle
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)
        let cycleIndex = Int(t / cycleDuration)

        // Generate varied melody for this cycle if needed
        if cycleIndex != currentCycle {
            variedMelody = generateVariedMelody(forCycle: cycleIndex)
            currentCycle = cycleIndex
        }

        // Find which note is currently playing (use varied melody)
        guard let noteIndex = findNoteIndex(at: cycleTime) else {
            return 0.0
        }

        let note = variedMelody[noteIndex]
        let noteStartTime = cumulativeTimes[noteIndex]
        let timeSinceNoteStart = cycleTime - noteStartTime

        // Handle silence (cloud covering moon)
        if note.freq == 0.0 {
            return 0.0
        }

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

        // Return with deeper, richer volume (0.38)
        return normalized * envelope * 0.38
    }

    // MARK: - Helper Methods

    /// Generate varied melody for a specific cycle with subtle random changes
    /// - Parameter cycle: Cycle index for seeding randomness
    /// - Returns: Melody with subtle variations (like clouds moving across moon)
    private func generateVariedMelody(forCycle cycle: Int) -> [Note] {
        var rng = SeededRandomNumberGenerator(seed: UInt64(cycle + 1000))
        var varied: [Note] = []

        for baseNote in melody {
            var note = baseNote

            // 1. Octave shift (20% probability)
            if rng.nextFloat() < 0.2 {
                let shiftUp = rng.nextFloat() < 0.5
                note.freq *= shiftUp ? 2.0 : 0.5  // 1 octave up or down
            }

            // 2. Note omission (10% probability) - cloud covering moon
            if rng.nextFloat() < 0.1 {
                note.freq = 0.0  // Silence
            }

            // 3. Duration micro-adjustment (30% probability)
            if rng.nextFloat() < 0.3 {
                let adjustment = (rng.nextFloat() - 0.5) * 0.4  // ±0.2s (scaled for 2x tempo)
                note.duration = max(0.8, note.duration + adjustment)
            }

            varied.append(note)
        }

        return varied
    }

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
// Key: D♭ Major (same as Debussy's Clair de Lune for transparency)
// Scale: Db, Eb, F, Gb, Ab, C (pentatonic-ish, avoiding harsh intervals)
// Phrasing: Gentle rise and fall, no large leaps
// Duration: Variable (0.6s and 0.8s) for natural, expressive phrasing
//
// SOUND CHARACTER:
//
// - Soft harmonics (30%, 12%) vs toy piano (35%, 15%)
// - Long decay (2.0s) for shimmer and sustain
// - Gentle attack (30ms) for smooth note transitions
// - Low volume (0.30) for ambient, meditative quality
//
// TECHNICAL IMPLEMENTATION:
//
// - Uses Signal protocol (pure time-based function)
// - Cumulative time array for efficient note lookup
// - Per-note envelope (independent attack/decay)
// - 15-note cycle, ~9.8 second loop
//
// REVERB RECOMMENDATION:
//
// Use large, spacious reverb (Cathedral-like):
// - roomSize: 2.0 (large space)
// - decay: 0.90 (very long tail)
// - mix: 0.55 (rich reverb presence)
//
// This creates the "moonlight atmosphere" effect.
