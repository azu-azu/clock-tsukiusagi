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
    case windChime          // 癒しチャイム
    case tibetanBowl        // チベタンボウル風
    case oceanWaves         // 波の音
    case oceanWavesSeagulls // 波 + 海鳥
    case cracklingFire      // 焚き火の音

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
        case .windChime:
            return "癒しチャイム"
        case .tibetanBowl:
            return "チベタンボウル"
        case .oceanWaves:
            return "波の音"
        case .oceanWavesSeagulls:
            return "波 + 海鳥"
        case .cracklingFire:
            return "焚き火の音"
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
        public static let attackTime: Double = 0.01

        /// エンベロープ - ディケイ時間
        public static let decayTime: Double = 3.0

        /// エンベロープ - サステインレベル
        public static let sustainLevel: Double = 0.0

        /// エンベロープ - リリース時間
        public static let releaseTime: Double = 1.0
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
        public static let vibratoDepth: Double = 0.02
    }

    // MARK: - Ocean Waves（波の音）

    /// 波の音プリセット設定
    public struct OceanWaves {
        /// ベースノイズ音量
        public static let noiseAmplitude: Float = 0.3

        /// LFO周波数（波の強弱周期）
        public static let lfoFrequency: Double = 0.2  // 5秒周期

        /// LFO深さ
        public static let lfoDepth: Double = 0.8

        /// LFO最小値（音量）
        public static let lfoMinimum: Double = 0.1

        /// LFO最大値（音量）
        public static let lfoMaximum: Double = 0.6
    }

    // MARK: - Ocean Waves + Seagulls（波 + 海鳥）

    /// 波 + 海鳥プリセット設定
    public struct OceanWavesSeagulls {
        /// 波ノイズ音量
        public static let noiseAmplitude: Float = 0.3

        /// 波の周期（穏やかに）
        public static let lfoFrequency: Double = 0.18

        /// LFO最小値
        public static let lfoMinimum: Double = 0.1

        /// LFO最大値
        public static let lfoMaximum: Double = 0.6

        /// 海鳥チャープ音量
        public static let birdAmplitude: Double = 0.22

        /// チャープ間隔（最小）
        public static let birdMinInterval: Double = 4.0

        /// チャープ間隔（最大）
        public static let birdMaxInterval: Double = 11.0

        /// チャープ持続時間（最小）
        public static let birdMinDuration: Double = 0.25

        /// チャープ持続時間（最大）
        public static let birdMaxDuration: Double = 0.55

        /// チャープの周波数帯（カモメ風）
        public static let birdFrequencyRange: ClosedRange<Double> = 1700.0...3200.0

        /// 同時発音数
        public static let maxConcurrentChirps: Int = 3
    }

    // MARK: - Crackling Fire（焚き火の音）

    /// 焚き火の音プリセット設定
    public struct CracklingFire {
        /// ベースノイズ音量
        public static let baseAmplitude: Float = 0.25

        /// パルス音量
        public static let pulseAmplitude: Float = 0.6

        /// パルス最小間隔
        public static let pulseMinInterval: Double = 0.5

        /// パルス最大間隔
        public static let pulseMaxInterval: Double = 3.0

        /// パルス最小持続時間
        public static let pulseMinDuration: Double = 0.01

        /// パルス最大持続時間
        public static let pulseMaxDuration: Double = 0.05
    }
}
