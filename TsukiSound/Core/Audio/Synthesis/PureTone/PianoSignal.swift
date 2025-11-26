//
//  PianoSignal.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-23.
//  Toy Piano Dream — gentle chord progression with toy piano timbre
//

import Foundation

/// Toy Piano Dream — simple, dreamy chord progression
///
/// This preset creates a warm, music-box-like toy piano sound:
/// Components:
/// - Simple chord progression: C → Am → F → G (8-second cycle)
/// - Toy piano timbre: fundamental + 2-3 harmonics
/// - Gentle attack (20ms) + long decay (1.5s) for music-box feel
/// - Deep reverb for dreamy, ambient atmosphere
///
/// Chord voicings (3-note triads):
/// - C major: C3-E3-G3 (261.63, 329.63, 392.00 Hz)
/// - A minor: A2-C3-E3 (220.00, 261.63, 329.63 Hz)
/// - F major: F3-A3-C4 (349.23, 440.00, 523.25 Hz)
/// - G major: G3-B3-D4 (392.00, 493.88, 587.33 Hz)
///
/// Timing: Each chord sustains for 2 seconds, creating a calm 8-second cycle
public struct PianoSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {
        let generator = PianoGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

private final class PianoGenerator {

    // Chord progression: C → Am → F → G
    struct Chord {
        let frequencies: [Float]  // 3-note triad
        let name: String
    }

    let chords: [Chord] = [
        Chord(frequencies: [261.63, 329.63, 392.00], name: "C"),   // C major
        Chord(frequencies: [220.00, 261.63, 329.63], name: "Am"),  // A minor
        Chord(frequencies: [349.23, 440.00, 523.25], name: "F"),   // F major
        Chord(frequencies: [392.00, 493.88, 587.33], name: "G")    // G major
    ]

    // Timing parameters
    let chordDuration: Float = 2.0      // Each chord lasts 2 seconds
    let cycleDuration: Float = 8.0      // Full progression: 8 seconds

    // Envelope parameters
    let attack: Float = 0.020           // 20ms gentle attack
    let decay: Float = 1.5              // 1.5s music-box decay

    // Harmonic structure (toy piano timbre)
    let harmonics: [Float] = [1.0, 2.0, 3.0]
    let harmonicAmps: [Float] = [1.0, 0.35, 0.15]  // Fundamental dominant

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
        return normalizedChord * envelope * 0.25  // Soft volume for gentle feel
    }

    public func reset() {
        // Stateless, no reset needed
    }
}
