//
//  CathedralStillnessSignal.swift
//  TsukiSound
//
//  大聖堂の静寂 - 和音ドローンオルガン
//  Signal-based implementation with chord harmony and slow LFO breathing
//
//  ## 「ボワーン」がぐるぐる回る仕組み
//  - LFOが音量を0.4〜0.8で呼吸させる（50秒周期）
//  - メロディとは無関係に回り続ける
//  - セクションで全体ボリュームだけ調整（ちょっとずつ聞こえてくる）
//

import Foundation

/// Cathedral Stillness: Ambient organ drone with chord harmony
///
/// 特徴：
/// - 和音（C + G の完全5度）で厚みのある響き
/// - 超低速LFO（0.02Hz = 50秒周期）で音量がゆっくり呼吸
/// - 4倍音までの加算合成で「ボワーン」という透明な音色
/// - Section 0から徐々に聞こえてきて、いつの間にか厚くなる
public struct CathedralStillnessSignal {

    /// Create Cathedral Stillness signal
    /// - Returns: Signal generating ambient organ drone
    public static func makeSignal() -> Signal {
        // 和音設定: C3 + G3（完全5度）
        let rootFreq: Float = 130.81   // C3
        let fifthFreq: Float = 196.00  // G3

        // LFO設定: 超低速の呼吸（50秒で1周期）
        let lfoFrequency: Float = 0.02  // Hz

        // セクションごとの全体ボリューム（LFOの「ボワーン」はそのまま）
        let section0Volume: Float = 0.3   // 控えめに聞こえる
        let section2Volume: Float = 1.0   // フル

        return Signal { t in
            let section = JupiterTiming.currentSection(at: t)
            let sectionProgress = JupiterTiming.sectionProgress(at: t)

            // LFOで音量を 0.4 〜 0.8 の範囲でゆっくり変化（ぐるぐる）
            let lfoPhase = 2.0 * Float.pi * lfoFrequency * t
            let lfoValue = 0.6 + 0.2 * sin(lfoPhase)

            // セクションに応じた全体ボリューム（ちょっとずつ聞こえてくる）
            let volume: Float
            switch section {
            case 0:
                // 控えめに聞こえる
                volume = section0Volume
            case 1:
                // ちょっとずつ聞こえてくる
                volume = section0Volume + (section2Volume - section0Volume) * sectionProgress
            default:
                // フルで鳴る
                volume = section2Volume
            }

            // 倍音設定（オルガンらしい柔らかめ）
            let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0]
            let amps: [Float] = [0.9, 0.4, 0.25, 0.15]

            var value: Float = 0.0

            // Root note (C3) の倍音合成
            for i in 0..<harmonics.count {
                let freq = rootFreq * harmonics[i]
                let phase = 2.0 * Float.pi * freq * t
                value += amps[i] * 0.5 * sin(phase)
            }

            // Fifth note (G3) の倍音合成（少し控えめ）
            for i in 0..<harmonics.count {
                let freq = fifthFreq * harmonics[i]
                let phase = 2.0 * Float.pi * freq * t
                value += amps[i] * 0.35 * sin(phase)
            }

            // LFOで音量変調 × セクションボリューム
            return value * lfoValue * 0.12 * volume
        }
    }
}
