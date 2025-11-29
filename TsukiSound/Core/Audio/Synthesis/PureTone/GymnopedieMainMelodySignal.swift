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

    // MARK: - Structure Constants

    /// クライマックス小節（余韻延長の対象）
    /// Bar 38は準備、Bar 39が頂点だが、余韻延長は39から適用
    private let climaxBar: Int = 39

    /// デチューン幅（メロディ・和音共通）
    /// - メロディ: 細かな揺らぎで生命感を出す
    /// - 和音: 均質な厚みでコーラス感を出す
    /// 将来richSine混在時も統一感を維持するため共通化
    private let detuneHz: Float = 0.2

    // MARK: - Frequency Constants (Bass/Chord用 - GymnopedieFrequencyから参照)

    private typealias F = GymnopedieFrequency

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

    let bassAttack: Float = 0.20     // 0.15 → 0.20: 低音のノイズ抑制（200Hz以下は長めに）
    let bassDecay: Float = 3.5       // 2.8 → 3.5: 床感を長く持続
    let bassGain: Float = 0.16       // pureSineは厚めに

    let chordAttack: Float = 0.08    // 0.05 → 0.08: ノイズ抑制のため60ms以上を推奨
    let chordDecay: Float = 2.5      // 1.8 → 2.5: 響きを長く
    let chordGain: Float = 0.06

    // MARK: - Data Structures

    struct BassChordBar {
        let bar: Int           // 1-indexed
        let bassFreq: Float
        let chordFreqs: [Float]
    }

    // MARK: - Melody Data (external)

    let melodyNotes = GymnopedieMelodyData.melodyNotes

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
                bassFreq = F.E3
                chordFreqs = [F.B3, F.D4]
            // E5 持続部分
            case 19, 20, 21:
                bassFreq = F.E3
                chordFreqs = [F.B3, F.D4]
            // Default pattern
            default:
                if bar % 2 == 1 {
                    bassFreq = F.G3
                    chordFreqs = [F.B3, F.D4]
                } else {
                    bassFreq = F.D3
                    chordFreqs = [F.A3, F.C_4]
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

                // Bar 39のみ余韻を長く（真のクライマックス）
                let isClimax = note.startBar >= climaxBar
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
                        let maxFreq: Float = F.E6
                        let minFreq: Float = 600.0
                        let reductionRatio = min(1.0, (note.freq - minFreq) / (maxFreq - minFreq))
                        // 最高音域で最大35%の減衰（20% → 35%に強化）
                        let highFreqReduction = 1.0 - reductionRatio * 0.35
                        effectiveGain *= highFreqReduction
                    }
                }

                var env = SignalEnvelopeUtils.smoothEnvelope(
                    t: dt,
                    duration: noteDur,
                    attack: melodyAttack,
                    decay: effectiveDecay
                )

                // フェードアウト: 長い持続音の後半で徐々に音量を下げる
                // 50%地点から開始し、終点で30%まで減衰（自然な消え方）
                if note.fadeOut {
                    let progress = dt / noteDur  // 0.0 ~ 1.0
                    if progress > 0.5 {
                        // 0.5→1.0 の進行を 0.0→1.0 にマッピング
                        let fadeProgress = (progress - 0.5) * 2.0
                        // 1.0 → 0.3 へ滑らかに減衰（コサインカーブ）
                        let fadeMultiplier = 0.3 + 0.7 * (1.0 + cos(fadeProgress * .pi)) / 2.0
                        env *= fadeMultiplier
                    }
                }

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

                // デチューン・レイヤー適用: 各音を3レイヤーで重ねる
                // 2音 × 3レイヤー = 6音になるため、平均化で音量バランスを維持
                var chordVal: Float = 0
                for freq in data.chordFreqs {
                    let v1 = SignalEnvelopeUtils.pureSine(frequency: freq, t: t)
                    let v2 = SignalEnvelopeUtils.pureSine(frequency: freq + detuneHz, t: t)
                    let v3 = SignalEnvelopeUtils.pureSine(frequency: freq - detuneHz, t: t)
                    chordVal += (v1 + v2 + v3) / 3.0
                }
                chordVal /= Float(data.chordFreqs.count)

                output += chordVal * env * chordGain
            }
        }

        return output
    }
}
