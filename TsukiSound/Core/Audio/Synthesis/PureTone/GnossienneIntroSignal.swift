//
//  GnossienneIntroSignal.swift
//  TsukiSound
//
//  Satie - Gnossienne No.1 (Public Domain)
//  True opening: C5 → Eb5 → D5 → C5 → Bb4 → Bb4
//
//  Key signature: Bb, Eb, Ab (flats)
//  Character: Lent, flowing, ambiguous meter
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

    // MARK: - Pitches

    struct Pitch {
        static let D4_Nat: Float  = 293.66   // Dorian
        static let Eb4: Float     = 311.13
        static let F4: Float      = 349.23
        static let G4: Float      = 392.00
        static let Ab4: Float     = 415.30
        static let Bb4: Float     = 466.16
        static let B4_Nat: Float  = 493.88   // Grace note
        static let C5: Float      = 523.25
        static let D5: Float      = 587.33
        static let Eb5: Float     = 622.25
    }

    // MARK: - Note Event

    struct NoteEvent {
        let frequency: Float
        let duration: Float

        init(_ freq: Float, dur: Float) {
            self.frequency = freq
            self.duration = dur
        }
    }

    // MARK: - Melody Data

    let melody: [NoteEvent] = [

        // === Intro: True Satie Opening ===
        // The famous "wandering" melody everyone recognizes
        // C5 → Eb5 → D5 → C5 → Bb4 → Bb4

        NoteEvent(Pitch.C5,  dur: 1.2),   // Do
        NoteEvent(Pitch.Eb5, dur: 1.2),   // Mi♭
        NoteEvent(Pitch.D5,  dur: 1.2),   // Re
        NoteEvent(Pitch.C5,  dur: 1.3),   // Do
        NoteEvent(Pitch.Bb4, dur: 1.2),   // Si♭
        NoteEvent(Pitch.Bb4, dur: 1.5),   // Si♭ (longer)

        // === Theme A: "Ta - Ta(Grace) - Tan - Tan" ===

        NoteEvent(Pitch.C5, dur: 1.0),

        // Grace note split (0.15 + 0.85)
        NoteEvent(Pitch.B4_Nat, dur: 0.15),
        NoteEvent(Pitch.C5, dur: 0.85),

        NoteEvent(Pitch.Ab4, dur: 1.0),
        NoteEvent(Pitch.F4, dur: 1.0),

        // === Bar 3: Syncopated ===

        NoteEvent(Pitch.G4, dur: 1.0),
        NoteEvent(Pitch.F4, dur: 0.5),
        NoteEvent(Pitch.G4, dur: 0.5),
        NoteEvent(Pitch.F4, dur: 1.0),
        NoteEvent(Pitch.Eb4, dur: 1.0),

        // === Bar 4: Long Resolve ===

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
        cumulative.last!
    }()

    // MARK: - Sound Parameters

    let attack: Float = 0.08
    let decay: Float = 2.5
    let gain: Float = 0.40

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)

        guard let idx = findNoteIndex(time: cycleTime) else {
            return 0.0
        }

        let note = melody[idx]
        let noteStart = cumulative[idx]
        let timeSinceStart = cycleTime - noteStart

        let env = envelope(time: timeSinceStart, noteDuration: note.duration)
        let tone = softTone(freq: note.frequency, t: t)

        return SignalEnvelopeUtils.softClip(tone * env * gain)
    }

    // MARK: - Helpers

    private func findNoteIndex(time: Float) -> Int? {
        for i in 0..<melody.count {
            if time >= cumulative[i] && time < cumulative[i + 1] {
                return i
            }
        }
        return nil
    }

    private func softTone(freq: Float, t: Float) -> Float {
        let harmonics: [Float] = [1.0, 2.0, 3.0]
        let amplitudes: [Float] = [1.0, 0.3, 0.1]

        var signal: Float = 0.0
        for i in 0..<harmonics.count {
            signal += sin(2.0 * Float.pi * freq * harmonics[i] * t) * amplitudes[i]
        }
        return signal / Float(harmonics.count)
    }

    private func envelope(time: Float, noteDuration: Float) -> Float {
        if time < attack {
            let p = time / attack
            return p
        }

        let decayTime = time - attack
        let effectiveDecay = max(decay, noteDuration * 0.6)
        return exp(-decayTime / effectiveDecay)
    }
}

// MARK: - Design Notes
//
// GNOSSIENNE NO. 1 - TRUE OPENING
//
// Source: Erik Satie (1890, public domain)
//
// INTRO:
//
// The famous "wandering" melody:
// C5 → Eb5 → D5 → C5 → Bb4 → Bb4
// (Do Mi Re Do Si Si)
//
// This is what everyone recognizes as "Gnossienne No.1"
//
// STRUCTURE:
//
// 1. Intro: Do-Mi-Re-Do-Si-Si (6 notes)
// 2. Theme A: Ta-Ta-Tan-Tan pattern
// 3. Syncopated movement
// 4. Long D Natural resolve
//
// COPYRIGHT:
//
// Erik Satie died in 1925. Public domain since 1995.
