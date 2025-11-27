//
//  GymnopedieMainMelodySignal.swift
//  TsukiSound
//
//  Satie - Gymnopédie No.1 (Public Domain)
//  楽譜に基づく3層構造: ベース + 和音 + メロディ
//
//  楽譜解析 (g1-g4.jpeg):
//  - 調号: D Major (F#, C#)
//  - 拍子: 3/4
//  - テンポ: Lent et douloureux (≈70 BPM)
//  - メロディ: 小節6から始まる流れるようなレガート旋律
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
    let totalBars: Int = 39
    lazy var cycleDuration: Float = Float(totalBars) * barDuration

    // MARK: - Frequency Constants (D Major: F#, C#)

    // Bass
    let G2:  Float = 98.00
    let D3:  Float = 146.83

    // Chord
    let D4:  Float = 293.66
    let F_4: Float = 369.99   // F#4

    // Melody (楽譜に基づく正確な音域)
    let F_4m: Float = 369.99  // F#4 for melody
    let G4:  Float = 392.00
    let A4:  Float = 440.00
    let B4:  Float = 493.88
    let C_5: Float = 554.37   // C#5
    let D5:  Float = 587.33
    let E5:  Float = 659.25

    // MARK: - Sound Parameters

    let melodyAttack: Float = 0.08
    let melodyDecay: Float = 2.5      // 長めのディケイでレガート感
    let melodyGain: Float = 0.28

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

    // MARK: - Melody Data (楽譜 g1-g4.jpeg より正確に転写)
    //
    // 小節番号は0-indexed (楽譜の小節1 = startBar: 0)
    // 拍は0-indexed (1拍目 = startBeat: 0)
    //
    // 楽譜の特徴:
    // - 小節1-4: イントロ（メロディなし）
    // - 小節5-6から: 有名な下降→上昇の流れるメロディ
    // - 長いスラーでレガートに演奏

    lazy var melodyNotes: [MelodyNote] = {
        return [
            // ===== 小節1-4: イントロ（メロディなし） =====

            // ===== 小節5-6: メロディ開始 =====
            // 小節5: D5 が入る（アウフタクト的に）
            MelodyNote(freq: D5, startBar: 4, startBeat: 2, durBeats: 1),

            // 小節6-11: 第1フレーズ（有名な流れるメロディ）
            // "C#5 → B4 → A4 → G4 → F#4 → G4 → A4 → B4 → C#5 → D5 → E5 → D5 → C#5 → B4"
            // 長いスラーでレガート

            // 小節6: D5(2分) - B4(4分)
            MelodyNote(freq: D5, startBar: 5, startBeat: 0, durBeats: 2),
            MelodyNote(freq: B4, startBar: 5, startBeat: 2, durBeats: 1),

            // 小節7: D5(4分) - B4(4分) - 休
            MelodyNote(freq: D5, startBar: 6, startBeat: 0, durBeats: 1),
            MelodyNote(freq: B4, startBar: 6, startBeat: 1, durBeats: 1),

            // 小節8: A4(付点2分、次へタイ)
            MelodyNote(freq: A4, startBar: 7, startBeat: 0, durBeats: 6),  // 2小節分タイ

            // 小節9-10: スラーで流れる旋律（下降→上昇）
            // A4からの続き、そしてF#4 → G4 → A4 の動き
            MelodyNote(freq: F_4m, startBar: 9, startBeat: 0, durBeats: 1),
            MelodyNote(freq: G4, startBar: 9, startBeat: 1, durBeats: 1),
            MelodyNote(freq: A4, startBar: 9, startBeat: 2, durBeats: 1),

            // 小節10: B4 → C#5 → D5
            MelodyNote(freq: B4, startBar: 9, startBeat: 0, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 9, startBeat: 1, durBeats: 1),
            MelodyNote(freq: D5, startBar: 9, startBeat: 2, durBeats: 1),

            // 小節11: E5 → D5 → C#5
            MelodyNote(freq: E5, startBar: 10, startBeat: 0, durBeats: 1),
            MelodyNote(freq: D5, startBar: 10, startBeat: 1, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 10, startBeat: 2, durBeats: 1),

            // ===== 小節12-17: 第2フレーズ =====
            // 小節12: D5(2分) - B4(4分)
            MelodyNote(freq: D5, startBar: 11, startBeat: 0, durBeats: 2),
            MelodyNote(freq: B4, startBar: 11, startBeat: 2, durBeats: 1),

            // 小節13: D5(4分) - B4(4分)
            MelodyNote(freq: D5, startBar: 12, startBeat: 0, durBeats: 1),
            MelodyNote(freq: B4, startBar: 12, startBeat: 1, durBeats: 1),

            // 小節14: A4(付点2分、タイで続く)
            MelodyNote(freq: A4, startBar: 13, startBeat: 0, durBeats: 6),

            // 小節15-16: F#4 → G4 → A4 → B4 → C#5 → D5
            MelodyNote(freq: F_4m, startBar: 15, startBeat: 0, durBeats: 1),
            MelodyNote(freq: G4, startBar: 15, startBeat: 1, durBeats: 1),
            MelodyNote(freq: A4, startBar: 15, startBeat: 2, durBeats: 1),
            MelodyNote(freq: B4, startBar: 16, startBeat: 0, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 16, startBeat: 1, durBeats: 1),
            MelodyNote(freq: D5, startBar: 16, startBeat: 2, durBeats: 1),

            // 小節17: E5 → D5 → C#5
            MelodyNote(freq: E5, startBar: 17, startBeat: 0, durBeats: 1),
            MelodyNote(freq: D5, startBar: 17, startBeat: 1, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 17, startBeat: 2, durBeats: 1),

            // ===== 小節18-23: 第3フレーズ =====
            // 小節18: D5(付点2分)
            MelodyNote(freq: D5, startBar: 18, startBeat: 0, durBeats: 3),

            // 小節19: D5(付点2分、タイで続く)
            MelodyNote(freq: D5, startBar: 19, startBeat: 0, durBeats: 6),

            // 小節21-22 (pセクション)
            MelodyNote(freq: C_5, startBar: 21, startBeat: 0, durBeats: 2),
            MelodyNote(freq: B4, startBar: 21, startBeat: 2, durBeats: 1),
            MelodyNote(freq: A4, startBar: 22, startBeat: 0, durBeats: 2),
            MelodyNote(freq: G4, startBar: 22, startBeat: 2, durBeats: 1),

            // 小節23: F#4 → G4 → A4
            MelodyNote(freq: F_4m, startBar: 23, startBeat: 0, durBeats: 1),
            MelodyNote(freq: G4, startBar: 23, startBeat: 1, durBeats: 1),
            MelodyNote(freq: A4, startBar: 23, startBeat: 2, durBeats: 1),

            // ===== 小節24-29: 第4フレーズ（繰り返し） =====
            MelodyNote(freq: B4, startBar: 24, startBeat: 0, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 24, startBeat: 1, durBeats: 1),
            MelodyNote(freq: D5, startBar: 24, startBeat: 2, durBeats: 1),

            MelodyNote(freq: E5, startBar: 25, startBeat: 0, durBeats: 1),
            MelodyNote(freq: D5, startBar: 25, startBeat: 1, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 25, startBeat: 2, durBeats: 1),

            MelodyNote(freq: D5, startBar: 26, startBeat: 0, durBeats: 2),
            MelodyNote(freq: B4, startBar: 26, startBeat: 2, durBeats: 1),

            MelodyNote(freq: D5, startBar: 27, startBeat: 0, durBeats: 1),
            MelodyNote(freq: B4, startBar: 27, startBeat: 1, durBeats: 1),

            MelodyNote(freq: A4, startBar: 28, startBeat: 0, durBeats: 6),

            // ===== 小節30-35: 終結部へ =====
            MelodyNote(freq: F_4m, startBar: 30, startBeat: 0, durBeats: 1),
            MelodyNote(freq: G4, startBar: 30, startBeat: 1, durBeats: 1),
            MelodyNote(freq: A4, startBar: 30, startBeat: 2, durBeats: 1),

            MelodyNote(freq: B4, startBar: 31, startBeat: 0, durBeats: 1),
            MelodyNote(freq: C_5, startBar: 31, startBeat: 1, durBeats: 1),
            MelodyNote(freq: D5, startBar: 31, startBeat: 2, durBeats: 1),

            MelodyNote(freq: D5, startBar: 32, startBeat: 0, durBeats: 3),

            // 小節33-35: 最終フレーズ
            MelodyNote(freq: C_5, startBar: 33, startBeat: 0, durBeats: 2),
            MelodyNote(freq: B4, startBar: 33, startBeat: 2, durBeats: 1),

            MelodyNote(freq: A4, startBar: 34, startBeat: 0, durBeats: 3),

            MelodyNote(freq: G4, startBar: 35, startBeat: 0, durBeats: 3),
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
