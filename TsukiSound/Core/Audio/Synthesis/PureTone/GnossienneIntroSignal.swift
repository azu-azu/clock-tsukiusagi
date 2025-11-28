//
//  GnossienneIntroSignal.swift
//  TsukiSound
//
//  Satie - Gnossienne No.1 (Public Domain)
//  Free tempo (non-mesuré) with flowing chromatic melody
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
        static let Db5: Float     = 554.37
    }

    // MARK: - Note Event

    struct NoteEvent {
        let frequency: Float
        let duration: Float  // Free tempo values

        init(_ freq: Float, dur: Float) {
            self.frequency = freq
            self.duration = dur
        }
    }

    // MARK: - Melody Data

    let melody: [NoteEvent] = [

        // === Intro: Lent (flowing chromatic phrase) ===
        // The famous opening: G4 → Ab4 → Bb4 → C5 → Db5 → C5 → Bb4 → Ab4 → G4
        // Free tempo, connected legato

        NoteEvent(Pitch.G4,   dur: 1.2),
        NoteEvent(Pitch.Ab4,  dur: 1.2),
        NoteEvent(Pitch.Bb4,  dur: 1.2),
        NoteEvent(Pitch.C5,   dur: 1.3),   // Slightly longer at peak
        NoteEvent(Pitch.Db5,  dur: 1.4),   // The highest point, linger
        NoteEvent(Pitch.C5,   dur: 1.2),
        NoteEvent(Pitch.Bb4,  dur: 1.2),
        NoteEvent(Pitch.Ab4,  dur: 1.2),
        NoteEvent(Pitch.G4,   dur: 1.5),   // Rest at bottom

        // === Theme A: "Ta - Ta(Grace) - Tan - Tan" ===

        // Beat 1: C5
        NoteEvent(Pitch.C5, dur: 1.0),

        // Beat 2: Grace note split (0.15 + 0.85)
        NoteEvent(Pitch.B4_Nat, dur: 0.15),
        NoteEvent(Pitch.C5, dur: 0.85),

        // Beat 3: Ab4
        NoteEvent(Pitch.Ab4, dur: 1.0),

        // Beat 4: F4
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

    // MARK: - Sound Parameters (Voice-like, soft)

    let attack: Float = 0.08    // Slower attack for voice-like feel
    let decay: Float = 2.5      // Longer decay for legato
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

    /// Soft, voice-like tone (less harsh harmonics)
    private func softTone(freq: Float, t: Float) -> Float {
        let harmonics: [Float] = [1.0, 2.0, 3.0]
        let amplitudes: [Float] = [1.0, 0.3, 0.1]  // Softer overtones

        var signal: Float = 0.0
        for i in 0..<harmonics.count {
            signal += sin(2.0 * Float.pi * freq * harmonics[i] * t) * amplitudes[i]
        }
        return signal / Float(harmonics.count)
    }

    /// Soft envelope for legato, voice-like feel
    private func envelope(time: Float, noteDuration: Float) -> Float {
        // Slow attack
        if time < attack {
            let p = time / attack
            return p  // Linear rise for softer attack
        }

        // Long, gentle decay
        let decayTime = time - attack
        let effectiveDecay = max(decay, noteDuration * 0.6)
        return exp(-decayTime / effectiveDecay)
    }
}

// MARK: - Design Notes
//
// GNOSSIENNE NO. 1 - FREE TEMPO (NON-MESURÉ)
//
// Source: Erik Satie (1890, public domain)
//
// INTRO PHRASE:
//
// The famous opening chromatic melody:
// G4 → Ab4 → Bb4 → C5 → Db5 → C5 → Bb4 → Ab4 → G4
//
// Character:
// - Flowing, connected legato
// - Ambiguous meter (no strict beats)
// - Duration varies: 1.2 - 1.5 seconds per note
//
// SOUND DESIGN:
//
// - Voice-like (soft harmonics: 1.0, 0.3, 0.1)
// - Slow attack (0.08s) for gentle onset
// - Long decay (2.5s) for legato connection
// - No harsh piano attack
//
// STRUCTURE:
//
// 1. Intro: Chromatic ascent/descent (9 notes)
// 2. Theme A: Ta-Ta-Tan-Tan pattern
// 3. Bar 3: Syncopated movement
// 4. Bar 4: Long D Natural resolve
//
// COPYRIGHT:
//
// Erik Satie died in 1925. Public domain since 1995.
