//
//  ClairDeLuneIntroSignal.swift
//  TsukiSound
//
//  Debussy - Clair de Lune (Public Domain)
//  2-layer PureTone Engine
//
//  Layers:
//  1. Melody (right hand, true Debussy intro)
//  2. Arpeggio (Debussy-style moving inner voice, softened)
//

import Foundation

public struct ClairDeLuneIntroSignal {
    public static func makeSignal() -> Signal {
        let g = ClairDeLuneGenerator()
        return Signal { t in g.mix(at: t) }
    }
}

private final class ClairDeLuneGenerator {

    // MARK: - Pitches (Db Major / Ab Major relative)

    struct Pitch {
        static let Db4: Float = 277.18
        static let Eb4: Float = 311.13
        static let F4: Float  = 349.23
        static let Ab4: Float = 415.30
        static let Bb4: Float = 466.16

        static let Db5: Float = 554.37
        static let Eb5: Float = 622.25
        static let F5: Float  = 698.46
        static let Ab5: Float = 830.61
        static let Bb5: Float = 932.33

        static let Db3: Float = 138.59
        static let Ab3: Float = 207.65
        static let Db4_low: Float = 277.18
        static let F4_low: Float  = 349.23
    }

    struct NoteEvent {
        let frequency: Float
        let duration: Float
        init(_ freq: Float, dur: Float) {
            self.frequency = freq
            self.duration = dur
        }
    }

    // MARK: - Melody (True Debussy Intro)

    let melody: [NoteEvent] = [
        NoteEvent(Pitch.Db5, dur: 1.4),
        NoteEvent(Pitch.Eb5, dur: 1.2),
        NoteEvent(Pitch.F5,  dur: 1.2),
        NoteEvent(Pitch.Ab5, dur: 1.4),
        NoteEvent(Pitch.Bb5, dur: 1.0),
        NoteEvent(Pitch.Ab5, dur: 1.0),
        NoteEvent(Pitch.F5,  dur: 1.0),
        NoteEvent(Pitch.Eb5, dur: 1.0),
        NoteEvent(Pitch.Db5, dur: 1.8),
    ]

    // MARK: - Inner Arpeggio (Debussy-style, softened)

    let inner: [NoteEvent] = [
        NoteEvent(Pitch.Db3, dur: 0.8),
        NoteEvent(Pitch.Ab3, dur: 0.8),
        NoteEvent(Pitch.Db4_low, dur: 0.8),
        NoteEvent(Pitch.F4_low, dur: 0.8),
        NoteEvent(Pitch.Db4_low, dur: 0.8),
        NoteEvent(Pitch.Ab3, dur: 0.8),
    ]

    // MARK: - Timing

    lazy var melTimes = cumulative(melody)
    lazy var innerTimes = cumulative(inner)

    lazy var melDuration: Float = melTimes.last!
    lazy var innerDuration: Float = innerTimes.last!

    // MARK: - Sound Parameters (PureTone)

    let attack: Float = 0.06
    let decay: Float = 3.2

    let gainMel: Float = 0.48
    let gainInner: Float = 0.30

    // MARK: - Mixer

    func mix(at t: Float) -> Float {
        let m = play(at: t, notes: melody, times: melTimes, cycle: melDuration, gain: gainMel)
        let c = play(at: t, notes: inner, times: innerTimes, cycle: innerDuration, gain: gainInner)

        return SignalEnvelopeUtils.softClip(m + c)
    }

    // MARK: - Layer Playback

    private func play(
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
        for n in notes { t.append(t.last! + n.duration) }
        return t
    }

    private func find(_ x: Float, in cum: [Float]) -> Int? {
        for i in 0..<cum.count - 1 {
            if x >= cum[i] && x < cum[i + 1] {
                return i
            }
        }
        return nil
    }

    private func softTone(freq: Float, t: Float) -> Float {
        let h: [Float] = [1.0, 2.0, 3.0]
        let a: [Float] = [1.0, 0.25, 0.10]

        var s: Float = 0
        for i in 0..<h.count {
            s += sin(2 * .pi * freq * h[i] * t) * a[i]
        }
        return s / Float(h.count)
    }

    private func envelope(time: Float, dur: Float) -> Float {
        if time < attack { return time / attack }
        let d = time - attack
        let eff = max(decay, dur * 0.6)
        return exp(-d / eff)
    }
}

// MARK: - Design Notes
//
// CLAIR DE LUNE - TRUE DEBUSSY INTRO
//
// Source: Claude Debussy (1890, public domain)
//
// MELODY (Layer 1):
// Db5 → Eb5 → F5 → Ab5 → Bb5 → Ab5 → F5 → Eb5 → Db5
// The famous ascending/descending phrase
//
// ARPEGGIO (Layer 2):
// Db3 → Ab3 → Db4 → F4 → Db4 → Ab3
// Debussy-style inner voice, simplified for ambient feel
//
// COPYRIGHT:
//
// Claude Debussy died in 1918. Public domain worldwide.
