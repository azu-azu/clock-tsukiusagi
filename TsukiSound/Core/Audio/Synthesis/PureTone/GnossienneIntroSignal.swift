//
//  GnossienneIntroSignal.swift
//  TsukiSound
//
//  Satie - Gnossienne No.1 (Public Domain)
//  Intro and Theme A (Bars 1-4)
//
//  Key: F Dorian Mode (F Minor with D Natural)
//  Time: 4/4
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

    /// Lento (~50 BPM)
    private static let beatDuration: Float = 1.2

    // MARK: - Frequencies (F Dorian Mode)

    struct Freq {
        static let F2: Float  = 87.31
        static let F3: Float  = 174.61
        static let Ab3: Float = 207.65
        static let C4: Float  = 261.63

        static let D4: Float  = 293.66   // D Natural (Dorian characteristic)
        static let Eb4: Float = 311.13
        static let F4: Float  = 349.23
        static let G4: Float  = 392.00
        static let Ab4: Float = 415.30
        static let B4_Nat: Float = 493.88  // Grace note
        static let C5: Float  = 523.25
    }

    // MARK: - Note Data

    struct NoteData {
        let frequency: Float
        let duration: Float  // In beats
        let graceNoteFreq: Float?

        init(freq: Float, dur: Float, grace: Float? = nil) {
            self.frequency = freq
            self.duration = dur
            self.graceNoteFreq = grace
        }

        static func rest(dur: Float) -> NoteData {
            return NoteData(freq: 0, dur: dur, grace: nil)
        }
    }

    // MARK: - Left Hand (Bass Ostinato)

    let leftHand: [NoteData] = [
        // --- Bar 1 (Intro) ---
        NoteData(freq: Freq.F2,  dur: 1.0),
        NoteData(freq: Freq.Ab3, dur: 1.0, grace: Freq.F3),  // Chord hint
        NoteData(freq: Freq.F2,  dur: 1.0),
        NoteData(freq: Freq.Ab3, dur: 1.0, grace: Freq.F3),

        // --- Bar 2 ---
        NoteData(freq: Freq.F2,  dur: 1.0),
        NoteData(freq: Freq.Ab3, dur: 1.0, grace: Freq.F3),
        NoteData(freq: Freq.F2,  dur: 1.0),
        NoteData(freq: Freq.Ab3, dur: 1.0, grace: Freq.F3),

        // --- Bar 3 ---
        NoteData(freq: Freq.F2,  dur: 1.0),
        NoteData(freq: Freq.Ab3, dur: 1.0, grace: Freq.F3),
        NoteData(freq: Freq.F2,  dur: 1.0),
        NoteData(freq: Freq.Ab3, dur: 1.0, grace: Freq.F3),

        // --- Bar 4 ---
        NoteData(freq: Freq.F2,  dur: 1.0),
        NoteData(freq: Freq.Ab3, dur: 1.0, grace: Freq.F3),
        NoteData(freq: Freq.F2,  dur: 1.0),
        NoteData(freq: Freq.Ab3, dur: 1.0, grace: Freq.F3),
    ]

    // MARK: - Right Hand (Melody)

    let rightHand: [NoteData] = [
        // --- Bar 1 (Intro - Silence) ---
        NoteData.rest(dur: 4.0),

        // --- Bar 2 (Theme Entry) ---
        NoteData(freq: Freq.C5,  dur: 1.0),
        NoteData(freq: Freq.C5,  dur: 1.0, grace: Freq.B4_Nat),  // Grace note!
        NoteData(freq: Freq.Ab4, dur: 1.0),
        NoteData(freq: Freq.F4,  dur: 1.0),

        // --- Bar 3 ---
        NoteData(freq: Freq.G4,  dur: 1.0),
        NoteData(freq: Freq.F4,  dur: 0.5),
        NoteData(freq: Freq.G4,  dur: 0.5),
        NoteData(freq: Freq.F4,  dur: 1.0),
        NoteData(freq: Freq.Eb4, dur: 1.0),

        // --- Bar 4 (Long D Natural - Dorian) ---
        NoteData(freq: Freq.D4,  dur: 4.0),
    ]

    // MARK: - Timing

    lazy var leftHandCumulative: [Float] = {
        var times: [Float] = [0]
        for note in leftHand {
            times.append(times.last! + note.duration)
        }
        return times
    }()

    lazy var rightHandCumulative: [Float] = {
        var times: [Float] = [0]
        for note in rightHand {
            times.append(times.last! + note.duration)
        }
        return times
    }()

    lazy var cycleDuration: Float = {
        max(leftHandCumulative.last!, rightHandCumulative.last!)
    }()

    // MARK: - Sound Parameters

    let graceDuration: Float = 0.10

    let melodyAttack: Float = 0.05
    let melodyDecay: Float = 2.0
    let melodyGain: Float = 0.45
    let graceGain: Float = 0.25

    let bassAttack: Float = 0.03
    let bassDecay: Float = 1.5
    let bassGain: Float = 0.20
    let chordGain: Float = 0.12

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration * Self.beatDuration)
        let beatPosition = cycleTime / Self.beatDuration

        var signal: Float = 0.0

        // Left hand (bass)
        signal += generateLeftHand(beat: beatPosition, t: t)

        // Right hand (melody)
        signal += generateRightHand(beat: beatPosition, t: t)

        return SignalEnvelopeUtils.softClip(signal * 0.6)
    }

    // MARK: - Left Hand Generation

    private func generateLeftHand(beat: Float, t: Float) -> Float {
        guard let idx = findNoteIndex(beat: beat, cumulative: leftHandCumulative) else {
            return 0.0
        }

        let note = leftHand[idx]
        guard note.frequency > 0 else { return 0.0 }  // Rest

        let noteStart = leftHandCumulative[idx]
        let timeSinceStart = (beat - noteStart) * Self.beatDuration

        var signal: Float = 0.0

        // Main bass note
        let env = envelope(time: timeSinceStart, attack: bassAttack, decay: bassDecay)
        signal += sin(2.0 * Float.pi * note.frequency * t) * env * bassGain

        // Chord notes (F3, Ab3, C4) when grace hint present
        if note.graceNoteFreq != nil {
            signal += sin(2.0 * Float.pi * Freq.F3 * t) * env * chordGain
            signal += sin(2.0 * Float.pi * Freq.Ab3 * t) * env * chordGain
            signal += sin(2.0 * Float.pi * Freq.C4 * t) * env * chordGain
        }

        return signal
    }

    // MARK: - Right Hand Generation

    private func generateRightHand(beat: Float, t: Float) -> Float {
        guard let idx = findNoteIndex(beat: beat, cumulative: rightHandCumulative) else {
            return 0.0
        }

        let note = rightHand[idx]
        guard note.frequency > 0 else { return 0.0 }  // Rest

        let noteStart = rightHandCumulative[idx]
        let timeSinceStart = (beat - noteStart) * Self.beatDuration

        var signal: Float = 0.0

        // Grace note
        if let grace = note.graceNoteFreq {
            if timeSinceStart < graceDuration * Self.beatDuration {
                let graceEnv = envelope(time: timeSinceStart, attack: 0.01, decay: 0.06)
                signal += pianoTone(freq: grace, t: t) * graceEnv * graceGain
            }
        }

        // Main melody note
        let env = envelope(time: timeSinceStart, attack: melodyAttack, decay: melodyDecay)
        signal += pianoTone(freq: note.frequency, t: t) * env * melodyGain

        return signal
    }

    // MARK: - Helpers

    private func findNoteIndex(beat: Float, cumulative: [Float]) -> Int? {
        for i in 0..<(cumulative.count - 1) {
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

    private func envelope(time: Float, attack: Float, decay: Float) -> Float {
        if time < attack {
            let p = time / attack
            return p * p
        } else {
            return exp(-(time - attack) / decay)
        }
    }
}

// MARK: - Design Notes
//
// GNOSSIENNE NO. 1 - INTRO & THEME A
//
// Source: Erik Satie (1890, public domain)
//
// KEY CORRECTION:
//
// F Dorian Mode (not F Minor):
// - Uses D Natural (293.66Hz) instead of Db
// - This creates the characteristic "modal" sound
//
// STRUCTURE:
//
// Bar 1 (Intro):
// - Left hand: Bass ostinato (F2 -> Fm chord)
// - Right hand: Silence (rest)
//
// Bar 2 (Theme Entry):
// - C5, [B Natural]->C5, Ab4, F4
//
// Bar 3:
// - G4, F4(0.5)-G4(0.5), F4, Eb4
//
// Bar 4:
// - D4 (whole note, Dorian characteristic)
//
// ACCOMPANIMENT:
//
// Left hand ostinato pattern:
// - F2 (bass) -> Fm chord (F3, Ab3, C4)
// - Repeats throughout
//
// COPYRIGHT:
//
// Erik Satie died in 1925. Public domain since 1995.
