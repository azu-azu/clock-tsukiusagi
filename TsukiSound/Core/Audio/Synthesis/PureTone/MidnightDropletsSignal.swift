//
//  MidnightDropletsSignal.swift
//  TsukiSound
//
//  深夜の雫 - アルペジオハープ
//  Signal-based implementation with ascending arpeggio patterns
//

import Foundation

/// Midnight Droplets: Sparse arpeggio harp with pentatonic scale
///
/// 特徴：
/// - 2〜4音の上昇アルペジオパターン
/// - ペンタトニックスケール（C4, D4, E4, G4, A4）
/// - 6〜15秒のランダム間隔で稀に鳴る
/// - 各音は2〜3秒の exponential decay
/// - 音と音の間隔は100〜150ms
public struct MidnightDropletsSignal {

    /// Create Midnight Droplets signal
    /// - Returns: Signal generating sparse arpeggio harp
    public static func makeSignal() -> Signal {
        // ペンタトニックスケール（C5ベース）
        // Jupiterメロディ（E4〜E6）の上に逃がして透明感を保つ
        let scale: [Float] = [
            523.25,  // C5
            587.33,  // D5
            659.25,  // E5
            783.99,  // G5
            880.00   // A5
        ]

        // 次のアルペジオまでの間隔設定
        let minInterval: Float = 6.0    // 最短6秒
        let maxInterval: Float = 15.0   // 最長15秒

        // 各音の減衰時間
        let noteDecay: Float = 5.0      // 5.0秒で減衰（長い余韻）
        let fadeOutStart: Float = 4.2   // 4.2秒からさらにフェードアウト開始

        // 全体音量（かすかに鳴る程度）
        let masterGain: Float = 0.02

        // アルペジオ内の音の間隔
        let noteSpacing: Float = 0.12   // 120ms

        return Signal { t in
            // シード値を時間ベースで生成（安定したランダム性）
            let arpeggioIndex = Int(t / minInterval)

            // この時点でのランダムシード
            var randomState = UInt64(arpeggioIndex * 7919)  // 素数でシード

            // 次のアルペジオ開始時刻を計算
            func nextRandom() -> Float {
                randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
                return Float(randomState % 10000) / 10000.0
            }

            let randomOffset = nextRandom() * (maxInterval - minInterval)
            let arpeggioStartTime = Float(arpeggioIndex) * minInterval + randomOffset

            // このアルペジオがまだ始まっていない場合は無音
            guard t >= arpeggioStartTime else {
                return 0.0
            }

            // アルペジオからの経過時間
            let timeSinceArpeggio = t - arpeggioStartTime

            // アルペジオ全体の長さを超えたら無音
            let maxArpeggioLength = Float(4) * noteSpacing + noteDecay
            guard timeSinceArpeggio < maxArpeggioLength else {
                return 0.0
            }

            // アルペジオの音数を決定（2〜4音）
            randomState = UInt64(arpeggioIndex * 7919)  // リセット
            _ = nextRandom()  // 間隔計算で使った分を進める
            let numNotes = 2 + Int(nextRandom() * 3.0)  // 2, 3, or 4

            // 開始音のインデックスを決定（上昇パターンが収まる範囲）
            let maxStartIndex = scale.count - numNotes
            let startIndex = Int(nextRandom() * Float(maxStartIndex + 1))

            var value: Float = 0.0

            // アルペジオの各音を生成
            for noteOffset in 0..<numNotes {
                let noteStartTime = Float(noteOffset) * noteSpacing
                let timeSinceNote = timeSinceArpeggio - noteStartTime

                // この音がまだ始まっていない、または減衰し終わった場合はスキップ
                guard timeSinceNote >= 0.0 && timeSinceNote < noteDecay else {
                    continue
                }

                // 音の周波数（上昇アルペジオ）
                let freq = scale[startIndex + noteOffset]

                // 倍音合成（ハープらしい倍音構造、豊かな響き）
                let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0]
                let amps: [Float] = [1.0, 0.5, 0.3, 0.15]

                // エンベロープ（exponential decay）
                let envelope = exp(-timeSinceNote / noteDecay)

                // 最後の部分でさらにフェードアウト（プツッと切れないように）
                let finalFade: Float
                if timeSinceNote > fadeOutStart {
                    let fadeProgress = (timeSinceNote - fadeOutStart) / (noteDecay - fadeOutStart)
                    finalFade = 1.0 - fadeProgress  // 線形フェードアウト
                } else {
                    finalFade = 1.0
                }

                var noteValue: Float = 0.0
                for i in 0..<harmonics.count {
                    let harmFreq = freq * harmonics[i]
                    let phase = 2.0 * Float.pi * harmFreq * t
                    noteValue += amps[i] * sin(phase)
                }

                value += noteValue * envelope * finalFade
            }

            return value * masterGain
        }
    }
}
