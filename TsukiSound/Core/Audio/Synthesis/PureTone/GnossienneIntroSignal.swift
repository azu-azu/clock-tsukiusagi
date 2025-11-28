//
//  GnossienneIntroSignal.swift
//  TsukiSound
//
//  Satie - Gnossienne No.1 (Public Domain)
//  Theme presentation section (Bars 1-6)
//
//  Key: F Minor (3 flats: Bb, Eb, Ab)
//  Time: 4/4 (with bar lines for practical reference)
//
//  Left hand: Hypnotic ostinato pattern (F2 -> Fm chord -> F2 -> Fm chord)
//  Right hand: Melody ("Très luisant")
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

    /// Quarter note duration in seconds
    /// Original tempo is around 66 BPM, we use slower ~50 BPM for meditative feel
    private static let beatDuration: Float = 1.2  // 1.2s per beat = 50 BPM

    // MARK: - Pitch Frequencies (Equal Temperament A4=440Hz)

    enum Pitch: Float {
        // Bass
        case F2  = 87.31

        // Left hand chord (Fm)
        case F3  = 174.61
        case Ab3 = 207.65
        case C4  = 261.63

        // Melody range
        case D4  = 293.66
        case Eb4 = 311.13
        case F4  = 349.23
        case G4  = 392.00
        case Ab4 = 415.30
        case Bb4 = 466.16
        case C5  = 523.25
        case Db5 = 554.37
        case Eb5 = 622.25
        case F5  = 698.46
    }

    // MARK: - Note Data Structure

    struct MelodyNote {
        let pitch: Pitch
        let startBeat: Float  // Beat position within bar (0.0 - 3.0)
        let duration: Float   // Duration in beats (1.0 = quarter note)
    }

    // MARK: - Melody Definition (Right Hand)

    /// Melody notes for each bar (1-indexed)
    /// Bar 1: No melody (LH intro only)
    let melodyByBar: [[MelodyNote]] = [
        // Bar 1: LH only (empty)
        [],

        // Bar 2: Theme A begins
        [
            MelodyNote(pitch: .C5, startBeat: 0.0, duration: 1.0),
            MelodyNote(pitch: .C5, startBeat: 1.0, duration: 1.0),
            MelodyNote(pitch: .Ab4, startBeat: 2.0, duration: 1.0),
            MelodyNote(pitch: .F4, startBeat: 3.0, duration: 1.0),
        ],

        // Bar 3
        [
            MelodyNote(pitch: .G4, startBeat: 0.0, duration: 1.0),
            MelodyNote(pitch: .F4, startBeat: 1.0, duration: 0.5),
            MelodyNote(pitch: .G4, startBeat: 1.5, duration: 0.5),
            MelodyNote(pitch: .F4, startBeat: 2.0, duration: 1.0),
            MelodyNote(pitch: .Eb4, startBeat: 3.0, duration: 1.0),
        ],

        // Bar 4: D4 whole note
        [
            MelodyNote(pitch: .D4, startBeat: 0.0, duration: 4.0),
        ],

        // Bar 5: Starts on beat 1
        [
            MelodyNote(pitch: .F5, startBeat: 1.0, duration: 1.0),
            MelodyNote(pitch: .Eb5, startBeat: 2.0, duration: 1.0),
            MelodyNote(pitch: .Eb5, startBeat: 3.0, duration: 1.0),
        ],

        // Bar 6
        [
            MelodyNote(pitch: .Db5, startBeat: 0.0, duration: 1.0),
            MelodyNote(pitch: .C5, startBeat: 1.0, duration: 1.0),
            MelodyNote(pitch: .Bb4, startBeat: 2.0, duration: 1.0),
            MelodyNote(pitch: .C5, startBeat: 3.0, duration: 1.0),
        ],
    ]

    // MARK: - Timing Calculations

    /// Total bars in the piece
    let totalBars: Int = 6

    /// Beats per bar (4/4 time)
    let beatsPerBar: Float = 4.0

    /// Total cycle duration in seconds
    lazy var cycleDuration: Float = {
        Float(totalBars) * beatsPerBar * Self.beatDuration
    }()

    // MARK: - Sound Parameters

    // Melody (right hand) - piano-like
    let melodyAttack: Float = 0.05
    let melodyDecay: Float = 2.5
    let melodyGain: Float = 0.35

    // Accompaniment (left hand) - softer, supportive
    let accompAttack: Float = 0.03
    let accompDecay: Float = 1.8
    let accompBassGain: Float = 0.20
    let accompChordGain: Float = 0.12

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)

        // Calculate current bar and beat
        let totalBeats = cycleTime / Self.beatDuration
        let currentBar = Int(totalBeats / beatsPerBar) + 1  // 1-indexed
        let beatInBar = totalBeats.truncatingRemainder(dividingBy: beatsPerBar)

        var signal: Float = 0.0

        // Generate accompaniment (left hand)
        signal += generateAccompaniment(beat: beatInBar, t: t)

        // Generate melody (right hand)
        if currentBar >= 1 && currentBar <= melodyByBar.count {
            signal += generateMelody(bar: currentBar, beat: beatInBar, t: t)
        }

        return SignalEnvelopeUtils.softClip(signal)
    }

    // MARK: - Accompaniment Generation (Left Hand)

    /// Generates the hypnotic ostinato pattern
    /// Beat 0: Bass (F2)
    /// Beat 1: Chord (Fm: F3, Ab3, C4)
    /// Beat 2: Bass (F2)
    /// Beat 3: Chord (Fm: F3, Ab3, C4)
    private func generateAccompaniment(beat: Float, t: Float) -> Float {
        var signal: Float = 0.0

        // Determine which voice is active based on beat position
        let beatIndex = Int(beat)
        let beatFraction = beat - Float(beatIndex)
        let timeSinceBeat = beatFraction * Self.beatDuration

        if beatIndex == 0 || beatIndex == 2 {
            // Bass note (F2)
            let env = calculateEnvelope(
                timeSinceStart: timeSinceBeat,
                attack: accompAttack,
                decay: accompDecay
            )
            signal += sin(2.0 * Float.pi * Pitch.F2.rawValue * t) * env * accompBassGain
        } else {
            // Chord (Fm: F3, Ab3, C4)
            let env = calculateEnvelope(
                timeSinceStart: timeSinceBeat,
                attack: accompAttack,
                decay: accompDecay
            )
            let chordPitches: [Pitch] = [.F3, .Ab3, .C4]
            for pitch in chordPitches {
                signal += sin(2.0 * Float.pi * pitch.rawValue * t) * env * accompChordGain
            }
        }

        return signal
    }

    // MARK: - Melody Generation (Right Hand)

    private func generateMelody(bar: Int, beat: Float, t: Float) -> Float {
        guard bar >= 1 && bar <= melodyByBar.count else { return 0.0 }

        let notes = melodyByBar[bar - 1]  // Convert to 0-indexed
        var signal: Float = 0.0

        for note in notes {
            // Check if this note is currently sounding
            let noteEnd = note.startBeat + note.duration
            if beat >= note.startBeat && beat < noteEnd {
                let timeSinceNoteStart = (beat - note.startBeat) * Self.beatDuration
                let env = calculateEnvelope(
                    timeSinceStart: timeSinceNoteStart,
                    attack: melodyAttack,
                    decay: melodyDecay
                )

                // Piano-like tone with harmonics
                signal += generatePianoTone(frequency: note.pitch.rawValue, t: t) * env * melodyGain
            }
        }

        return signal
    }

    // MARK: - Tone Generation

    /// Generates piano-like tone with harmonics
    private func generatePianoTone(frequency: Float, t: Float) -> Float {
        let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0]
        let amplitudes: [Float] = [1.0, 0.4, 0.2, 0.1]

        var signal: Float = 0.0
        for i in 0..<harmonics.count {
            let freq = frequency * harmonics[i]
            signal += sin(2.0 * Float.pi * freq * t) * amplitudes[i]
        }

        return signal / Float(harmonics.count)
    }

    // MARK: - Envelope

    /// Simple attack-decay envelope
    private func calculateEnvelope(timeSinceStart: Float, attack: Float, decay: Float) -> Float {
        if timeSinceStart < attack {
            // Attack phase
            let progress = timeSinceStart / attack
            return progress * progress  // Quadratic rise
        } else {
            // Decay phase
            let decayTime = timeSinceStart - attack
            return exp(-decayTime / decay)
        }
    }
}

// MARK: - Design Notes
//
// GNOSSIENNE NO. 1 IMPLEMENTATION
//
// Source: Erik Satie's Gnossienne No. 1 (1890, public domain)
//
// MUSICAL STRUCTURE:
//
// Key: F Minor (3 flats: Bb, Eb, Ab)
// Time: 4/4 (with bar lines for practical reference)
// Tempo: ~50 BPM (slower than original for meditative feel)
//
// LEFT HAND (Accompaniment):
// - Hypnotic ostinato pattern throughout
// - Beat 0: Bass (F2)
// - Beat 1: Chord (Fm: F3, Ab3, C4)
// - Beat 2: Bass (F2)
// - Beat 3: Chord (Fm: F3, Ab3, C4)
//
// RIGHT HAND (Melody):
// - Bar 1: LH intro only
// - Bar 2: Theme A begins (C5, C5, Ab4, F4)
// - Bar 3: Development (G4, F4-G4, F4, Eb4)
// - Bar 4: D4 whole note (Dorian color)
// - Bar 5: F5, Eb5, Eb5 (starts beat 1)
// - Bar 6: Db5, C5, Bb4, C5
//
// SOUND DESIGN:
//
// - Piano-like harmonics (fundamental + 3 overtones)
// - Soft accompaniment to support melody
// - Exponential decay for natural piano feel
// - Soft clipping to prevent distortion
//
// COPYRIGHT:
//
// Erik Satie died in 1925. Under copyright law (70 years after death),
// Gnossiennes entered public domain by 1995. Using the melody is legal.
