//
//  GnossienneIntroSignal.swift
//  TsukiSound
//
//  Satie - Gnossienne No.1 (Public Domain)
//  Theme A and B (Bars 1-6)
//
//  Key: F Minor / Dorian Mode (3 flats, but with D natural)
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

    // MARK: - Pitch Frequencies

    // Bass & Chord
    let F2: Float  = 87.31
    let F3: Float  = 174.61
    let Ab3: Float = 207.65
    let C4_chord: Float = 261.63

    // Melody
    let D4: Float  = 293.66
    let Eb4: Float = 311.13
    let F4: Float  = 349.23
    let G4: Float  = 392.00
    let Ab4: Float = 415.30
    let Bb4: Float = 466.16
    let B4_Nat: Float = 493.88  // Grace note
    let C5: Float  = 523.25
    let Db5: Float = 554.37
    let Eb5: Float = 622.25
    let F5: Float  = 698.46

    // MARK: - Note Data

    struct MelodyNote {
        let freq: Float
        let startBar: Int
        let startBeat: Float
        let durBeats: Float
        let graceFreq: Float?

        init(_ freq: Float, bar: Int, beat: Float, dur: Float, grace: Float? = nil) {
            self.freq = freq
            self.startBar = bar
            self.startBeat = beat
            self.durBeats = dur
            self.graceFreq = grace
        }
    }

    struct BassNote {
        let freq: Float
        let isChord: Bool
        let startBar: Int
        let startBeat: Float
        let durBeats: Float
    }

    // MARK: - Melody (Right Hand)

    lazy var melody: [MelodyNote] = {
        [
            // --- Theme A (Bars 2-4) ---

            // Bar 2: C5 ... [Grace B]->C5 ... Ab4 ... F4
            MelodyNote(C5, bar: 2, beat: 0.0, dur: 1.0),
            MelodyNote(C5, bar: 2, beat: 1.0, dur: 1.0, grace: B4_Nat),
            MelodyNote(Ab4, bar: 2, beat: 2.0, dur: 1.0),
            MelodyNote(F4, bar: 2, beat: 3.0, dur: 1.0),

            // Bar 3: G4 ... F4(8)-G4(8) ... F4 ... Eb4
            MelodyNote(G4, bar: 3, beat: 0.0, dur: 1.0),
            MelodyNote(F4, bar: 3, beat: 1.0, dur: 0.5),
            MelodyNote(G4, bar: 3, beat: 1.5, dur: 0.5),
            MelodyNote(F4, bar: 3, beat: 2.0, dur: 1.0),
            MelodyNote(Eb4, bar: 3, beat: 3.0, dur: 1.0),

            // Bar 4: D4 (Dorian note, held long)
            MelodyNote(D4, bar: 4, beat: 0.0, dur: 4.0),

            // --- Theme B (Bars 5-6) ---

            // Bar 5: F5 ... Eb5 ... [Grace Db]->Eb5 (Long)
            MelodyNote(F5, bar: 5, beat: 1.0, dur: 1.0),
            MelodyNote(Eb5, bar: 5, beat: 2.0, dur: 1.0),
            MelodyNote(Eb5, bar: 5, beat: 3.0, dur: 2.0, grace: Db5),

            // Bar 6: Db5 ... C5 ... Bb4 ... C5
            MelodyNote(Db5, bar: 6, beat: 0.0, dur: 1.0),
            MelodyNote(C5, bar: 6, beat: 1.0, dur: 1.0),
            MelodyNote(Bb4, bar: 6, beat: 2.0, dur: 1.0),
            MelodyNote(C5, bar: 6, beat: 3.0, dur: 1.0),
        ]
    }()

    // MARK: - Bass (Left Hand)

    lazy var bass: [BassNote] = {
        var notes: [BassNote] = []
        for bar in 1...6 {
            // Bass -> Chord -> Bass -> Chord
            notes.append(BassNote(freq: F2, isChord: false, startBar: bar, startBeat: 0.0, durBeats: 1.0))
            notes.append(BassNote(freq: F3, isChord: true,  startBar: bar, startBeat: 1.0, durBeats: 1.0))
            notes.append(BassNote(freq: F2, isChord: false, startBar: bar, startBeat: 2.0, durBeats: 1.0))
            notes.append(BassNote(freq: F3, isChord: true,  startBar: bar, startBeat: 3.0, durBeats: 1.0))
        }
        return notes
    }()

    // MARK: - Timing

    let totalBars: Int = 6
    let beatsPerBar: Float = 4.0

    lazy var cycleDuration: Float = {
        Float(totalBars) * beatsPerBar * Self.beatDuration
    }()

    // MARK: - Sound Parameters

    let graceDuration: Float = 0.12

    let melodyAttack: Float = 0.05
    let melodyDecay: Float = 2.0
    let melodyGain: Float = 0.45
    let graceGain: Float = 0.30

    let bassAttack: Float = 0.03
    let bassDecay: Float = 1.5
    let bassGain: Float = 0.18
    let chordGain: Float = 0.10

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)
        let totalBeats = cycleTime / Self.beatDuration
        let currentBar = Int(totalBeats / beatsPerBar) + 1
        let beatInBar = totalBeats.truncatingRemainder(dividingBy: beatsPerBar)

        var signal: Float = 0.0

        // Bass
        signal += generateBass(bar: currentBar, beat: beatInBar, t: t)

        // Melody
        signal += generateMelody(bar: currentBar, beat: beatInBar, t: t)

        return SignalEnvelopeUtils.softClip(signal * 0.6)
    }

    // MARK: - Melody Generation

    private func generateMelody(bar: Int, beat: Float, t: Float) -> Float {
        var signal: Float = 0.0

        for note in melody {
            guard note.startBar == bar else { continue }

            // Grace note
            if let grace = note.graceFreq {
                let graceStart = note.startBeat
                let graceEnd = graceStart + graceDuration

                if beat >= graceStart && beat < graceEnd {
                    let timeInGrace = (beat - graceStart) * Self.beatDuration
                    let env = envelope(time: timeInGrace, attack: 0.01, decay: 0.08)
                    signal += pianoTone(freq: grace, t: t) * env * graceGain
                }
            }

            // Main note
            let noteEnd = note.startBeat + note.durBeats
            if beat >= note.startBeat && beat < noteEnd {
                let timeSinceStart = (beat - note.startBeat) * Self.beatDuration
                let env = envelope(time: timeSinceStart, attack: melodyAttack, decay: melodyDecay)
                signal += pianoTone(freq: note.freq, t: t) * env * melodyGain
            }
        }

        return signal
    }

    // MARK: - Bass Generation

    private func generateBass(bar: Int, beat: Float, t: Float) -> Float {
        var signal: Float = 0.0

        for note in bass {
            guard note.startBar == bar else { continue }

            let noteEnd = note.startBeat + note.durBeats
            if beat >= note.startBeat && beat < noteEnd {
                let timeSinceStart = (beat - note.startBeat) * Self.beatDuration
                let env = envelope(time: timeSinceStart, attack: bassAttack, decay: bassDecay)

                if note.isChord {
                    // Fm chord: F3, Ab3, C4
                    signal += sin(2.0 * Float.pi * F3 * t) * env * chordGain
                    signal += sin(2.0 * Float.pi * Ab3 * t) * env * chordGain
                    signal += sin(2.0 * Float.pi * C4_chord * t) * env * chordGain
                } else {
                    // Bass note
                    signal += sin(2.0 * Float.pi * note.freq * t) * env * bassGain
                }
            }
        }

        return signal
    }

    // MARK: - Helpers

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
// GNOSSIENNE NO. 1
//
// Source: Erik Satie (1890, public domain)
//
// STRUCTURE:
//
// Theme A (Bars 2-4):
// - Bar 2: C5, [B Natural]->C5, Ab4, F4
// - Bar 3: G4, F4-G4 (8ths), F4, Eb4
// - Bar 4: D4 (whole note, Dorian color)
//
// Theme B (Bars 5-6):
// - Bar 5: F5, Eb5, [Db5]->Eb5 (long)
// - Bar 6: Db5, C5, Bb4, C5
//
// ACCOMPANIMENT:
//
// Hypnotic ostinato (all bars):
// Beat 0: F2 (bass)
// Beat 1: Fm chord (F3, Ab3, C4)
// Beat 2: F2 (bass)
// Beat 3: Fm chord (F3, Ab3, C4)
//
// KEY FEATURES:
//
// - Grace notes (Acciaccatura) for Oriental flavor
// - D natural creates Dorian mode color
// - Bar 3 rhythm: 1-0.5-0.5-1-1 beats
//
// COPYRIGHT:
//
// Erik Satie died in 1925. Public domain since 1995.
