//
//  NaturalSoundPresets.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  自然音プリセット（波/焚き火/ボウル/チャイム）
//

import Foundation

/// 自然音プリセット
public enum NaturalSoundPreset {
    case oceanWaves         // 波の音
    case cracklingFire      // 焚き火の音
    case tibetanBowl        // チベタンボウル風
    case windChime          // 癒しチャイム
}

/// 自然音プリセットの設定
public struct NaturalSoundPresets {
    // MARK: - Ocean Waves（波の音）

    /// 波の音プリセット設定
    public struct OceanWaves {
        /// ベースノイズ音量
        public static let noiseAmplitude: Float = 0.3

        /// ローパスフィルタカットオフ周波数
        public static let lowpassCutoff: Float = 800.0

        /// ローパスフィルタQ値
        public static let lowpassQ: Float = 0.7

        /// LFO周波数（波の強弱周期）
        public static let lfoFrequency: Double = 0.2  // 5秒周期

        /// LFO深さ
        public static let lfoDepth: Double = 0.8

        /// LFO最小値（音量）
        public static let lfoMinimum: Double = 0.1

        /// LFO最大値（音量）
        public static let lfoMaximum: Double = 0.6

        /// リバーブWet/Dry
        public static let reverbWetDryMix: Float = 30.0
    }

    // MARK: - Crackling Fire（焚き火の音）

    /// 焚き火の音プリセット設定
    public struct CracklingFire {
        /// ベースノイズ中心周波数
        public static let baseCenterFrequency: Float = 300.0

        /// ベースノイズ帯域幅
        public static let baseBandwidth: Float = 1.5

        /// ベースノイズ音量
        public static let baseAmplitude: Float = 0.25

        /// パルス音量
        public static let pulseAmplitude: Float = 0.6

        /// パルス最小持続時間
        public static let pulseMinDuration: Double = 0.01

        /// パルス最大持続時間
        public static let pulseMaxDuration: Double = 0.05

        /// パルス最小間隔
        public static let pulseMinInterval: Double = 0.5

        /// パルス最大間隔
        public static let pulseMaxInterval: Double = 3.0

        /// リバーブWet/Dry
        public static let reverbWetDryMix: Float = 15.0
    }

    // MARK: - Tibetan Bowl（チベタンボウル風）

    /// チベタンボウル風プリセット設定
    public struct TibetanBowl {
        /// 基音の周波数
        public static let fundamentalFrequency: Double = 220.0  // A3

        /// 全体の音量
        public static let amplitude: Double = 0.2

        /// 倍音構造
        public static let harmonics: [Harmonic] = [
            Harmonic(multiplier: 1.0, amplitude: 1.0),   // 基音
            Harmonic(multiplier: 2.0, amplitude: 0.7),   // 2倍音
            Harmonic(multiplier: 3.0, amplitude: 0.5),   // 3倍音
            Harmonic(multiplier: 4.0, amplitude: 0.3),   // 4倍音
            Harmonic(multiplier: 5.0, amplitude: 0.2)    // 5倍音
        ]

        /// ビブラートLFO周波数
        public static let vibratoFrequency: Double = 5.0

        /// ビブラート深さ（周波数変調）
        public static let vibratoDepth: Double = 0.02  // 2%

        /// エンベロープ - アタック時間
        public static let attackTime: Double = 0.5

        /// エンベロープ - ディケイ時間
        public static let decayTime: Double = 10.0

        /// エンベロープ - サステインレベル
        public static let sustainLevel: Double = 0.3

        /// エンベロープ - リリース時間
        public static let releaseTime: Double = 3.0

        /// リバーブWet/Dry
        public static let reverbWetDryMix: Float = 50.0
    }

    // MARK: - Wind Chime（癒しチャイム）

    /// 癒しチャイムプリセット設定
    public struct WindChime {
        /// ペンタトニックスケールの周波数（Hz）
        public static let frequencies: [Double] = [
            1047.0,  // C6
            1175.0,  // D6
            1319.0,  // E6
            1568.0,  // G6
            1760.0,  // A6
            2093.0   // C7
        ]

        /// 音量
        public static let amplitude: Double = 0.3

        /// ランダムトリガー最小間隔
        public static let minInterval: Double = 2.0

        /// ランダムトリガー最大間隔
        public static let maxInterval: Double = 8.0

        /// エンベロープ - アタック時間
        public static let attackTime: Double = 0.01  // 瞬時

        /// エンベロープ - ディケイ時間
        public static let decayTime: Double = 3.0

        /// エンベロープ - サステインレベル
        public static let sustainLevel: Double = 0.0  // すぐに減衰

        /// エンベロープ - リリース時間
        public static let releaseTime: Double = 1.0

        /// リバーブWet/Dry
        public static let reverbWetDryMix: Float = 60.0
    }
}
