//
//  SubPianoSignal.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-24.
//  SubPiano — octave-up soft piano layer for shimmer and depth
//

import Foundation

/// SubPiano — octave-up soft piano layer
///
/// Adds shimmer and sparkle to the main Toy Piano without changing harmony:
/// - 1 octave higher than main piano (C5-G5 instead of C3-G3)
/// - 20% volume (subtle shimmer layer)
/// - Super-fast attack (5ms) with no hammer feel
/// - Fewer harmonics for transparency
/// - Like a "music box shadow" layer
///
/// Same chord progression as main: C → Am → F → G (8-second cycle)
/// Creates "glass box music box" or "piano in dreamy lace" atmosphere
public struct SubPianoSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {
        let generator = SubPianoGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

private final class SubPianoGenerator {

    // Same chord progression as main Toy Piano, but 1 octave up
    struct Chord {
        let frequencies: [Float]  // 3-note triad
        let name: String
    }

    let chords: [Chord] = [
        Chord(frequencies: [523.25, 659.25, 784.00], name: "C"),   // C major (C5-E5-G5)
        Chord(frequencies: [440.00, 523.25, 659.25], name: "Am"),  // A minor (A4-C5-E5)
        Chord(frequencies: [698.46, 880.00, 1046.50], name: "F"),  // F major (F5-A5-C6)
        Chord(frequencies: [784.00, 987.77, 1174.66], name: "G")   // G major (G5-B5-D6)
    ]

    // Timing parameters (same as main)
    let chordDuration: Float = 2.0      // Each chord lasts 2 seconds
    let cycleDuration: Float = 8.0      // Full progression: 8 seconds

    // Envelope parameters (faster attack, shorter decay)
    let attack: Float = 0.005           // 5ms super-fast attack (no hammer feel)
    let decay: Float = 1.2              // 1.2s shorter decay (lighter than main's 1.5s)

    // Harmonic structure (fewer harmonics for transparency)
    let harmonics: [Float] = [1.0, 2.0]
    let harmonicAmps: [Float] = [1.0, 0.18]  // Fundamental + subtle 2nd harmonic

    func sample(at t: Float) -> Float {
        // Determine which chord we're in
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)
        let chordIndex = Int(cycleTime / chordDuration)
        guard chordIndex < chords.count else { return 0.0 }

        let chord = chords[chordIndex]
        let timeSinceChordStart = cycleTime - Float(chordIndex) * chordDuration

        // Calculate envelope (attack + decay)
        let envelope: Float
        if timeSinceChordStart < attack {
            // Attack phase: linear fade-in
            envelope = timeSinceChordStart / attack
        } else {
            // Decay phase: exponential fade-out
            let decayTime = timeSinceChordStart - attack
            envelope = exp(-decayTime / decay)
        }

        // Generate chord with harmonics
        var chordValue: Float = 0.0

        for noteFreq in chord.frequencies {
            var noteValue: Float = 0.0

            // Add harmonics for each note
            for h in 0..<harmonics.count {
                let freq = noteFreq * harmonics[h]
                let phase = 2.0 * Float.pi * freq * t
                noteValue += sin(phase) * harmonicAmps[h]
            }

            chordValue += noteValue
        }

        // Normalize by number of notes and apply envelope
        let normalizedChord = chordValue / Float(chord.frequencies.count)

        // SUPER soft — this is just a shimmer layer (20% volume)
        return normalizedChord * envelope * 0.20
    }

    public func reset() {
        // Stateless, no reset needed
    }
}
