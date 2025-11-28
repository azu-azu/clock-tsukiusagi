//
//  GnossienneIntroSignal.swift
//  TsukiSound
//
//  Satie - Gnossienne No.1 (Public Domain)
//  Explicit rhythm: Beat 2 split into 0.15 + 0.85 for grace note
//
//  Key signature: Bb, Eb, Ab (flats)
//  Accidentals: B Natural (grace), D Natural (Dorian)
//

import Foundation

public struct GnossienneIntroSignal {
    public static func makeSignal() -> Signal {
        let g = GnossienneGenerator()
        return Signal { t in g.sample(at: t) }
    }
}

// MARK: - Private Implementation

private final class GnossienneGenerator {

    // MARK: - Tempo

    /// Beat duration (~50 BPM)
    private static let beatDuration: Float = 1.0

    // MARK: - Pitches (Exact from sheet music)

    struct Pitch {
        static let F4: Float      = 349.23
        static let G4: Float      = 392.00
        static let Ab4: Float     = 415.30   // Key signature flat
        static let B4_Nat: Float  = 493.88   // Accidental Natural (Grace!)
        static let C5: Float      = 523.25
        static let D4_Nat: Float  = 293.66   // Dorian characteristic
        static let Eb4: Float     = 311.13   // Key signature flat
    }

    // MARK: - Note Event

    struct NoteEvent {
        let frequency: Float
        let duration: Float  // In beats

        init(_ freq: Float, dur: Float) {
            self.frequency = freq
            self.duration = dur
        }
    }

    // MARK: - Melody Data (Bars 2-4)

    let melody: [NoteEvent] = [

        // === Bar 2: "Ta - Ta(Grace) - Tan - Tan" ===

        // Beat 1: "Ta" (C5 Quarter Note)
        NoteEvent(Pitch.C5, dur: 1.0),

        // Beat 2: Grace note split (0.15 + 0.85)
        NoteEvent(Pitch.B4_Nat, dur: 0.15),  // Grace B Natural
        NoteEvent(Pitch.C5, dur: 0.85),       // Main C5

        // Beat 3: "Tan" (Ab4)
        NoteEvent(Pitch.Ab4, dur: 1.0),

        // Beat 4: "Tan" (F4)
        NoteEvent(Pitch.F4, dur: 1.0),

        // === Bar 3: "Taaan - Taaan..." ===

        // Beat 1: G4
        NoteEvent(Pitch.G4, dur: 1.0),

        // Beat 2: F4, G4 Eighth Notes
        NoteEvent(Pitch.F4, dur: 0.5),
        NoteEvent(Pitch.G4, dur: 0.5),

        // Beat 3: F4
        NoteEvent(Pitch.F4, dur: 1.0),

        // Beat 4: Eb4
        NoteEvent(Pitch.Eb4, dur: 1.0),

        // === Bar 4: Long Resolve ===

        // Whole note D Natural
        NoteEvent(Pitch.D4_Nat, dur: 4.0),
    ]

    // MARK: - Timing

    lazy var cumulative: [Float] = {
        var times: [Float] = [0]
        for note in melody {
            times.append(times.last! + note.duration)
        }
        return times
    }()

    lazy var cycleDuration: Float = {
        cumulative.last! * Self.beatDuration
    }()

    // MARK: - Sound Parameters

    let attack: Float = 0.02
    let decay: Float = 1.5
    let gain: Float = 0.45

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)
        let beatPosition = cycleTime / Self.beatDuration

        guard let idx = findNoteIndex(beat: beatPosition) else {
            return 0.0
        }

        let note = melody[idx]
        let noteStart = cumulative[idx]
        let timeSinceStart = (beatPosition - noteStart) * Self.beatDuration

        let env = envelope(time: timeSinceStart, noteDuration: note.duration * Self.beatDuration)
        let tone = pianoTone(freq: note.frequency, t: t)

        return SignalEnvelopeUtils.softClip(tone * env * gain)
    }

    // MARK: - Helpers

    private func findNoteIndex(beat: Float) -> Int? {
        for i in 0..<melody.count {
            if beat >= cumulative[i] && beat < cumulative[i + 1] {
                return i
            }
        }
        return nil
    }

    private func pianoTone(freq: Float, t: Float) -> Float {
        let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0]
        let amplitudes: [Float] = [1.0, 0.4, 0.2, 0.1]

        var signal: Float = 0.0
        for i in 0..<harmonics.count {
            signal += sin(2.0 * Float.pi * freq * harmonics[i] * t) * amplitudes[i]
        }
        return signal / Float(harmonics.count)
    }

    private func envelope(time: Float, noteDuration: Float) -> Float {
        if time < attack {
            let p = time / attack
            return p * p
        }

        let decayTime = time - attack
        let effectiveDecay = min(decay, noteDuration * 0.7)
        return exp(-decayTime / effectiveDecay)
    }
}

// MARK: - Design Notes
//
// GNOSSIENNE NO. 1 - EXPLICIT RHYTHM
//
// Source: Erik Satie (1890, public domain)
//
// BEAT 2 SPLIT:
//
// The crucial "Ta-Ta" on Beat 2 of Bar 2:
// - 0.15 beats: B Natural (grace note kick)
// - 0.85 beats: C5 (main note)
// Total: 1.0 beat (quarter note equivalent)
//
// This ensures the "Ta-Ta" nuance is heard correctly.
//
// STRUCTURE:
//
// Bar 2: C5 | B-C5 | Ab4 | F4
// Bar 3: G4 | F4-G4 | F4 | Eb4
// Bar 4: D4 (whole note, Dorian)
//
// KEY SIGNATURE:
//
// Flats: Bb, Eb, Ab
// Accidentals: B Natural (grace), D Natural (Dorian)
//
// COPYRIGHT:
//
// Erik Satie died in 1925. Public domain since 1995.
