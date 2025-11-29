//
//  GymnopedieMainMelodySignal.swift
//  TsukiSound
//
//  Satie - Gymnopédie No.1 (Public Domain)
//  楽譜に基づく3層構造: ベース + 和音 + メロディ
//
//  楽譜解析 (Ren's transcription - g1 to g5):
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
    let totalBars: Int = 41       // Bar 39 + 余韻2小節
    lazy var cycleDuration: Float = Float(totalBars) * barDuration

    // MARK: - Frequency Constants (D Major: F#, C#)

    // Bass
    let C3:  Float = 130.81   // C3 (ナチュラル) - クライマックス用
    let D3:  Float = 146.83
    let E3:  Float = 164.81
    let G3:  Float = 196.00

    // Chord
    let A3:  Float = 220.00
    let B3:  Float = 246.94
    let C4:  Float = 261.63   // C4 (ナチュラル)
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
    let F5:  Float = 698.46   // F5 (ナチュラル)
    let F_5: Float = 739.99   // F#5
    let G5:  Float = 783.99
    let A5:  Float = 880.00
    let B5:  Float = 987.77   // B5
    let C6:  Float = 1046.50  // C6 (ナチュラル)
    let D6:  Float = 1174.66  // D6
    let E6:  Float = 1318.51  // E6

    // MARK: - Sound Parameters
    //
    // ミックスバランス方針（Ren's review反映）:
    // - Bass: pureSineは埋もれやすい → 厚めに（0.16）
    // - Melody: richSineは倍音で抜けやすい → 控えめに（0.28）
    // - Chord: 響き程度に（0.06）
    //
    // 美学: Bass="床"、Melody="浮かぶ線"
    // 床が厚く、線が控えめ → 静謐で詩的な響き
    //
    // 滑らかさ方針（SignalEnvelopeUtils guide準拠）:
    // - 低音(200Hz以下): attack 120ms以上
    // - 中音(200-500Hz): attack 60ms以上
    // - 高音(500Hz以上): attack 30ms以上
    // - 急激な変化はクリックノイズの原因

    let melodyAttack: Float = 0.15   // 0.13 → 0.15: 高音域の鋭さを抑え、より滑らかな立ち上がり
    let melodyDecay: Float = 4.5     // 4.0 → 4.5: より長く、優雅に減衰させる
    let melodyGain: Float = 0.28     // richSineなので控えめに

    let bassAttack: Float = 0.15     // 0.12 → 0.15: 低音は長めに（推奨120ms+）
    let bassDecay: Float = 3.5       // 2.8 → 3.5: 床感を長く持続
    let bassGain: Float = 0.16       // pureSineは厚めに

    let chordAttack: Float = 0.05    // 0.10 → 0.05: pureSineなら短くてもノイズ出にくい、パッと開く響き
    let chordDecay: Float = 2.5      // 1.8 → 2.5: 響きを長く
    let chordGain: Float = 0.06

    // MARK: - Data Structures

    struct MelodyNote {
        let freq: Float
        let startBar: Int      // 1-indexed
        let startBeat: Float   // 0, 1, 2
        let durBeats: Float
        let customGain: Float? // nil = use default melodyGain

        init(freq: Float, startBar: Int, startBeat: Float, durBeats: Float, customGain: Float? = nil) {
            self.freq = freq
            self.startBar = startBar
            self.startBeat = startBeat
            self.durBeats = durBeats
            self.customGain = customGain
        }
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
            // MARK: g1 - Bars 1-12 (Intro + Theme A)
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
            MelodyNote(freq: F_4, startBar: 9, startBeat: 0, durBeats: 12),   // F#4 (12拍)

            // ========================================
            // MARK: g2 - Bars 13-21 (Theme repeat + Development)
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
            MelodyNote(freq: E5, startBar: 19, startBeat: 0, durBeats: 9),   // E5 (9拍)

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
            MelodyNote(freq: E4, startBar: 24, startBeat: 1, durBeats: 2),   // E4 (Alto)

            // --- Bar 25-26 ---
            MelodyNote(freq: D5, startBar: 25, startBeat: 0, durBeats: 5),   // D5 (5拍)
            MelodyNote(freq: D4, startBar: 25, startBeat: 1, durBeats: 2),   // D4 (Alto)
            MelodyNote(freq: D5, startBar: 26, startBeat: 2, durBeats: 1),   // D5
            MelodyNote(freq: D4, startBar: 26, startBeat: 1, durBeats: 2),   // D4 (Alto)

            // ========================================
            // MARK: g4 - Bars 27-31 (Ascending passage)
            // ========================================
            // --- Bar 27 ---
            MelodyNote(freq: E5, startBar: 27, startBeat: 0, durBeats: 1),   // E5
            MelodyNote(freq: F5, startBar: 27, startBeat: 1, durBeats: 1),   // F5 (ナチュラル)
            MelodyNote(freq: G5, startBar: 27, startBeat: 2, durBeats: 1),   // G5

            // --- Bar 28 ---
            MelodyNote(freq: A5, startBar: 28, startBeat: 0, durBeats: 1),   // A5
            MelodyNote(freq: C5, startBar: 28, startBeat: 1, durBeats: 1),   // C5 (ナチュラル)
            MelodyNote(freq: D5, startBar: 28, startBeat: 2, durBeats: 1),   // D5

            // --- Bar 29 ---
            MelodyNote(freq: E5, startBar: 29, startBeat: 0, durBeats: 1),   // E5
            MelodyNote(freq: D5, startBar: 29, startBeat: 1, durBeats: 1),   // D5
            MelodyNote(freq: B4, startBar: 29, startBeat: 2, durBeats: 1),   // B4
            MelodyNote(freq: E4, startBar: 29, startBeat: 1, durBeats: 2),   // E4 (Alto)

            // --- Bar 30-31 ---
            MelodyNote(freq: D5, startBar: 30, startBeat: 0, durBeats: 5),   // D5 (5拍)
            MelodyNote(freq: D4, startBar: 30, startBeat: 1, durBeats: 2),   // D4 (Alto)
            MelodyNote(freq: D5, startBar: 31, startBeat: 2, durBeats: 1),   // D5
            MelodyNote(freq: D4, startBar: 31, startBeat: 1, durBeats: 2),   // D4 (Alto)

            // ========================================
            // MARK: g5 - Bars 32-39 (Final section)
            // ========================================

            // --- Bar 32 ---
            MelodyNote(freq: G5, startBar: 32, startBeat: 0, durBeats: 3),   // G5 (3拍)

            // --- Bar 33 ---
            MelodyNote(freq: F_5, startBar: 33, startBeat: 0, durBeats: 3),  // F#5 (3拍)

            // --- Bar 34 ---
            MelodyNote(freq: B4, startBar: 34, startBeat: 0, durBeats: 1),   // B4
            MelodyNote(freq: A4, startBar: 34, startBeat: 1, durBeats: 1),   // A4
            MelodyNote(freq: B4, startBar: 34, startBeat: 2, durBeats: 1),   // B4

            // --- Bar 35 ---
            MelodyNote(freq: C_5, startBar: 35, startBeat: 0, durBeats: 1),  // C#5
            MelodyNote(freq: D5, startBar: 35, startBeat: 1, durBeats: 1),   // D5
            MelodyNote(freq: E5, startBar: 35, startBeat: 2, durBeats: 1),   // E5

            // --- Bar 36 ---
            MelodyNote(freq: C_5, startBar: 36, startBeat: 0, durBeats: 1),  // C#5
            MelodyNote(freq: D5, startBar: 36, startBeat: 1, durBeats: 1),   // D5
            MelodyNote(freq: E5, startBar: 36, startBeat: 2, durBeats: 1),   // E5

            // --- Bar 37 ---
            MelodyNote(freq: F_4, startBar: 37, startBeat: 0, durBeats: 3),  // F#4 (3拍)
            MelodyNote(freq: D4, startBar: 37, startBeat: 1, durBeats: 1),   // D4 (Alto)
            MelodyNote(freq: G4, startBar: 37, startBeat: 2, durBeats: 1),   // G4 (Alto)

            // --- Bar 38-39: 階段式クライマックス ---
            // 同時4音ではなく、時間差で積み上げる（位相干渉を回避）
            // delayをstartBeatに変換: 0.08秒 ≈ 0.12 beat (beat = 0.682秒)

            // Bar 38: Am系 - 静かな準備
            MelodyNote(freq: A3, startBar: 38, startBeat: 0.00, durBeats: 3.5, customGain: 0.14),  // Bass A3
            MelodyNote(freq: E4, startBar: 38, startBeat: 0.12, durBeats: 3.3, customGain: 0.10),  // Mid E4
            MelodyNote(freq: A4, startBar: 38, startBeat: 0.24, durBeats: 3.1, customGain: 0.08),  // High A4

            // Bar 39: D Major - 最終クライマックス（階段式レイヤー）
            // Bass → Mid → Color → High の順で積み上げ
            // 位相干渉を避けるため、A4-D5間を広めに（0.08 beat ≈ 55ms）
            MelodyNote(freq: D3, startBar: 39, startBeat: 0.00, durBeats: 6.0, customGain: 0.16),  // Bass D3
            MelodyNote(freq: D4, startBar: 39, startBeat: 0.12, durBeats: 5.8, customGain: 0.10),  // Mid D4
            MelodyNote(freq: A4, startBar: 39, startBeat: 0.20, durBeats: 5.5, customGain: 0.12),  // Color A4
            MelodyNote(freq: D5, startBar: 39, startBeat: 0.28, durBeats: 5.2, customGain: 0.08)

            // Bar 40-: 続きは後で追加
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

        // デチューン幅: 0.5Hz（耳でほぼ聞き分けられないレベルのズレで豊かさを出す）
        let detuneHz: Float = 0.5

        for note in melodyNotes {
            let noteStart = Float(note.startBar - 1) * barDuration + note.startBeat * beat
            let noteDur = note.durBeats * beat

            if t >= noteStart && t < noteStart + noteDur {
                let dt = t - noteStart

                // カスタムゲインがある場合はそれを使用（階段式クライマックス用）
                // ない場合はデフォルトのmelodyGainを使用
                let isClimax = note.startBar >= 38
                // クライマックスは余韻を長く（1.5倍 → 2.0倍に延長）
                let effectiveDecay = isClimax ? melodyDecay * 2.0 : melodyDecay

                var effectiveGain: Float
                if let custom = note.customGain {
                    // 階段式クライマックス: カスタムゲインをそのまま使用
                    effectiveGain = custom
                } else {
                    // 通常のメロディ
                    effectiveGain = melodyGain

                    // 高音域のゲイン調整 (600Hz以上をターゲット)
                    // 高音域の「キーン」を抑えるため、周波数に応じてゲインを減衰
                    // pureSineでも高周波は耳に刺さりやすいため、強めに減衰
                    if note.freq >= 600.0 {
                        let maxFreq: Float = 1318.51  // E6
                        let minFreq: Float = 600.0
                        let reductionRatio = min(1.0, (note.freq - minFreq) / (maxFreq - minFreq))
                        // 最高音域で最大35%の減衰（20% → 35%に強化）
                        let highFreqReduction = 1.0 - reductionRatio * 0.35
                        effectiveGain *= highFreqReduction
                    }
                }

                let env = SignalEnvelopeUtils.smoothEnvelope(
                    t: dt,
                    duration: noteDur,
                    attack: melodyAttack,
                    decay: effectiveDecay
                )

                // デチューン・レイヤー: 3つのサイン波を重ねてコーラスのような深みを出す
                // pureSineベースなので高次倍音は発生せず、刺さる問題を回避
                let v1 = SignalEnvelopeUtils.pureSine(frequency: note.freq, t: t)           // Center
                let v2 = SignalEnvelopeUtils.pureSine(frequency: note.freq + detuneHz, t: t) // +Detune
                let v3 = SignalEnvelopeUtils.pureSine(frequency: note.freq - detuneHz, t: t) // -Detune
                let layeredV = (v1 + v2 + v3) / 3.0

                output += layeredV * env * effectiveGain
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
