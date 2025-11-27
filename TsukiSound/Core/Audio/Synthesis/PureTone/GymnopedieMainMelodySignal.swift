//
//  GymnopedieMainMelodySignal.swift
//  TsukiSound
//
//  Satie - Gymnopédie No.1 (Public Domain)
//  楽譜に基づく3層構造: ベース + 和音 + メロディ
//
//  楽譜解析 (Ren's transcription):
//  - 調号: D Major (F#, C#)
//  - 拍子: 3/4
//  - テンポ: Lent et douloureux (≈70 BPM)
//  - 構造: Bass(1拍目) + Chord(2-3拍目) + Melody
//
//  伴奏パターン:
//  - 奇数小節: Bass=G3, Chord=B3+D4
//  - 偶数小節: Bass=D3, Chord=A3+C#4
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
    let totalBars: Int = 24       // イントロ + テーマ（ループ用に短縮）
    lazy var cycleDuration: Float = Float(totalBars) * barDuration

    // MARK: - Frequency Constants (D Major: F#, C#)

    // Bass
    let G3:  Float = 196.00
    let D3:  Float = 146.83
    let E3:  Float = 164.81

    // Chord (低い方)
    let A3:  Float = 220.00
    let B3:  Float = 246.94
    let C_4: Float = 277.18   // C#4
    let D4:  Float = 293.66

    // Melody
    let A4:  Float = 440.00
    let B4:  Float = 493.88
    let C_5: Float = 554.37   // C#5
    let D5:  Float = 587.33
    let E5:  Float = 659.25
    let F_5: Float = 739.99   // F#5
    let G5:  Float = 783.99
    let A5:  Float = 880.00

    // MARK: - Sound Parameters

    let melodyAttack: Float = 0.08
    let melodyDecay: Float = 2.5
    let melodyGain: Float = 0.28

    let bassAttack: Float = 0.12
    let bassDecay: Float = 2.5
    let bassGain: Float = 0.12

    let chordAttack: Float = 0.08
    let chordDecay: Float = 1.8
    let chordGain: Float = 0.08

    // MARK: - Data Structures

    struct MelodyNote {
        let freq: Float
        let startBar: Int      // 1-indexed (楽譜通り)
        let startBeat: Float   // 0, 1, 2
        let durBeats: Float
    }

    struct BassNote {
        let freq: Float
        let bar: Int           // 1-indexed
    }

    struct ChordNote {
        let freqs: [Float]
        let bar: Int           // 1-indexed
    }

    // MARK: - Melody Data (Ren's transcription より)
    //
    // Bar 1-4: イントロ（メロディなし）
    // Bar 5以降: メロディ開始

    lazy var melodyNotes: [MelodyNote] = {
        return [
            // ===== Bar 5 (Melody Enters) =====
            MelodyNote(freq: F_5, startBar: 5, startBeat: 0, durBeats: 1),  // F#5
            MelodyNote(freq: A5, startBar: 5, startBeat: 1, durBeats: 1),   // A5
            MelodyNote(freq: G5, startBar: 5, startBeat: 2, durBeats: 1),   // G5

            // ===== Bar 6 =====
            MelodyNote(freq: F_5, startBar: 6, startBeat: 0, durBeats: 1),  // F#5
            MelodyNote(freq: C_5, startBar: 6, startBeat: 1, durBeats: 1),  // C#5
            MelodyNote(freq: B4, startBar: 6, startBeat: 2, durBeats: 1),   // B4

            // ===== Bar 7 =====
            MelodyNote(freq: C_5, startBar: 7, startBeat: 0, durBeats: 2),  // C#5 (半音符)
            MelodyNote(freq: D5, startBar: 7, startBeat: 2, durBeats: 1),   // D5

            // ===== Bar 8 =====
            MelodyNote(freq: A4, startBar: 8, startBeat: 0, durBeats: 3),   // A4 (付点2分)

            // ===== Bar 9 =====
            MelodyNote(freq: A4, startBar: 9, startBeat: 0, durBeats: 1),   // A4
            MelodyNote(freq: F_5, startBar: 9, startBeat: 1, durBeats: 1),  // F#5
            MelodyNote(freq: E5, startBar: 9, startBeat: 2, durBeats: 1),   // E5

            // ===== Bar 10 =====
            MelodyNote(freq: D5, startBar: 10, startBeat: 0, durBeats: 1),  // D5
            MelodyNote(freq: A4, startBar: 10, startBeat: 1, durBeats: 2),  // A4 (2分)

            // ===== Bar 11-12: 繰り返しパターン =====
            MelodyNote(freq: F_5, startBar: 11, startBeat: 0, durBeats: 1),
            MelodyNote(freq: A5, startBar: 11, startBeat: 1, durBeats: 1),
            MelodyNote(freq: G5, startBar: 11, startBeat: 2, durBeats: 1),

            MelodyNote(freq: F_5, startBar: 12, startBeat: 0, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 12, startBeat: 1, durBeats: 1),
            MelodyNote(freq: B4, startBar: 12, startBeat: 2, durBeats: 1),

            // ===== Bar 13-14 =====
            MelodyNote(freq: C_5, startBar: 13, startBeat: 0, durBeats: 2),
            MelodyNote(freq: D5, startBar: 13, startBeat: 2, durBeats: 1),

            MelodyNote(freq: A4, startBar: 14, startBeat: 0, durBeats: 3),

            // ===== Bar 15-16 =====
            MelodyNote(freq: A4, startBar: 15, startBeat: 0, durBeats: 1),
            MelodyNote(freq: F_5, startBar: 15, startBeat: 1, durBeats: 1),
            MelodyNote(freq: E5, startBar: 15, startBeat: 2, durBeats: 1),

            MelodyNote(freq: D5, startBar: 16, startBeat: 0, durBeats: 1),
            MelodyNote(freq: A4, startBar: 16, startBeat: 1, durBeats: 2),

            // ===== Bar 17-20: 展開部 =====
            MelodyNote(freq: F_5, startBar: 17, startBeat: 0, durBeats: 1),
            MelodyNote(freq: A5, startBar: 17, startBeat: 1, durBeats: 1),
            MelodyNote(freq: G5, startBar: 17, startBeat: 2, durBeats: 1),

            MelodyNote(freq: F_5, startBar: 18, startBeat: 0, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 18, startBeat: 1, durBeats: 1),
            MelodyNote(freq: B4, startBar: 18, startBeat: 2, durBeats: 1),

            MelodyNote(freq: C_5, startBar: 19, startBeat: 0, durBeats: 2),
            MelodyNote(freq: D5, startBar: 19, startBeat: 2, durBeats: 1),

            MelodyNote(freq: A4, startBar: 20, startBeat: 0, durBeats: 3),

            // ===== Bar 21-24: 終結 =====
            MelodyNote(freq: A4, startBar: 21, startBeat: 0, durBeats: 1),
            MelodyNote(freq: F_5, startBar: 21, startBeat: 1, durBeats: 1),
            MelodyNote(freq: E5, startBar: 21, startBeat: 2, durBeats: 1),

            MelodyNote(freq: D5, startBar: 22, startBeat: 0, durBeats: 1),
            MelodyNote(freq: A4, startBar: 22, startBeat: 1, durBeats: 2),

            MelodyNote(freq: D5, startBar: 23, startBeat: 0, durBeats: 3),

            MelodyNote(freq: D5, startBar: 24, startBeat: 0, durBeats: 3),
        ]
    }()

    // MARK: - Bass Data (DRY: 奇数=G3, 偶数=D3, 例外あり)

    lazy var bassNotes: [BassNote] = {
        (1...totalBars).map { bar in
            let freq: Float
            if bar == 9 || bar == 10 || bar == 15 || bar == 16 || bar == 21 || bar == 22 {
                freq = E3  // 例外: E minor 7 context
            } else if bar % 2 == 1 {
                freq = G3  // 奇数小節
            } else {
                freq = D3  // 偶数小節
            }
            return BassNote(freq: freq, bar: bar)
        }
    }()

    // MARK: - Chord Data (DRY: 奇数=B3+D4, 偶数=A3+C#4)

    lazy var chordNotes: [ChordNote] = {
        (1...totalBars).map { bar in
            let freqs: [Float]
            if bar % 2 == 1 {
                freqs = [B3, D4]      // 奇数小節
            } else {
                freqs = [A3, C_4]     // 偶数小節
            }
            return ChordNote(freqs: freqs, bar: bar)
        }
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
            // 1-indexed to 0-indexed
            let noteStart = Float(note.startBar - 1) * barDuration + note.startBeat * beat
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
            // 1-indexed to 0-indexed
            let noteStart = Float(note.bar - 1) * barDuration
            let noteDur = barDuration  // 付点2分 = 小節全体

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

        for chord in chordNotes {
            // 1-indexed to 0-indexed, 2拍目から開始
            let chordStart = Float(chord.bar - 1) * barDuration + beat
            let chordDur = 2 * beat  // 2分音符

            if t >= chordStart && t < chordStart + chordDur {
                let dt = t - chordStart
                let env = SignalEnvelopeUtils.smoothEnvelope(
                    t: dt,
                    duration: chordDur,
                    attack: chordAttack,
                    decay: chordDecay
                )

                var chordVal: Float = 0
                for freq in chord.freqs {
                    chordVal += SignalEnvelopeUtils.pureSine(frequency: freq, t: t)
                }
                chordVal /= Float(chord.freqs.count)

                output += chordVal * env * chordGain
            }
        }

        return output
    }
}
