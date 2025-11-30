//
//  CathedralStillnessSignal.swift
//  TsukiSound
//
//  大聖堂の静寂 - 和音ドローンオルガン
//  Signal-based implementation with chord harmony and slow LFO breathing
//
//  ## セクション対応
//  JupiterTimingを参照し、楽曲の進行に合わせて音色が変化
//  - Section 0 (Bar 1-4): 無音（メロディはJupiterSignalでGymnopédie風に演奏）
//  - Section 1 (Bar 5-8): オルガンドローンがフェードイン
//  - Section 2以降: オルガンドローン
//

import Foundation

/// Cathedral Stillness: Ambient organ drone with chord harmony
///
/// 特徴：
/// - Section 0: 無音（JupiterSignalがGymnopédie風ベース音色でメロディを演奏）
/// - Section 1: オルガンドローンがフェードイン
/// - Section 2以降: 和音（C + G の完全5度）で厚みのある響き
/// - 超低速LFO（0.02Hz）で音量がゆっくり呼吸するように変化
public struct CathedralStillnessSignal {

    /// Create Cathedral Stillness signal
    /// - Returns: Signal generating ambient organ drone
    public static func makeSignal() -> Signal {
        // === Organ Drone 設定 ===
        let organRootFreq: Float = 130.81   // C3
        let organFifthFreq: Float = 196.00  // G3

        // LFO設定: 超低速の呼吸（50秒で1周期）
        let lfoFrequency: Float = 0.02  // Hz

        return Signal { t in
            let section = JupiterTiming.currentSection(at: t)
            let sectionProgress = JupiterTiming.sectionProgress(at: t)

            // LFOで音量を 0.4 〜 0.8 の範囲でゆっくり変化
            let lfoPhase = 2.0 * Float.pi * lfoFrequency * t
            let lfoValue = 0.6 + 0.2 * sin(lfoPhase)

            // === Section 0: 無音（メロディはJupiterSignalで処理）===
            if section == 0 {
                return 0.0
            }

            // === Section 1: オルガンドローンのフェードイン ===
            if section == 1 {
                let organFade = sectionProgress
                return generateOrganDrone(t: t, rootFreq: organRootFreq, fifthFreq: organFifthFreq, lfoValue: lfoValue) * organFade
            }

            // === Section 2以降: オルガンドローン ===
            return generateOrganDrone(t: t, rootFreq: organRootFreq, fifthFreq: organFifthFreq, lfoValue: lfoValue)
        }
    }

    /// オルガンドローン生成（C3 + G3 の完全5度）
    private static func generateOrganDrone(t: Float, rootFreq: Float, fifthFreq: Float, lfoValue: Float) -> Float {
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

        return value * lfoValue * 0.12
    }
}
