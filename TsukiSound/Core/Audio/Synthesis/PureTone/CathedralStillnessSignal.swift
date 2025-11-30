//
//  CathedralStillnessSignal.swift
//  TsukiSound
//
//  大聖堂の静寂 - 和音ドローンオルガン
//  Signal-based implementation with chord harmony and slow LFO breathing
//

import Foundation

/// Cathedral Stillness: Ambient organ drone with chord harmony
///
/// 特徴：
/// - 和音（C + G の完全5度）で厚みのある響き
/// - 超低速LFO（0.02Hz）で音量がゆっくり呼吸するように変化
/// - 4倍音までの加算合成で透明な音色
/// - ほぼ静止したドローンとして機能
public struct CathedralStillnessSignal {

    /// Create Cathedral Stillness signal
    /// - Returns: Signal generating ambient organ drone
    public static func makeSignal() -> Signal {
        // 和音設定: C3 + G3（完全5度）
        let rootFreq: Float = 130.81   // C3
        let fifthFreq: Float = 196.00  // G3

        // LFO設定: 超低速の呼吸（50秒で1周期）
        let lfoFrequency: Float = 0.02  // Hz

        return Signal { t in
            // LFOで音量を 0.4 〜 0.8 の範囲でゆっくり変化
            let lfoPhase = 2.0 * Float.pi * lfoFrequency * t
            let lfoValue = 0.6 + 0.2 * sin(lfoPhase)  // 0.4 〜 0.8

            // 倍音設定（Jupiterメロディとの干渉を避けるため、2倍音以上を大幅カット）
            // C3の4倍音(523Hz)がC5、G3の2倍音(392Hz)がG4と干渉するため
            let harmonics: [Float] = [1.0, 2.0]
            let amps: [Float] = [1.0, 0.15]

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

            // LFOで音量変調
            return value * lfoValue * 0.12  // 全体音量は控えめ
        }
    }
}
