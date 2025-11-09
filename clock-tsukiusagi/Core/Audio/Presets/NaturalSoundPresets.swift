//
//  NaturalSoundPresets.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  自然音プリセット（波/焚き火/ボウル/チャイム/心地よい音）
//

import Foundation

/// 自然音プリセット
public enum NaturalSoundPreset {
    case comfortRelax       // Comfort Pack Relax（最小構成・リラックス）
}

/// 自然音プリセットの設定
public struct NaturalSoundPresets {
    // MARK: - Comfort Pack Relax（最小構成）

    /// Comfort Pack Relax プリセット設定
    /// Azu設計: マウスクリック・マスキング用
    /// 構成: ピンクノイズ（ベース）+ バンドパスノイズ（高域マスキング）
    public struct ComfortRelax {
        // ベースノイズ（ピンク、HPF+LPFで帯域制限）
        public static let baseNoiseType: NoiseType = .pink
        public static let baseNoiseAmplitude: Double = 0.063  // -24 dB
        public static let baseHighpassCutoff: Float = 1200.0  // 1.2 kHz HPF
        public static let baseLowpassCutoff: Float = 9000.0   // 9 kHz LPF
        public static let baseNoiseLFOFrequency: Double = 0.10
        public static let baseNoiseLFODepth: Double = 0.15

        // マスキング用バンドパスノイズ（高域）
        public static let maskNoiseType: NoiseType = .pink
        public static let maskNoiseAmplitude: Double = 0.032  // -30 dB
        public static let maskBandpassCenter: Float = 4500.0  // 4.5 kHz中心
        public static let maskBandpassQ: Float = 1.0          // Q値
        public static let maskNoiseLFOFrequency: Double = 0.03  // ほぼ揺らさない

        // 空間（最小限）
        public static let reverbWetDryMix: Float = 8.0  // Wet 0.08
        public static let reverbPreDelay: Double = 0.012  // 12 ms

        // マスター（歪み防止）
        public static let masterAttenuation: Double = 0.35  // -9 dB
    }
}
