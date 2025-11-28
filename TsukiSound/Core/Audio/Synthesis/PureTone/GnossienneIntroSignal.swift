//
//  GnossienneIntroSignal.swift
//  TsukiSound
//
//  Satie - Gnossienne No.1 (Public Domain)
//  Theme presentation section (Bars 1-6)
//
//  Key: F Minor (3 flats: Bb, Eb, Ab)
//  Time: 4/4
//
//  Corrections based on score analysis:
//  - Grace notes (Acciaccatura) for Oriental flavor
//  - Proper half note duration in Bar 5
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

    // MARK: - Tempo Configuration

    /// Lento (Very slow, approx 50 BPM)
    private static let beatDuration: Float = 1.2

    // MARK: - Pitch Frequencies

    enum Pitch: Float {
        // Bass & Chord
        case F2  = 87.31
        case F3  = 174.61
        case Ab3 = 207.65
        case C4_chord = 261.63  // For chord use

        // Melody range
        case D4  = 293.66
        case Eb4 = 311.13
        case F4  = 349.23
        case G4  = 392.00
        case Ab4 = 415.30
        case Bb4 = 466.16
        case B4_Natural = 493.88  // Grace note (Oriental flavor)
        case C5  = 523.25
        case Db5 = 554.37
        case Eb5 = 622.25
        case F5  = 698.46
    }

    // MARK: - Note Data Structure

    struct MelodyNote {
        let pitch: Pitch
        let startBeat: Float
        let duration: Float
        let graceNote: Pitch?  // Optional grace note (Acciaccatura)

        init(_ pitch: Pitch, start: Float, dur: Float, grace: Pitch? = nil) {
            self.pitch = pitch
            self.startBeat = start
            self.duration = dur
            self.graceNote = grace
        }
    }

    // MARK: - Melody Definition (Corrected from score)

    let melodyByBar: [[MelodyNote]] = [
        // --- Bar 1 (Intro) ---
        // LH only, no melody
        [],

        // --- Bar 2 (Theme A) ---
        // C5 - [Grace B4]-C5 - Ab4 - F4
        [
            MelodyNote(.C5, start: 0.0, dur: 1.0),
            MelodyNote(.C5, start: 1.0, dur: 1.0, grace: .B4_Natural),  // Grace note!
            MelodyNote(.Ab4, start: 2.0, dur: 1.0),
            MelodyNote(.F4, start: 3.0, dur: 1.0),
        ],

        // --- Bar 3 ---
        // G4 - F4(8th)-G4(8th) - F4 - Eb4
        [
            MelodyNote(.G4, start: 0.0, dur: 1.0),
            MelodyNote(.F4, start: 1.0, dur: 0.5),
            MelodyNote(.G4, start: 1.5, dur: 0.5),
            MelodyNote(.F4, start: 2.0, dur: 1.0),
            MelodyNote(.Eb4, start: 3.0, dur: 1.0),
        ],

        // --- Bar 4 ---
        // D4 (Whole Note) - Dorian flavor
        [
            MelodyNote(.D4, start: 0.0, dur: 4.0),
        ],

        // --- Bar 5 ---
        // F5 - Eb5 - [Grace Db5]-Eb5 (Half Note!)
        // Melody starts on beat 1 (rest on beat 0)
        [
            MelodyNote(.F5, start: 1.0, dur: 1.0),
            MelodyNote(.Eb5, start: 2.0, dur: 1.0),
            MelodyNote(.Eb5, start: 3.0, dur: 2.0, grace: .Db5),  // Half note with grace!
        ],

        // --- Bar 6 ---
        // Db5 - C5 - Bb4 - C5
        [
            MelodyNote(.Db5, start: 0.0, dur: 1.0),
            MelodyNote(.C5, start: 1.0, dur: 1.0),
            MelodyNote(.Bb4, start: 2.0, dur: 1.0),
            MelodyNote(.C5, start: 3.0, dur: 1.0),
        ],
    ]

    // MARK: - Timing

    let totalBars: Int = 6
    let beatsPerBar: Float = 4.0

    lazy var cycleDuration: Float = {
        Float(totalBars) * beatsPerBar * Self.beatDuration
    }()

    // MARK: - Sound Parameters

    // Grace note timing
    let graceDuration: Float = 0.12  // Very short (Acciaccatura)

    // Melody
    let melodyAttack: Float = 0.05
    let melodyDecay: Float = 2.0
    let melodyGain: Float = 0.45

    // Grace note
    let graceGain: Float = 0.30

    // Accompaniment
    let accompAttack: Float = 0.03
    let accompDecay: Float = 1.5
    let bassGain: Float = 0.18
    let chordGain: Float = 0.10

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)
        let totalBeats = cycleTime / Self.beatDuration
        let currentBar = Int(totalBeats / beatsPerBar) + 1
        let beatInBar = totalBeats.truncatingRemainder(dividingBy: beatsPerBar)

        var signal: Float = 0.0

        // 1. Accompaniment (Bass-Chord-Bass-Chord)
        signal += generateAccompaniment(beat: beatInBar, t: t)

        // 2. Melody with grace notes
        if currentBar >= 1 && currentBar <= melodyByBar.count {
            signal += generateMelody(bar: currentBar, beat: beatInBar, t: t)
        }

        return SignalEnvelopeUtils.softClip(signal * 0.6)
    }

    // MARK: - Melody Generation

    private func generateMelody(bar: Int, beat: Float, t: Float) -> Float {
        let notes = melodyByBar[bar - 1]
        var signal: Float = 0.0

        for note in notes {
            // Grace note handling (Acciaccatura - crushed note)
            if let grace = note.graceNote {
                let graceStart = note.startBeat
                let graceEnd = graceStart + graceDuration

                if beat >= graceStart && beat < graceEnd {
                    let timeInGrace = (beat - graceStart) * Self.beatDuration
                    let env = calculateEnvelope(
                        time: timeInGrace,
                        attack: 0.01,
                        decay: 0.08
                    )
                    signal += generatePianoTone(freq: grace.rawValue, t: t) * env * graceGain
                }
            }

            // Main note
            let noteEnd = note.startBeat + note.duration
            if beat >= note.startBeat && beat < noteEnd {
                let timeSinceStart = (beat - note.startBeat) * Self.beatDuration
                let env = calculateEnvelope(
                    time: timeSinceStart,
                    attack: melodyAttack,
                    decay: melodyDecay
                )
                signal += generatePianoTone(freq: note.pitch.rawValue, t: t) * env * melodyGain
            }
        }

        return signal
    }

    // MARK: - Accompaniment Generation

    /// Hypnotic ostinato: Bass(F2) - Chord(Fm) - Bass(F2) - Chord(Fm)
    private func generateAccompaniment(beat: Float, t: Float) -> Float {
        var signal: Float = 0.0

        let beatIndex = Int(beat)
        let beatFraction = beat - Float(beatIndex)
        let timeSinceBeat = beatFraction * Self.beatDuration

        let env = calculateEnvelope(
            time: timeSinceBeat,
            attack: accompAttack,
            decay: accompDecay
        )

        if beatIndex == 0 || beatIndex == 2 {
            // Bass (F2)
            signal += sin(2.0 * Float.pi * Pitch.F2.rawValue * t) * env * bassGain
        } else {
            // Chord (Fm: F3, Ab3, C4)
            signal += sin(2.0 * Float.pi * Pitch.F3.rawValue * t) * env * chordGain
            signal += sin(2.0 * Float.pi * Pitch.Ab3.rawValue * t) * env * chordGain
            signal += sin(2.0 * Float.pi * Pitch.C4_chord.rawValue * t) * env * chordGain
        }

        return signal
    }

    // MARK: - Tone Generation

    private func generatePianoTone(freq: Float, t: Float) -> Float {
        let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0]
        let amplitudes: [Float] = [1.0, 0.4, 0.2, 0.1]

        var signal: Float = 0.0
        for i in 0..<harmonics.count {
            signal += sin(2.0 * Float.pi * freq * harmonics[i] * t) * amplitudes[i]
        }

        return signal / Float(harmonics.count)
    }

    // MARK: - Envelope

    private func calculateEnvelope(time: Float, attack: Float, decay: Float) -> Float {
        if time < attack {
            let progress = time / attack
            return progress * progress
        } else {
            return exp(-(time - attack) / decay)
        }
    }
}

// MARK: - Design Notes
//
// GNOSSIENNE NO. 1 - CORRECTED IMPLEMENTATION
//
// Source: Erik Satie's Gnossienne No. 1 (1890, public domain)
//
// KEY CORRECTIONS:
//
// 1. GRACE NOTES (Acciaccatura):
//    - Bar 2: B4 Natural before C5 (Oriental flavor)
//    - Bar 5: Db5 before final Eb5
//    - Short duration (0.12 beats) for crushed effect
//
// 2. BAR 5 DURATION:
//    - Final Eb5 is Half Note (2.0 beats), not Quarter
//    - Creates proper phrase breathing
//
// 3. MELODY START IN BAR 5:
//    - Melody starts on beat 1, not beat 0
//    - Beat 0 is rest (LH bass only)
//
// MUSICAL STRUCTURE:
//
// Key: F Minor
// Time: 4/4 (Lento)
// Tempo: ~50 BPM
//
// LH Pattern (constant):
// Beat 0: F2 (Bass)
// Beat 1: Fm chord (F3, Ab3, C4)
// Beat 2: F2 (Bass)
// Beat 3: Fm chord (F3, Ab3, C4)
//
// COPYRIGHT:
//
// Erik Satie died in 1925. Public domain since 1995.
