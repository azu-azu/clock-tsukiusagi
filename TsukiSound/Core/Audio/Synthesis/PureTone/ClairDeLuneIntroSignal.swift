//
//  ClairDeLuneIntroSignal.swift
//  TsukiSound
//
//  Debussy - Clair de Lune (Public Domain)
//  3-layer PureTone engine
//
//  Layers:
//  1. Melody (right hand)
//  2. Inner chords (arpeggio)
//  3. Soft bass
//

import Foundation

public struct ClairDeLuneIntroSignal {
    public static func makeSignal() -> Signal {
        let g = ClairDeLuneGenerator()
        return Signal { t in g.mix(at: t) }
    }
}

private final class ClairDeLuneGenerator {

    // MARK: - Pitches (Ab Major)

    struct Pitch {
        static let Ab3: Float = 207.65
        static let Bb3: Float = 233.08
        static let C4: Float  = 261.63
        static let Db4: Float = 277.18
        static let Eb4: Float = 311.13
        static let F4: Float  = 349.23
        static let G4: Float  = 392.00
        static let Ab4: Float = 415.30
        static let Bb4: Float = 466.16
        static let C5: Float  = 523.25
    }

    struct NoteEvent {
        let frequency: Float
        let duration: Float

        init(_ freq: Float, dur: Float) {
            self.frequency = freq
            self.duration = dur
        }
    }

    // MARK: - Melody (famous intro phrase)

    let melody: [NoteEvent] = [
        NoteEvent(Pitch.Eb4, dur: 1.4),  // Mi♭
        NoteEvent(Pitch.Db4, dur: 1.2),  // Re♭
        NoteEvent(Pitch.C4,  dur: 1.2),  // Do
        NoteEvent(Pitch.Bb3, dur: 1.4),  // Si♭
        NoteEvent(Pitch.Ab3, dur: 1.0),  // La♭
        NoteEvent(Pitch.Bb3, dur: 1.0),  // Si♭
        NoteEvent(Pitch.C4,  dur: 1.6),  // Do
    ]

    // MARK: - Inner Arpeggio (soft chords)

    let inner: [NoteEvent] = [
        NoteEvent(Pitch.Ab3, dur: 0.7),
        NoteEvent(Pitch.C4,  dur: 0.7),
        NoteEvent(Pitch.Eb4, dur: 0.7),
        NoteEvent(Pitch.G4,  dur: 0.7),
        NoteEvent(Pitch.Eb4, dur: 0.7),
        NoteEvent(Pitch.C4,  dur: 0.7),
    ]

    // MARK: - Bass (simple support)

    let bass: [NoteEvent] = [
        NoteEvent(Pitch.Ab3, dur: 3.5),
        NoteEvent(Pitch.Eb4, dur: 3.5),
    ]

    // MARK: - Timing

    lazy var melTimes: [Float] = cumulative(melody)
    lazy var innerTimes: [Float] = cumulative(inner)
    lazy var bassTimes: [Float] = cumulative(bass)

    lazy var melDuration: Float = melTimes.last!
    lazy var innerDuration: Float = innerTimes.last!
    lazy var bassDuration: Float = bassTimes.last!

    // MARK: - Sound Parameters

    let attack: Float = 0.05
    let decay: Float = 2.6
    let gainMel: Float = 0.45
    let gainInner: Float = 0.25
    let gainBass: Float = 0.22

    // MARK: - Mixer

    func mix(at t: Float) -> Float {
        let m = playOneLayer(at: t, notes: melody, times: melTimes, cycle: melDuration, gain: gainMel)
        let c = playOneLayer(at: t, notes: inner, times: innerTimes, cycle: innerDuration, gain: gainInner)
        let b = playOneLayer(at: t, notes: bass, times: bassTimes, cycle: bassDuration, gain: gainBass)

        return SignalEnvelopeUtils.softClip(m + c + b)
    }

    // MARK: - Layer Player

    private func playOneLayer(
        at t: Float,
        notes: [NoteEvent],
        times: [Float],
        cycle: Float,
        gain: Float
    ) -> Float {
        let tt = t.truncatingRemainder(dividingBy: cycle)

        guard let idx = find(tt, in: times) else { return 0 }

        let note = notes[idx]
        let start = times[idx]
        let local = tt - start

        let env = envelope(time: local, dur: note.duration)
        let tone = softTone(freq: note.frequency, t: t)

        return tone * env * gain
    }

    // MARK: - Helpers

    private func cumulative(_ notes: [NoteEvent]) -> [Float] {
        var t: [Float] = [0]
        notes.forEach { t.append(t.last! + $0.duration) }
        return t
    }

    private func find(_ time: Float, in cum: [Float]) -> Int? {
        for i in 0..<cum.count - 1 {
            if time >= cum[i] && time < cum[i + 1] { return i }
        }
        return nil
    }

    private func softTone(freq: Float, t: Float) -> Float {
        let h: [Float] = [1.0, 2.0, 3.0]
        let a: [Float] = [1.0, 0.25, 0.12]

        var s: Float = 0
        for i in 0..<h.count {
            s += sin(2 * .pi * freq * h[i] * t) * a[i]
        }
        return s / Float(h.count)
    }

    private func envelope(time: Float, dur: Float) -> Float {
        if time < attack {
            return time / attack
        }
        let d = time - attack
        let eff = max(decay, dur * 0.6)
        return exp(-d / eff)
    }
}

// MARK: - Design Notes
//
// CLAIR DE LUNE - 3 LAYER STRUCTURE
//
// Source: Claude Debussy (1890, public domain)
//
// LAYERS:
//
// 1. Melody: Eb4 → Db4 → C4 → Bb3 → Ab3 → Bb3 → C4
//    The famous "moonlight" descending phrase
//
// 2. Inner: Ab3 → C4 → Eb4 → G4 → Eb4 → C4
//    Soft arpeggio for harmonic fill
//
// 3. Bass: Ab3 → Eb4
//    Simple low support, not heavy
//
// Each layer has its own cycle duration and gain.
// Layers are mixed together with soft clipping.
//
// COPYRIGHT:
//
// Claude Debussy died in 1918. Public domain worldwide.
