//
//  MoonlightFlowMidnightSignal.swift
//  TsukiSound
//
//  Midnight version of Moonlight Flow — darker, slower, deeper
//  Key: B♭ Minor (darker mood than D♭ Major)
//  Character: Quiet night at 2AM, solitary, mysterious
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

/// MoonlightFlowMidnightSignal - Midnight version with darker atmosphere
///
/// Deep night variation of Moonlight Flow in B♭ Minor
/// Features longer silences, lower pitch range, and darker harmonics
///
/// Characteristics:
/// - B♭ Minor key (darker than D♭ Major)
/// - 12 notes (vs 15 in normal version)
/// - Lower range: Bb2 (116Hz) ~ F4 (349Hz)
/// - Darker harmonics: [1.0, 0.20, 0.08]
/// - 15% omission rate (vs 10%)
/// - Longer envelope: 40ms attack, 2.4s decay
/// - Cycle: ~10.8 seconds
public struct MoonlightFlowMidnightSignal {

    /// Create midnight moonlight signal
    /// - Returns: Signal generating the midnight melody
    public static func makeSignal() -> Signal {
        let generator = MidnightGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

// MARK: - Private Implementation

private final class MidnightGenerator {

    // MARK: - Data Structures

    struct Note {
        var freq: Float
        var duration: Float
    }

    // MARK: - Melody Definition

    /// Midnight melody in B♭ Minor
    /// Total duration: ~21.6 seconds (2x slower tempo)
    /// Descending motion for deep night feeling
    let melody: [Note] = [
        Note(freq: 233.08, duration: 1.6), // Bb3
        Note(freq: 277.18, duration: 1.2), // Db4
        Note(freq: 174.61, duration: 1.6), // F3
        Note(freq: 207.65, duration: 1.2), // Ab3
        Note(freq: 261.63, duration: 1.6), // C4
        Note(freq: 349.23, duration: 1.2), // F4
        Note(freq: 311.13, duration: 1.6), // Eb4
        Note(freq: 233.08, duration: 1.2), // Bb3
        Note(freq: 277.18, duration: 1.6), // Db4
        Note(freq: 261.63, duration: 1.2), // C4
        Note(freq: 207.65, duration: 1.6), // Ab3
        Note(freq: 116.54, duration: 2.0)  // Bb2 (deep ending)
    ]

    // MARK: - Timing Calculations

    /// Cumulative times for efficient note indexing
    lazy var cumulativeTimes: [Float] = {
        var times: [Float] = [0.0]
        for note in melody {
            times.append(times.last! + note.duration)
        }
        return times
    }()

    /// Total cycle duration
    lazy var cycleDuration: Float = cumulativeTimes.last!

    // MARK: - Envelope Parameters

    let attack: Float = 0.080      // 80ms: slow, deep midnight attack
    let decay: Float = 4.5         // 4.5s: very long decay for deep night resonance

    // MARK: - Harmonic Structure

    /// Harmonics: fundamental + 3 overtones for richer, deeper sound
    let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0]

    /// Rich but dark harmonic amplitudes - deeper than normal version
    let harmonicAmps: [Float] = [1.0, 0.50, 0.30, 0.15]  // Rich yet dark

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)
        guard let index = findNoteIndex(at: cycleTime) else { return 0.0 }

        var note = melody[index]
        let noteStart = cumulativeTimes[index]
        let dt = cycleTime - noteStart

        // Midnight random system (clouds at night)
        var rng = SeededRandomNumberGenerator(seed: UInt64(index + 2000))

        // 15% omission (higher than normal 10%)
        if rng.nextFloat() < 0.15 {
            return 0.0
        }

        // Octave shift down only (10%) - for deeper night feeling
        if rng.nextFloat() < 0.10 {
            note.freq *= 0.5  // 1 octave down
        }

        // Duration wobble
        let wobble = (rng.nextFloat() - 0.5) * 0.32  // ±0.16s (scaled for 2x tempo)
        let envelope = calculateEnvelope(dt + wobble)

        // Harmonic synthesis
        var value: Float = 0.0
        for h in 0..<harmonics.count {
            let freq = note.freq * harmonics[h]
            let phase = 2.0 * Float.pi * freq * t
            value += sin(phase) * harmonicAmps[h]
        }

        // Normalize and apply envelope with deeper midnight volume (0.36)
        let normalized = value / Float(harmonics.count)
        return normalized * envelope * 0.36
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
// MIDNIGHT CONCEPT:
//
// "月明かり"ではなく"月の影"を描く
// "Moonlight shadow" instead of "moonlight"
// Deep night at 2AM - quiet, solitary, mysterious
//
// MELODY DESIGN:
//
// Key: B♭ Minor (relative minor of D♭ Major)
// Range: Bb2 (116Hz) ~ F4 (349Hz) - lower than normal version
// Notes: 12 (vs 15) - more space, more silence
// Phrasing: Descending motion for settling-down feeling
//
// SOUND CHARACTER:
//
// - Darker harmonics (20%, 8%) vs normal (30%, 12%)
// - Longer decay (2.4s) vs normal (2.0s)
// - Slightly longer attack (40ms) vs normal (30ms)
// - Higher omission rate (15%) vs normal (10%)
// - Octave shift down only (no upward shifts)
// - Lower volume (0.28) for midnight quietness
//
// REVERB RECOMMENDATION:
//
// Use close, foggy reverb:
// - predelay: 0.010 (10ms - dense fog, close feeling)
// - roomSize: 2.0 (large space)
// - decay: 0.90 (long tail)
// - mix: 0.55 (rich presence)
//
// This creates "thick fog in a quiet alley" atmosphere.
//
// DIFFERENCE FROM NORMAL VERSION:
//
// Normal (Flow):       Midnight:
// - D♭ Major          - B♭ Minor
// - 15 notes          - 12 notes
// - Db3~Db5 range     - Bb2~F4 range
// - 10% omission      - 15% omission
// - Bidirectional     - Down only octave shift
// - 30ms predelay     - 10ms predelay
// - "Gentle moonlight" - "Dark moon shadow"
