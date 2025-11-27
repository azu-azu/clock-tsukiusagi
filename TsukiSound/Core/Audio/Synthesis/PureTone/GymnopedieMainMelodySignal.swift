//
//  GymnopedieMainMelodySignal.swift
//  TsukiSound
//
//  Satie - Gymnopédie No.1 (Public Domain)
//  楽譜に基づく3層構造: ベース + 和音 + メロディ
//
//  Disclaimer:
//  The pitch sequence is based on score transcription.
//  This is an ambient interpretation, not a verbatim performance.
//

import Foundation

public struct GymnopedieMainMelodySignal {
    public static func makeSignal() -> Signal {
        let g = GymnoGenerator()
        return Signal { t in g.sample(at: t) }
    }
}

private final class GymnoGenerator {

    // MARK: - Timing Constants (原曲テンポ ≈ 70 BPM)

    let beat: Float = 0.857        // 1拍 ≈ 0.857秒 (70 BPM)
    lazy var barDuration: Float = beat * 3  // 1小節 = 3拍
    let totalBars: Int = 39        // イントロ〜終結（簡略版）
    lazy var cycleDuration: Float = Float(totalBars) * barDuration

    // MARK: - Frequency Constants (D Major: F#, C#)

    let G2:  Float = 98.00
    let D3:  Float = 146.83
    let F_4: Float = 369.99   // F#4
    let D4:  Float = 293.66
    let A4:  Float = 440.00
    let B4:  Float = 493.88
    let C_5: Float = 554.37   // C#5
    let D5:  Float = 587.33
    let E5:  Float = 659.25
    let F_5: Float = 739.99   // F#5

    // MARK: - Sound Parameters

    let melodyAttack: Float = 0.08
    let melodyDecay: Float = 2.0
    let melodyGain: Float = 0.25

    let bassAttack: Float = 0.12
    let bassDecay: Float = 2.5
    let bassGain: Float = 0.10

    let chordAttack: Float = 0.08
    let chordDecay: Float = 1.8
    let chordGain: Float = 0.07

    // MARK: - Data Structures

    struct MelodyNote {
        let freq: Float
        let startBar: Int
        let startBeat: Float
        let durBeats: Float
    }

    // MARK: - Melody Data

    lazy var melodyNotes: [MelodyNote] = {
        return [
            // ===== 小節5-8: 第1フレーズ =====
            MelodyNote(freq: F_5, startBar: 4, startBeat: 0, durBeats: 2),
            MelodyNote(freq: D5, startBar: 4, startBeat: 2, durBeats: 1),
            MelodyNote(freq: F_5, startBar: 5, startBeat: 0, durBeats: 1),
            MelodyNote(freq: D5, startBar: 5, startBeat: 1, durBeats: 1),
            MelodyNote(freq: B4, startBar: 6, startBeat: 0, durBeats: 3),
            MelodyNote(freq: A4, startBar: 7, startBeat: 0, durBeats: 1),
            MelodyNote(freq: B4, startBar: 7, startBeat: 1, durBeats: 2),

            // ===== 小節9-12: 第2フレーズ =====
            MelodyNote(freq: F_5, startBar: 8, startBeat: 0, durBeats: 2),
            MelodyNote(freq: D5, startBar: 8, startBeat: 2, durBeats: 1),
            MelodyNote(freq: F_5, startBar: 9, startBeat: 0, durBeats: 1),
            MelodyNote(freq: D5, startBar: 9, startBeat: 1, durBeats: 1),
            MelodyNote(freq: B4, startBar: 10, startBeat: 0, durBeats: 3),
            MelodyNote(freq: A4, startBar: 11, startBeat: 0, durBeats: 1),
            MelodyNote(freq: B4, startBar: 11, startBeat: 1, durBeats: 2),

            // ===== 小節13-17: 第3フレーズ =====
            MelodyNote(freq: F_5, startBar: 12, startBeat: 0, durBeats: 2),
            MelodyNote(freq: E5, startBar: 12, startBeat: 2, durBeats: 1),
            MelodyNote(freq: E5, startBar: 13, startBeat: 0, durBeats: 3),
            MelodyNote(freq: C_5, startBar: 14, startBeat: 0, durBeats: 3),
            MelodyNote(freq: B4, startBar: 15, startBeat: 0, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 15, startBeat: 1, durBeats: 2),
            MelodyNote(freq: D5, startBar: 16, startBeat: 0, durBeats: 3),

            // ===== 小節18-21 =====
            MelodyNote(freq: F_5, startBar: 17, startBeat: 0, durBeats: 2),
            MelodyNote(freq: D5, startBar: 17, startBeat: 2, durBeats: 1),
            MelodyNote(freq: F_5, startBar: 18, startBeat: 0, durBeats: 1),
            MelodyNote(freq: D5, startBar: 18, startBeat: 1, durBeats: 1),
            MelodyNote(freq: B4, startBar: 19, startBeat: 0, durBeats: 3),
            MelodyNote(freq: A4, startBar: 20, startBeat: 0, durBeats: 1),
            MelodyNote(freq: B4, startBar: 20, startBeat: 1, durBeats: 2),

            // ===== 小節22-25 =====
            MelodyNote(freq: F_5, startBar: 21, startBeat: 0, durBeats: 2),
            MelodyNote(freq: E5, startBar: 21, startBeat: 2, durBeats: 1),
            MelodyNote(freq: E5, startBar: 22, startBeat: 0, durBeats: 3),
            MelodyNote(freq: C_5, startBar: 23, startBeat: 0, durBeats: 3),
            MelodyNote(freq: B4, startBar: 24, startBeat: 0, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 24, startBeat: 1, durBeats: 2),

            // ===== 小節26-30 =====
            MelodyNote(freq: D5, startBar: 25, startBeat: 0, durBeats: 3),
            MelodyNote(freq: F_5, startBar: 26, startBeat: 0, durBeats: 2),
            MelodyNote(freq: D5, startBar: 26, startBeat: 2, durBeats: 1),
            MelodyNote(freq: F_5, startBar: 27, startBeat: 0, durBeats: 1),
            MelodyNote(freq: D5, startBar: 27, startBeat: 1, durBeats: 1),
            MelodyNote(freq: B4, startBar: 28, startBeat: 0, durBeats: 3),
            MelodyNote(freq: A4, startBar: 29, startBeat: 0, durBeats: 1),
            MelodyNote(freq: B4, startBar: 29, startBeat: 1, durBeats: 2),
            MelodyNote(freq: D5, startBar: 30, startBeat: 0, durBeats: 3),
        ]
    }()

    // MARK: - Bass & Chord Data

    lazy var bassNotes: [(bar: Int, freq: Float)] = {
        (0..<totalBars).map { (bar: $0, freq: G2) }
    }()

    lazy var chordBars: [Int] = {
        Array(0..<totalBars)
    }()

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        let local = t.truncatingRemainder(dividingBy: cycleDuration)

        let melodyOut = sampleMelody(at: local)
        let bassOut = sampleBass(at: local)
        let chordOut = sampleChords(at: local)

        let mixed = melodyOut + bassOut + chordOut
        return SignalEnvelopeUtils.softClip(mixed)
    }

    // MARK: - Melody Sampling

    private func sampleMelody(at t: Float) -> Float {
        var output: Float = 0

        for note in melodyNotes {
            let noteStart = Float(note.startBar) * barDuration + note.startBeat * beat
            let noteDur = note.durBeats * beat

            if t >= noteStart && t < noteStart + noteDur {
                let dt = t - noteStart
                let env = SignalEnvelopeUtils.smoothEnvelope(
                    t: dt,
                    duration: noteDur,
                    attack: melodyAttack,
                    decay: melodyDecay
                )
                let v = SignalEnvelopeUtils.pureSine(frequency: note.freq, t: t)
                output += v * env * melodyGain
            }
        }

        return output
    }

    // MARK: - Bass Sampling

    private func sampleBass(at t: Float) -> Float {
        var output: Float = 0

        for note in bassNotes {
            let noteStart = Float(note.bar) * barDuration
            let noteDur = barDuration

            if t >= noteStart && t < noteStart + noteDur {
                let dt = t - noteStart
                let env = SignalEnvelopeUtils.smoothEnvelope(
                    t: dt,
                    duration: noteDur,
                    attack: bassAttack,
                    decay: bassDecay
                )
                let v = SignalEnvelopeUtils.pureSine(frequency: note.freq, t: t)
                output += v * env * bassGain
            }
        }

        return output
    }

    // MARK: - Chord Sampling

    private func sampleChords(at t: Float) -> Float {
        var output: Float = 0

        for bar in chordBars {
            let chordStart = Float(bar) * barDuration + beat
            let chordDur = 2 * beat

            if t >= chordStart && t < chordStart + chordDur {
                let dt = t - chordStart
                let env = SignalEnvelopeUtils.smoothEnvelope(
                    t: dt,
                    duration: chordDur,
                    attack: chordAttack,
                    decay: chordDecay
                )
                let v1 = SignalEnvelopeUtils.pureSine(frequency: F_4, t: t)
                let v2 = SignalEnvelopeUtils.pureSine(frequency: D4, t: t)
                let v = (v1 + v2) * 0.5
                output += v * env * chordGain
            }
        }

        return output
    }
}
