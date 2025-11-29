//
//  GymnopedieMainMelodySignal.swift
//  TsukiSound
//
//  Satie - Gymnopédie No.1 (Public Domain)
//  楽譜に基づく3層構造: ベース + 和音 + メロディ
//
//  楽譜解析 (Ren's transcription - g1 to g4):
//  - 調号: D Major (F#, C#)
//  - 拍子: 3/4
//  - テンポ: 88 BPM (brisk yet relaxed)
//  - 構造: Bass(1拍目) + Chord(2-3拍目) + Melody
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

    // MARK: - Timing Constants (88 BPM - brisk yet relaxed)

    let beat: Float = 0.682        // 1拍 = 0.682秒 (88 BPM)
    lazy var barDuration: Float = beat * 3  // 1小節 = 3拍
    let totalBars: Int = 26       // 現在のメロディ範囲
    lazy var cycleDuration: Float = Float(totalBars) * barDuration

    // MARK: - Frequency Constants (D Major: F#, C#)

    // Bass
    let G3:  Float = 196.00
    let D3:  Float = 146.83
    let E3:  Float = 164.81

    // Chord
    let A3:  Float = 220.00
    let B3:  Float = 246.94
    let C_4: Float = 277.18   // C#4
    let D4:  Float = 293.66

    // Melody (wide range)
    let E4:  Float = 329.63
    let F_4: Float = 369.99   // F#4
    let G4:  Float = 392.00
    let A4:  Float = 440.00
    let B4:  Float = 493.88
    let C5:  Float = 523.25   // C5 (ナチュラル)
    let C_5: Float = 554.37   // C#5
    let D5:  Float = 587.33
    let E5:  Float = 659.25
    let F_5: Float = 739.99   // F#5
    let G5:  Float = 783.99
    let A5:  Float = 880.00

    // MARK: - Sound Parameters
    //
    // ミックスバランス方針（Ren's review反映）:
    // - Bass: pureSineは埋もれやすい → 厚めに（0.16）
    // - Melody: richSineは倍音で抜けやすい → 控えめに（0.28）
    // - Chord: 響き程度に（0.06）
    //
    // 美学: Bass="床"、Melody="浮かぶ線"
    // 床が厚く、線が控えめ → 静謐で詩的な響き

    let melodyAttack: Float = 0.11   // 0.08 → 0.11: ふわっと入る"サティ感"
    let melodyDecay: Float = 3.5     // 4.0 → 3.5: 累積を軽減しつつlegato維持
    let melodyGain: Float = 0.28     // 0.35 → 0.28: richSineなので控えめに

    let bassAttack: Float = 0.12
    let bassDecay: Float = 2.8       // 2.5 → 2.8: 鳴り止まない床感
    let bassGain: Float = 0.16       // 0.08 → 0.16: pureSineは厚めに

    let chordAttack: Float = 0.08
    let chordDecay: Float = 1.8
    let chordGain: Float = 0.06

    // MARK: - Data Structures

    struct MelodyNote {
        let freq: Float
        let startBar: Int      // 1-indexed
        let startBeat: Float   // 0, 1, 2
        let durBeats: Float
    }

    struct BassChordBar {
        let bar: Int           // 1-indexed
        let bassFreq: Float
        let chordFreqs: [Float]
    }

    // MARK: - Melody Data (Ren's transcription - Full Score)

    lazy var melodyNotes: [MelodyNote] = {
        return [
            // ========================================
            // MARK: g1 - Bars 1-11 (Intro + Theme A)
            // ========================================

            // Bar 1-4: Intro (No Melody)

            // --- Bar 5 (Melody Enters - 1拍休符から) ---
            // Beat 0: 休符
            MelodyNote(freq: F_5, startBar: 5, startBeat: 1, durBeats: 1),   // F#5
            MelodyNote(freq: A5, startBar: 5, startBeat: 2, durBeats: 1),    // A5

            // --- Bar 6 ---
            MelodyNote(freq: G5, startBar: 6, startBeat: 0, durBeats: 1),    // G5
            MelodyNote(freq: F_5, startBar: 6, startBeat: 1, durBeats: 1),   // F#5
            MelodyNote(freq: C_5, startBar: 6, startBeat: 2, durBeats: 1),   // C#5

            // --- Bar 7 ---
            MelodyNote(freq: B4, startBar: 7, startBeat: 0, durBeats: 1),    // B4
            MelodyNote(freq: C_5, startBar: 7, startBeat: 1, durBeats: 1),   // C#5
            MelodyNote(freq: D5, startBar: 7, startBeat: 2, durBeats: 1),    // D5

            // --- Bar 8 ---
            MelodyNote(freq: A4, startBar: 8, startBeat: 0, durBeats: 3),    // A4 (3拍)

            // --- Bar 9-12: F#4 持続 (Fa 3拍 x4) ---
            MelodyNote(freq: F_4, startBar: 9, startBeat: 0, durBeats: 3),   // F#4 (3拍)
            MelodyNote(freq: F_4, startBar: 10, startBeat: 0, durBeats: 3),  // F#4 (3拍)
            MelodyNote(freq: F_4, startBar: 11, startBeat: 0, durBeats: 3),  // F#4 (3拍)
            MelodyNote(freq: F_4, startBar: 12, startBeat: 0, durBeats: 3),  // F#4 (3拍)

            // ========================================
            // MARK: g2 - Bars 13-22 (Theme repeat + Development)
            // ========================================

            // --- Bar 13 (Theme repeat - 1拍休符から) ---
            // Beat 0: 休符
            MelodyNote(freq: F_5, startBar: 13, startBeat: 1, durBeats: 1),  // F#5
            MelodyNote(freq: A5, startBar: 13, startBeat: 2, durBeats: 1),   // A5

            // --- Bar 14 ---
            MelodyNote(freq: G5, startBar: 14, startBeat: 0, durBeats: 1),   // G5
            MelodyNote(freq: F_5, startBar: 14, startBeat: 1, durBeats: 1),  // F#5
            MelodyNote(freq: C_5, startBar: 14, startBeat: 2, durBeats: 1),  // C#5

            // --- Bar 15 ---
            MelodyNote(freq: B4, startBar: 15, startBeat: 0, durBeats: 1),   // B4
            MelodyNote(freq: C_5, startBar: 15, startBeat: 1, durBeats: 1),  // C#5
            MelodyNote(freq: D5, startBar: 15, startBeat: 2, durBeats: 1),   // D5

            // --- Bar 16 ---
            MelodyNote(freq: A4, startBar: 16, startBeat: 0, durBeats: 3),   // A4 (3拍)

            // --- Bar 17 ---
            MelodyNote(freq: C_5, startBar: 17, startBeat: 0, durBeats: 3),  // C#5 (3拍)

            // --- Bar 18 ---
            MelodyNote(freq: F_5, startBar: 18, startBeat: 0, durBeats: 3),  // F#5 (3拍)

            // --- Bar 19-21: E5 持続 (Mi 3拍 x3) ---
            MelodyNote(freq: E5, startBar: 19, startBeat: 0, durBeats: 3),   // E5 (3拍)
            MelodyNote(freq: E5, startBar: 20, startBeat: 0, durBeats: 3),   // E5 (3拍)
            MelodyNote(freq: E5, startBar: 21, startBeat: 0, durBeats: 3),   // E5 (3拍)

            // ========================================
            // MARK: g3 - Bars 22-26 (Development)
            // ========================================

            // --- Bar 22 ---
            MelodyNote(freq: A4, startBar: 22, startBeat: 0, durBeats: 1),   // A4
            MelodyNote(freq: B4, startBar: 22, startBeat: 1, durBeats: 1),   // B4
            MelodyNote(freq: C5, startBar: 22, startBeat: 2, durBeats: 1),   // C5 (ナチュラル)

            // --- Bar 23 ---
            MelodyNote(freq: E5, startBar: 23, startBeat: 0, durBeats: 1),   // E5
            MelodyNote(freq: D5, startBar: 23, startBeat: 1, durBeats: 1),   // D5
            MelodyNote(freq: B4, startBar: 23, startBeat: 2, durBeats: 1),   // B4

            // --- Bar 24 ---
            MelodyNote(freq: D5, startBar: 24, startBeat: 0, durBeats: 1),   // D5
            MelodyNote(freq: C5, startBar: 24, startBeat: 1, durBeats: 1),   // C5 (ナチュラル)
            MelodyNote(freq: B4, startBar: 24, startBeat: 2, durBeats: 1),   // B4

            // --- Bar 25 ---
            MelodyNote(freq: D5, startBar: 25, startBeat: 0, durBeats: 3),   // D5 (3拍)

            // --- Bar 26 ---
            MelodyNote(freq: D5, startBar: 26, startBeat: 0, durBeats: 2),   // D5 (2拍)
            // Beat 2: 休符または次へ続く

            // Bar 27-: 続きは後で追加
        ]
    }()

    // MARK: - Bass & Chord Data (per bar)
    //
    // パターン:
    // - 基本奇数小節: Bass=G3, Chord=B3+D4
    // - 基本偶数小節: Bass=D3, Chord=A3+C#4
    // - 例外あり（E3ベース、A3+D4和音など）

    lazy var bassChordData: [BassChordBar] = {
        var data: [BassChordBar] = []

        for bar in 1...totalBars {
            let bassFreq: Float
            let chordFreqs: [Float]

            switch bar {
            // E minor context bars (F#4 持続部分)
            case 9, 10, 11, 12:
                bassFreq = E3
                chordFreqs = [B3, D4]
            // E5 持続部分
            case 19, 20, 21:
                bassFreq = E3
                chordFreqs = [B3, D4]
            // Default pattern
            default:
                if bar % 2 == 1 {
                    bassFreq = G3
                    chordFreqs = [B3, D4]
                } else {
                    bassFreq = D3
                    chordFreqs = [A3, C_4]
                }
            }

            data.append(BassChordBar(bar: bar, bassFreq: bassFreq, chordFreqs: chordFreqs))
        }

        return data
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
                // richSine: 奇数倍音を加えて暖かみのある音色に
                let v = SignalEnvelopeUtils.richSine(frequency: note.freq, t: t)
                output += v * env * melodyGain
            }
        }

        return output
    }

    // MARK: - Bass Sampling

    private func sampleBass(at t: Float) -> Float {
        var output: Float = 0

        for data in bassChordData {
            let noteStart = Float(data.bar - 1) * barDuration
            let noteDur = barDuration

            if t >= noteStart && t < noteStart + noteDur {
                let dt = t - noteStart
                let env = SignalEnvelopeUtils.smoothEnvelope(
                    t: dt,
                    duration: noteDur,
                    attack: bassAttack,
                    decay: bassDecay
                )
                let v = SignalEnvelopeUtils.pureSine(frequency: data.bassFreq, t: t)
                output += v * env * bassGain
            }
        }

        return output
    }

    // MARK: - Chord Sampling

    private func sampleChords(at t: Float) -> Float {
        var output: Float = 0

        for data in bassChordData {
            let chordStart = Float(data.bar - 1) * barDuration + beat
            let chordDur = 2 * beat

            if t >= chordStart && t < chordStart + chordDur {
                let dt = t - chordStart
                let env = SignalEnvelopeUtils.smoothEnvelope(
                    t: dt,
                    duration: chordDur,
                    attack: chordAttack,
                    decay: chordDecay
                )

                var chordVal: Float = 0
                for freq in data.chordFreqs {
                    chordVal += SignalEnvelopeUtils.pureSine(frequency: freq, t: t)
                }
                chordVal /= Float(data.chordFreqs.count)

                output += chordVal * env * chordGain
            }
        }

        return output
    }
}
