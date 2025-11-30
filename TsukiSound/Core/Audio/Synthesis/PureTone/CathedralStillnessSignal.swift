//
//  CathedralStillnessSignal.swift
//  TsukiSound
//
//  大聖堂の静寂 - 和音ドローンオルガン
//  Signal-based implementation with chord harmony and slow LFO breathing
//
//  ## セクション対応
//  JupiterTimingを参照し、楽曲の進行に合わせてフェードイン
//  - Section 0 (Bar 1-4): 無音（アカペラ風）
//  - Section 1 (Bar 5-8): フェードイン開始
//  - Section 2以降: フル音量
//

import Foundation

/// Cathedral Stillness: Ambient organ drone with chord harmony
///
/// 特徴：
/// - 和音（C + G の完全5度）で厚みのある響き
/// - 超低速LFO（0.02Hz）で音量がゆっくり呼吸するように変化
/// - 2倍音までの加算合成（Jupiterメロディとの干渉を避けるため）
/// - Jupiterの進行に合わせて段階的にフェードイン
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
            // セクションベースのゲイン計算
            let section = JupiterTiming.currentSection(at: t)
            let sectionProgress = JupiterTiming.sectionProgress(at: t)

            // Section 0: 無音（アカペラ風）
            // Section 1: フェードイン（0→1）
            // Section 2以降: フル音量
            let sectionGain: Float
            switch section {
            case 0:
                sectionGain = 0.0
            case 1:
                // スムーズなフェードイン（cos²カーブ）
                let fadeProgress = sectionProgress
                let c = cos((1.0 - fadeProgress) * Float.pi * 0.5)
                sectionGain = c * c
            default:
                sectionGain = 1.0
            }

            // 無音なら早期リターン
            guard sectionGain > 0.001 else { return 0.0 }

            // LFOで音量を 0.4 〜 0.8 の範囲でゆっくり変化
            let lfoPhase = 2.0 * Float.pi * lfoFrequency * t
            let lfoValue = 0.6 + 0.2 * sin(lfoPhase)  // 0.4 〜 0.8

            // 倍音設定（Jupiterメロディとの干渉を避けるため、2倍音以上を大幅カット）
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

            // LFOで音量変調 + セクションゲイン適用
            return value * lfoValue * 0.12 * sectionGain
        }
    }
}
