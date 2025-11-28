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
        static let D4_Nat: Float  = 293.66
        static let Eb4: Float     = 311.13
        static let F4: Float      = 349.23
        static let G4: Float      = 392.00
        static let Ab4: Float     = 415.30
        static let Bb4: Float     = 466.16 // Si Flat
        static let B4_Nat: Float  = 493.88 // Grace note
        static let C5: Float      = 523.25
        static let D5: Float      = 587.33
        static let Eb5: Float     = 622.25
    }

    // MARK: - Note Event
    struct NoteEvent {
        let frequency: Float
        let duration: Float
        let volume: Float // Velocity (Humanize dynamics)

        init(_ freq: Float, dur: Float, vol: Float = 1.0) {
            self.frequency = freq
            self.duration = dur
            self.volume = vol
        }

        // Factory for Rest (Silence)
        static func rest(dur: Float) -> NoteEvent {
            return NoteEvent(0, dur: dur, vol: 0)
        }
    }

    // MARK: - Melody Data
    let melody: [NoteEvent] = [

        // === Intro: Azu's Ear Copy (Humanized Rhythm) ===
        // "Ta(Do) - Ta(Mi) - Tan(Re)..."
        // Changed durations to be less robotic.

        NoteEvent(Pitch.C5,  dur: 0.6, vol: 0.8),  // Do (Soft entry)
        NoteEvent(Pitch.Eb5, dur: 0.6, vol: 0.85), // Mi♭
        NoteEvent(Pitch.D5,  dur: 1.2, vol: 0.9),  // Re (Hold slightly)
        NoteEvent(Pitch.C5,  dur: 1.0, vol: 0.8),  // Do

        // "Si - Si" (The echo part)
        NoteEvent(Pitch.Bb4, dur: 1.2, vol: 0.75), // Si♭
        NoteEvent(Pitch.Bb4, dur: 2.5, vol: 0.6),  // Si♭ (Fade out long)

        // Breath before the main theme
        NoteEvent.rest(dur: 0.5),

        // === Theme A: The Score (Accurate) ===

        // Beat 1
        NoteEvent(Pitch.C5, dur: 1.0, vol: 0.9),

        // Beat 2: Grace Note Logic (Sharp attack)
        NoteEvent(Pitch.B4_Nat, dur: 0.15, vol: 0.8), // Grace
        NoteEvent(Pitch.C5,     dur: 0.85, vol: 1.0), // Main

        // Beat 3 & 4
        NoteEvent(Pitch.Ab4, dur: 1.0, vol: 0.9),
        NoteEvent(Pitch.F4,  dur: 1.0, vol: 0.85),

        // === Bar 3 ===
        NoteEvent(Pitch.G4,  dur: 1.0, vol: 0.9),
        NoteEvent(Pitch.F4,  dur: 0.5, vol: 0.8),
        NoteEvent(Pitch.G4,  dur: 0.5, vol: 0.85),
        NoteEvent(Pitch.F4,  dur: 1.0, vol: 0.8),
        NoteEvent(Pitch.Eb4, dur: 1.0, vol: 0.75),

        // === Bar 4 ===
        NoteEvent(Pitch.D4_Nat, dur: 4.0, vol: 0.6), // Fade out
    ]

    // MARK: - Timing Setup
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

    // MARK: - Sound Design (Piano Physics)

    // Sharper attack for piano hammer feel
    let attack: Float = 0.02
    let globalGain: Float = 0.5

    // MARK: - Sample Generation
    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)

        guard let idx = findNoteIndex(time: cycleTime) else { return 0.0 }

        let note = melody[idx]

        // Silence handling
        if note.frequency == 0 { return 0.0 }

        let noteStart = cumulative[idx]
        let timeSinceStart = cycleTime - noteStart

        // 1. Envelope (Piano-like shape)
        let env = pianoEnvelope(time: timeSinceStart, duration: note.duration)

        // 2. Tone (Rich harmonics)
        let tone = richTone(freq: note.frequency, t: t)

        // 3. Apply Volume & Gain
        return SignalEnvelopeUtils.softClip(tone * env * note.volume * globalGain)
    }

    // MARK: - Helpers

    private func findNoteIndex(time: Float) -> Int? {
        // Simple linear search is fine for short melodies
        for i in 0..<melody.count {
            if time >= cumulative[i] && time < cumulative[i + 1] {
                return i
            }
        }
        return nil
    }

    private func richTone(freq: Float, t: Float) -> Float {
        // Adding 4th and 5th harmonics for depth
        let harmonics: [Float]  = [1.0, 2.0, 3.0, 4.0, 5.0]
        let amplitudes: [Float] = [1.0, 0.4, 0.2, 0.1, 0.05]

        var signal: Float = 0.0
        for i in 0..<harmonics.count {
            signal += sin(2.0 * Float.pi * freq * harmonics[i] * t) * amplitudes[i]
        }
        return signal
    }

    private func pianoEnvelope(time: Float, duration: Float) -> Float {
        // Attack Phase (Hammer strike)
        if time < attack {
            return time / attack
        }

        // Decay Phase (String vibration dying out)
        // Exponential decay feels more natural than linear
        let decayTime = time - attack
        let decayRate: Float = 2.0 // Adjust for sustain length

        // Release check: prevent sound from cutting off abruptly if note ends
        if time > duration {
            return 0.0
        }

        return exp(-decayTime * decayRate)
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
