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
    /// Azu設計: ピンクノイズ + 低周波ドローン + 呼吸LFO
    /// 構成: ピンクノイズ（ベース）+ 低周波ドローン（150-200 Hz）
    public struct ComfortRelax {
        // ノイズ床（ピンク、LPF 2kHz）
        public static let noiseType: NoiseType = .pink
        public static let noiseAmplitude: Double = 0.06  // -24 dB
        public static let noiseLowpassCutoff: Float = 2000.0  // 2 kHz LPF
        public static let noiseLFOFrequency: Double = 0.15  // 0.1-0.3 Hz（呼吸感）
        public static let noiseLFODepth: Double = 0.20  // ±20%

        // 低周波ドローン（150-200 Hz、芯）
        public static let droneFrequencies: [Double] = [165.0, 196.0]  // E3 + G3（低め）
        public static let droneDetuneCents: Double = 2.0  // ±2 cents
        public static let droneAmplitude: Double = 0.0316  // -30 dB
        public static let droneLFOFrequency: Double = 0.08  // ゆっくり

        // 空間（控えめ）
        public static let reverbWetDryMix: Float = 12.0  // Wet 0.12（10-15%）
        public static let reverbPreDelay: Double = 0.015  // 15 ms
    }
}
