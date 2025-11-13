//
//  NaturalSoundPresets.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  自然音プリセット（波/焚き火/ボウル/チャイム/心地よい音）
//

import Foundation

/// 自然音プリセット
public enum NaturalSoundPreset: String, CaseIterable, Identifiable {
    case clickSuppression   // クリック音防止（最小構成・リラックス）
    case pinkNoise          // ピンクノイズ（Focus向け）
    case brownNoise         // ブラウンノイズ（Sleep向け）
    case pleasantDrone      // 心地よいドローン（浮遊感）
    case pleasantWarm       // 心地よい音（温かい）
    case pleasantCalm       // 心地よい音（穏やか）
    case pleasantDeep       // 心地よい音（深い）
    case ambientFocus       // Endel風 Focus（集中・前向き）
    case ambientRelax       // Endel風 Relax（落ち着く・緩む）
    case ambientSleep       // Endel風 Sleep（眠る・静寂）

    public var id: String { rawValue }

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .clickSuppression:
            return "クリック音防止"
        case .pinkNoise:
            return "ピンクノイズ"
        case .brownNoise:
            return "ブラウンノイズ"
        case .pleasantDrone:
            return "心地よいドローン"
        case .pleasantWarm:
            return "心地よい音（温かい）"
        case .pleasantCalm:
            return "心地よい音（穏やか）"
        case .pleasantDeep:
            return "心地よい音（深い）"
        case .ambientFocus:
            return "集中モード (Focus)"
        case .ambientRelax:
            return "リラックスモード (Relax)"
        case .ambientSleep:
            return "睡眠モード (Sleep)"
        }
    }
}

/// 自然音プリセットの設定
public struct NaturalSoundPresets {
    // MARK: - クリック音防止（最小構成）

    /// クリック音防止プリセット設定
    /// Azu設計: ピンクノイズ + 低周波ドローン + 呼吸LFO
    /// 構成: ピンクノイズ（ベース）+ 低周波ドローン（150-200 Hz）
    public struct ClickSuppression {
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

    // MARK: - Pink Noise（ピンクノイズ - Focus向け）

    /// ピンクノイズプリセット設定
    /// Fujiko設計: Focus向け - サーッと締まる、思考が冴える
    public struct PinkNoise {
        public static let amplitude: Double = 0.15
    }

    // MARK: - Brown Noise（ブラウンノイズ - Sleep向け）

    /// ブラウンノイズプリセット設定
    /// Fujiko設計: Sleep向け - 低域中心、胎内音に近い
    public struct BrownNoise {
        public static let amplitude: Double = 0.12
    }

    // MARK: - Pleasant Drone（心地よいドローン）

    /// 心地よいドローンプリセット設定
    /// Fujiko設計原則: 和音 + LFO変調で「呼吸する」音を生成
    public struct PleasantDrone {
        /// 根音の周波数
        public static let rootFrequency: Double = 196.0  // G3

        /// コードタイプ（デフォルト: sus4で浮遊感）
        public static let chordType: ChordType = .sus4

        /// 音量
        public static let amplitude: Double = 0.22

        /// 音量LFO周波数（呼吸のリズム）
        public static let amplitudeLFOFrequency: Double = 0.15  // 約6.7秒周期

        /// ピッチLFO周波数（微細な揺らぎ）
        public static let pitchLFOFrequency: Double = 0.5

        /// ピッチLFO深さ（Hz）
        public static let pitchLFODepth: Double = 2.0

        /// ノイズ混入量
        public static let noiseLevel: Double = 0.015
    }

    // MARK: - Pleasant Warm（心地よい音 - 温かい）

    /// 心地よい音（温かい）プリセット設定
    /// Fujiko設計原則: デチューンされた複数オシレータで柔らかい音を生成
    public struct PleasantWarm {
        /// 基準周波数
        public static let baseFrequency: Double = 174.0  // F3（低めで温かい）

        /// デチューン量（Hz）
        public static let detuneAmount: Double = 3.0

        /// オシレータ数
        public static let oscillatorCount: Int = 3

        /// 音量
        public static let amplitude: Double = 0.28

        /// ノイズ混入量（空気感）
        public static let noiseLevel: Double = 0.02
    }

    // MARK: - Pleasant Calm（心地よい音 - 穏やか）

    /// 心地よい音（穏やか）プリセット設定
    public struct PleasantCalm {
        /// 基準周波数
        public static let baseFrequency: Double = 261.6  // C4（中間的）

        /// デチューン量（Hz）
        public static let detuneAmount: Double = 2.5

        /// オシレータ数
        public static let oscillatorCount: Int = 3

        /// 音量
        public static let amplitude: Double = 0.25

        /// ノイズ混入量
        public static let noiseLevel: Double = 0.015
    }

    // MARK: - Pleasant Deep（心地よい音 - 深い）

    /// 心地よい音（深い）プリセット設定
    public struct PleasantDeep {
        /// 基準周波数
        public static let baseFrequency: Double = 110.0  // A2（低音）

        /// デチューン量（Hz）
        public static let detuneAmount: Double = 4.0

        /// オシレータ数
        public static let oscillatorCount: Int = 3

        /// 音量
        public static let amplitude: Double = 0.32

        /// ノイズ混入量
        public static let noiseLevel: Double = 0.025
    }

    // MARK: - Ambient Focus（Endel風 Focus）

    /// Endel風 Focus プリセット設定
    /// Fujiko設計: 集中・前向き - サーッと締まる、思考が冴える
    public struct AmbientFocus {
        /// ノイズタイプ（ピンクノイズ）
        public static let noiseType: NoiseType = .pink

        /// ノイズ音量
        public static let noiseAmplitude: Double = 0.11

        /// サイン波周波数（明るくて集中感）
        public static let sineFrequencies: [Double] = [330.0, 495.0]

        /// サイン波音量（dB: -28）
        public static let sineAmplitude: Double = 0.04

        /// デチューン量
        public static let detuneAmount: Double = 2.0

        /// 音量LFO周波数（呼吸より少し速い）
        public static let lfoAmplitudeFrequency: Double = 0.25

        /// 音量LFO深さ
        public static let lfoAmplitudeDepth: Double = 0.2
    }

    // MARK: - Ambient Relax（Endel風 Relax）

    /// Endel風 Relax プリセット設定
    /// Fujiko設計: 落ち着く・緩む - 柔らかく包まれる感じ
    public struct AmbientRelax {
        /// ノイズタイプ（ホワイトノイズ）
        public static let noiseType: NoiseType = .white

        /// ノイズ音量
        public static let noiseAmplitude: Double = 0.10

        /// サイン波周波数（心拍に近くて安定）
        public static let sineFrequencies: [Double] = [220.0]

        /// サイン波音量（dB: -30）
        public static let sineAmplitude: Double = 0.032

        /// デチューン量
        public static let detuneAmount: Double = 2.0

        /// 音量LFO周波数（ゆっくり）
        public static let lfoAmplitudeFrequency: Double = 0.10

        /// 音量LFO深さ
        public static let lfoAmplitudeDepth: Double = 0.2
    }

    // MARK: - Ambient Sleep（Endel風 Sleep）

    /// Endel風 Sleep プリセット設定
    /// Fujiko設計: 眠る・静寂 - 低域中心、胎内音に近い
    public struct AmbientSleep {
        /// ノイズタイプ（ブラウンノイズ）
        public static let noiseType: NoiseType = .brown

        /// ノイズ音量
        public static let noiseAmplitude: Double = 0.08

        /// サイン波周波数（なし、または超低域）
        public static let sineFrequencies: [Double] = []

        /// サイン波音量（dB: -32）
        public static let sineAmplitude: Double = 0.025

        /// デチューン量
        public static let detuneAmount: Double = 1.5

        /// 音量LFO周波数（超ゆっくり）
        public static let lfoAmplitudeFrequency: Double = 0.05

        /// 音量LFO深さ
        public static let lfoAmplitudeDepth: Double = 0.15
    }
}
