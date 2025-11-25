//
//  MoonlightFlowSignal.swift
//  clock-tsukiusagi
//
//  Moonlight Flow - Impressionist-inspired original melody in Db Major
//  Single-note sequential melody with soft, dreamy character
//

import Foundation

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
        let freq: Float
        let duration: Float
    }

    // MARK: - Melody Definition

    /// Original melody in D♭ Major (from todo.md specification)
    /// Total duration: ~9.8 seconds
    let melody: [Note] = [
        Note(freq: 277.18, duration: 0.6),  // Db4
        Note(freq: 349.23, duration: 0.6),  // F4
        Note(freq: 415.30, duration: 0.6),  // Ab4
        Note(freq: 349.23, duration: 0.6),  // F4
        Note(freq: 311.13, duration: 0.6),  // Eb4
        Note(freq: 369.99, duration: 0.6),  // Gb4
        Note(freq: 554.37, duration: 0.8),  // Db5 (longer)
        Note(freq: 523.25, duration: 0.6),  // C5
        Note(freq: 349.23, duration: 0.6),  // F4
        Note(freq: 415.30, duration: 0.6),  // Ab4
        Note(freq: 554.37, duration: 0.8),  // Db5 (longer)
        Note(freq: 415.30, duration: 0.6),  // Ab4
        Note(freq: 369.99, duration: 0.6),  // Gb4
        Note(freq: 311.13, duration: 0.6),  // Eb4
        Note(freq: 277.18, duration: 0.8)   // Db4 (final, longer)
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

    let attack: Float = 0.030      // 30ms: gentle, smooth attack
    let decay: Float = 2.0         // 2.0s: long decay for moonlight shimmer

    // MARK: - Harmonic Structure

    /// Harmonics: fundamental + 2 overtones
    let harmonics: [Float] = [1.0, 2.0, 3.0]

    /// Harmonic amplitudes: softer than toy piano for transparent quality
    let harmonicAmps: [Float] = [1.0, 0.30, 0.12]  // Fundamental dominant, soft overtones

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

        // Return with soft, moonlight-like volume (0.30)
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
