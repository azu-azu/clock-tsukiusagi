//
//  GnossienneIntroSignal.swift
//  TsukiSound
//
//  Satie - Gnossienne No.1 (Public Domain)
//  Rhythmic correction: "Ta-Ta-Tan-Tan" articulation
//
//  Key: F Dorian Mode
//  Rhythm: Based on ear-copy timing, not strict notation
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

    /// Base beat duration (~50 BPM feel)
    private static let beatDuration: Float = 1.0

    // MARK: - Frequencies

    struct Freq {
        static let F3: Float  = 174.61
        static let Ab3: Float = 207.65
        static let C4: Float  = 261.63

        static let D4: Float  = 293.66   // Natural D (Dorian)
        static let Eb4: Float = 311.13
        static let F4: Float  = 349.23
        static let G4: Float  = 392.00
        static let Ab4: Float = 415.30
        static let B4: Float  = 493.88   // Natural B (grace note)
        static let C5: Float  = 523.25
    }

    // MARK: - Note Data

    struct Note {
        let frequency: Float
        let duration: Float  // Relative length (1.0 = standard beat)

        init(_ freq: Float, dur: Float) {
            self.frequency = freq
            self.duration = dur
        }
    }

    // MARK: - Melody (Rhythmic Correction)
    // "Ta-Ta-Tan-Tan-TaaanTaaan" - immediate start, no intro

    let melody: [Note] = [
        // --- Phrase 1: "Ta-Ta-Tan-Tan" ---

        // "Ta" (Grace B - very short)
        Note(Freq.B4, dur: 0.2),

        // "Ta" (Main C - shorter to fit bounce)
        Note(Freq.C5, dur: 0.8),

        // "Tan" (Ab)
        Note(Freq.Ab4, dur: 1.0),

        // "Tan" (F)
        Note(Freq.F4, dur: 1.0),

        // --- Phrase 2: "Taaan Taaan" (Syncopated) ---

        // "Taaan" (G)
        Note(Freq.G4, dur: 1.0),

        // "Ta-Ta" (Quick F-G)
        Note(Freq.F4, dur: 0.5),
        Note(Freq.G4, dur: 0.5),

        // "Tan" (F)
        Note(Freq.F4, dur: 1.0),

        // "Tan" (Eb)
        Note(Freq.Eb4, dur: 1.0),

        // --- Phrase 3: Long Resolve ---

        // "Taaaaaaan" (D Natural - held long)
        Note(Freq.D4, dur: 4.0),
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

    let attack: Float = 0.03
    let decay: Float = 1.8
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
        // Attack
        if time < attack {
            let p = time / attack
            return p * p
        }

        // Decay (shorter notes decay faster)
        let decayTime = time - attack
        let effectiveDecay = min(decay, noteDuration * 0.8)
        return exp(-decayTime / effectiveDecay)
    }
}

// MARK: - Design Notes
//
// GNOSSIENNE NO. 1 - RHYTHMIC CORRECTION
//
// Source: Erik Satie (1890, public domain)
//
// RHYTHM FIX:
//
// "Ta-Ta-Tan-Tan" articulation:
// - Grace B is now independent short note (0.2 beats)
// - Main C follows with 0.8 beats
// - Creates "bounce" feel instead of "flat" rhythm
//
// IMMEDIATE START:
//
// No bass intro - melody starts immediately
// First sound is B4 (grace) -> C5 (main)
//
// DURATION MIX:
//
// - 0.2: Very short (grace notes)
// - 0.5: Quick movement (syncopation)
// - 0.8: Slightly short main notes
// - 1.0: Standard quarter note feel
// - 4.0: Long held note (resolve)
//
// COPYRIGHT:
//
// Erik Satie died in 1925. Public domain since 1995.
