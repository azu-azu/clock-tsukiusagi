//
//  CathedralStillnessSignal.swift
//  TsukiSound
//
//  大聖堂の静寂 - 和音ドローンオルガン
//  Signal-based implementation with chord harmony and slow LFO breathing
//
//  ## セクション対応
//  JupiterTimingを参照し、楽曲の進行に合わせて音色が変化
//  - Section 0 (Bar 1-4): 超薄いドローン（-16dB相当）で「無重力の静けさ」
//  - Section 1 (Bar 5-8): オルガンドローンがフェードイン
//  - Section 2: オルガンドローン（通常）
//  - Section 3-4: オルガンドローン（厚み増加）
//  - Section 5: クライマックス → 終盤でSection 0レベルへフェードダウン
//

import Foundation

/// Cathedral Stillness: Ambient organ drone with chord harmony
///
/// 特徴：
/// - Section 0: 超薄いドローン（-16dB相当）- メロディが前に出つつ伴奏は存在
/// - Section 1: オルガンドローンがフェードイン
/// - Section 2以降: 和音（C + G の完全5度）で厚みのある響き
/// - 超低速LFO（0.02Hz）で音量がゆっくり呼吸するように変化
/// - ループ時: クライマックス→導入が薄い伴奏で自然に繋がる
public struct CathedralStillnessSignal {

    /// Create Cathedral Stillness signal
    /// - Returns: Signal generating ambient organ drone
    public static func makeSignal() -> Signal {
        // === Organ Drone 設定 ===
        let organRootFreq: Float = 130.81   // C3
        let organFifthFreq: Float = 196.00  // G3

        // LFO設定: 超低速の呼吸（50秒で1周期）
        let lfoFrequency: Float = 0.02  // Hz

        // Section 0 の薄いドローン: -16dB ≈ 0.16 (10^(-16/20))
        // 通常の gain 1.0 に対して 0.16 倍
        let section0Gain: Float = 0.16

        return Signal { t in
            let section = JupiterTiming.currentSection(at: t)

            // LFOで音量を 0.4 〜 0.8 の範囲でゆっくり変化
            let lfoPhase = 2.0 * Float.pi * lfoFrequency * t
            let lfoValue = 0.6 + 0.2 * sin(lfoPhase)

            // === Section 0: 超薄いドローン（-16dB相当）===
            // メロディが前に出つつ、伴奏の存在感を維持
            if section == 0 {
                return generateOrganDrone(t: t, rootFreq: organRootFreq, fifthFreq: organFifthFreq, lfoValue: lfoValue, gain: section0Gain)
            }

            // === Section 1: Section 0レベルから通常レベルへフェードイン ===
            if section == 1 {
                let progress = JupiterTiming.sectionProgress(at: t)
                // section0Gain → 1.0 へスムーズに遷移
                let gain = section0Gain + (1.0 - section0Gain) * progress
                return generateOrganDrone(t: t, rootFreq: organRootFreq, fifthFreq: organFifthFreq, lfoValue: lfoValue, gain: gain)
            }

            // === Section 2: オルガンドローン（通常）===
            if section == 2 {
                return generateOrganDrone(t: t, rootFreq: organRootFreq, fifthFreq: organFifthFreq, lfoValue: lfoValue, gain: 1.0)
            }

            // === Section 3-4: オルガンドローン（厚み増加）===
            if section == 3 || section == 4 {
                return generateOrganDrone(t: t, rootFreq: organRootFreq, fifthFreq: organFifthFreq, lfoValue: lfoValue, gain: 1.4)
            }

            // === Section 5: クライマックス → Section 0レベルへフェードダウン ===
            let sectionProgress = JupiterTiming.sectionProgress(at: t)
            let climaxGain: Float
            if sectionProgress < 0.8 {
                // 前半80%はクライマックス（gain 1.7）
                climaxGain = 1.7
            } else {
                // 後半20%で Section 0 レベル（0.16）へフェードダウン
                let fadeProgress = (sectionProgress - 0.8) / 0.2
                let c = cos(fadeProgress * Float.pi * 0.5)
                // 1.7 → section0Gain へ cos² でスムーズに遷移
                climaxGain = section0Gain + (1.7 - section0Gain) * c * c
            }
            return generateOrganDrone(t: t, rootFreq: organRootFreq, fifthFreq: organFifthFreq, lfoValue: lfoValue, gain: climaxGain)
        }
    }

    /// オルガンドローン生成（C3 + G3 の完全5度）
    /// - Parameters:
    ///   - gain: セクションに応じた音量倍率（Section 3以降は厚みを増す）
    private static func generateOrganDrone(t: Float, rootFreq: Float, fifthFreq: Float, lfoValue: Float, gain: Float) -> Float {
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

        return value * lfoValue * 0.12 * gain
    }
}
