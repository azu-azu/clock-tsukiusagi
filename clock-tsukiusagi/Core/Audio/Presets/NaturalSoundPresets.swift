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
    case windChime          // 癒しチャイム
    case oceanWavesSeagulls // 波 + 海鳥
    case moonlitSea         // 深夜の海
    case lunarPulse         // 月の脈動
    case darkShark          // 黒いサメの影
    case midnightTrain      // 夜汽車
    case lunarTide          // 月光の潮流
    case abyssalBreath      // 深海の呼吸
    case stardustNoise      // 星屑ノイズ
    case lunarDustStorm     // 月面の砂嵐
    case silentLibrary      // 夜の図書館
    case distantThunder     // 遠雷
    case sinkingMoon        // 沈む月
    case dawnHint           // 朝の気配

    public var id: String { rawValue }

    /// Indicates if this is a test/development preset
    public var isTest: Bool {
        [
            .lunarPulse,
            .stardustNoise,
            .lunarDustStorm,
            .silentLibrary,
            .distantThunder,
            .sinkingMoon,
            .dawnHint
        ].contains(self)
    }

    /// Display name for UI (Japanese with emoji)
    public var displayName: String {
        switch self {
        case .windChime:
            return "癒しチャイム"
        case .oceanWavesSeagulls:
            return "波 + 海鳥"
        case .moonlitSea:
            return "🌊 深夜の海"
        case .lunarPulse:
            return "🌕 月の脈動"
        case .darkShark:
            return "🦈 黒いサメの影"
        case .midnightTrain:
            return "🚂 夜汽車"
        case .lunarTide:
            return "🌙🌊 月光の潮流"
        case .abyssalBreath:
            return "🫧💙 深海の呼吸"
        case .stardustNoise:
            return "✨🌌 星屑ノイズ"
        case .lunarDustStorm:
            return "🌑🌪️ 月面の砂嵐"
        case .silentLibrary:
            return "📚🌙 夜の図書館"
        case .distantThunder:
            return "⚡🌩️ 遠雷"
        case .sinkingMoon:
            return "🌘💫 沈む月"
        case .dawnHint:
            return "🌅✨ 朝の気配"
        }
    }

    /// English title for selected display
    public var englishTitle: String {
        switch self {
        case .windChime:
            return "Wind Chime"
        case .oceanWavesSeagulls:
            return "Ocean Waves + Seagulls"
        case .moonlitSea:
            return "Moonlit Silent Sea"
        case .lunarPulse:
            return "Lunar Pulse"
        case .darkShark:
            return "Dark Shape Underwater"
        case .midnightTrain:
            return "Midnight Train in the Distance"
        case .lunarTide:
            return "Lunar Tide Drift"
        case .abyssalBreath:
            return "Abyssal Breath"
        case .stardustNoise:
            return "Stardust Shimmer"
        case .lunarDustStorm:
            return "Lunar Dust Storm"
        case .silentLibrary:
            return "Midnight Library Stillness"
        case .distantThunder:
            return "Distant Thunder Pulse"
        case .sinkingMoon:
            return "Sinking Moon Fade"
        case .dawnHint:
            return "Dawn Hint Glow"
        }
    }
}

/// 自然音プリセットの設定
public struct NaturalSoundPresets {
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

    // MARK: - Moonlit Sea（深夜の海）

    /// 深夜の海プリセット設定
    /// ピンクノイズ + ゆっくりうねるLFOで深海の呼吸を表現
    public struct MoonlitSea {
        /// ノイズ音量
        public static let noiseAmplitude: Float = 0.4

        /// LFO周波数（深海の呼吸周期）
        public static let lfoFrequency: Double = 0.25

        /// LFO最小値
        public static let lfoMinimum: Double = 0.03

        /// LFO最大値
        public static let lfoMaximum: Double = 0.10
    }

    // MARK: - Lunar Pulse（月の脈動）

    /// 月の脈動プリセット設定
    /// 純音（528Hz）+ 超ゆっくりフェードで光の呼吸を表現
    public struct LunarPulse {
        /// 純音の周波数
        public static let frequency: Double = 528.0

        /// 基本音量
        public static let amplitude: Float = 0.2

        /// LFO周波数（脈動の周期）
        public static let lfoFrequency: Double = 0.06

        /// LFO最小値
        public static let lfoMinimum: Double = 0.02

        /// LFO最大値
        public static let lfoMaximum: Double = 0.12
    }

    // MARK: - Dark Shark（黒いサメの影）

    /// 黒いサメの影プリセット設定
    /// ブラウンノイズ + ランダムLFOで存在の圧を表現
    public struct DarkShark {
        /// ノイズ音量
        public static let noiseAmplitude: Float = 0.4

        /// LFO周波数（ランダムな範囲の中央値）
        public static let lfoFrequency: Double = 0.115

        /// LFO最小値
        public static let lfoMinimum: Double = 0.02

        /// LFO最大値
        public static let lfoMaximum: Double = 0.08
    }

    // MARK: - Midnight Train（夜汽車）

    /// 夜汽車プリセット設定
    /// ブラウンノイズ + 律動LFOでゴトン…ゴトン…を表現
    public struct MidnightTrain {
        /// ノイズ音量
        public static let noiseAmplitude: Float = 0.3

        /// LFO周波数（ガタンゴトンの周期）
        public static let lfoFrequency: Double = 1.0

        /// LFO最小値
        public static let lfoMinimum: Double = 0.03

        /// LFO最大値
        public static let lfoMaximum: Double = 0.12
    }

    // MARK: - Lunar Tide（月光の潮流）

    /// 月光の潮流プリセット設定
    /// ピンクノイズ + きらめき帯域 + LFOで月光の海面を表現
    public struct LunarTide {
        /// ノイズタイプ（ベースはピンク）
        public static let noiseType: NoiseType = .pink

        /// ノイズ音量
        public static let noiseAmplitude: Double = 0.12

        /// 月光の"きらめき"を作る薄いShimmer帯域
        public static let shimmerFrequency: ClosedRange<Double> = 2500.0...4500.0

        /// LFO（海面の微細な揺れ）
        public static let lfoFrequency: Double = 0.18
        public static let lfoDepth: Double = 0.35

        /// ほんの少しの残響
        public static let reverbWetDryMix: Float = 10.0
    }

    // MARK: - Abyssal Breath（深海の呼吸）

    /// 深海の呼吸プリセット設定
    /// ブラウンノイズ + 超低域サイン + LFOで深海生物の気配を表現
    public struct AbyssalBreath {
        /// 深海の暗い層：ブラウンノイズ
        public static let noiseType: NoiseType = .brown

        /// ノイズ音量
        public static let noiseAmplitude: Double = 0.10

        /// 深海生物の"気配"となる超低域サイン
        public static let subSineFrequency: Double = 48.0
        public static let subSineAmplitude: Double = 0.03

        /// 呼吸より遅い振幅LFO
        public static let lfoFrequency: Double = 0.05
        public static let lfoDepth: Double = 0.25
    }

    // MARK: - Stardust Noise（星屑ノイズ）

    /// 星屑ノイズプリセット設定
    /// ホワイトノイズ + 高域帯域抽出 + 微細パルスで星のきらめきを表現
    public struct StardustNoise {
        /// ベースはホワイトノイズ
        public static let noiseType: NoiseType = .white

        /// 星のきらめき帯域を抜き出すBandpass
        public static let sparkleBand: ClosedRange<Double> = 8000.0...12000.0

        /// 星屑の微細パルス
        public static let microBurstMinInterval: Double = 0.4
        public static let microBurstMaxInterval: Double = 1.2
        public static let microBurstAmplitude: Double = 0.12
    }

    // MARK: - Lunar Dust Storm（月面の砂嵐）

    /// 月面の砂嵐プリセット設定
    /// ピンクノイズ + Notch Filter + 静止LFOで虚空の風を表現
    public struct LunarDustStorm {
        /// ピンクノイズ（空気の無い"虚空の風"）
        public static let noiseType: NoiseType = .pink

        /// 音量
        public static let noiseAmplitude: Double = 0.10

        /// 月面のざらつきを作るNotch Filter
        public static let notchFrequency: Double = 750.0
        public static let notchDepth: Double = -12.0  // -12dBカット

        /// ほぼ揺れない静止風
        public static let lfoFrequency: Double = 0.02
        public static let lfoDepth: Double = 0.05
    }

    // MARK: - Silent Library（夜の図書館）

    /// 夜の図書館プリセット設定
    /// ブラウンノイズ + 温かい帯域強調 + 静止LFOで静かな空間を表現
    public struct SilentLibrary {
        /// 静かな空間の空気：ブラウンノイズ
        public static let noiseType: NoiseType = .brown

        /// ノイズ音量
        public static let noiseAmplitude: Double = 0.10

        /// 木の棚の響き帯域を強める
        public static let warmthBand: ClosedRange<Double> = 150.0...300.0
        public static let warmthGain: Double = 1.4  // +40%

        /// 静止感（ほぼLFOなし）
        public static let lfoFrequency: Double = 0.01
        public static let lfoDepth: Double = 0.03
    }

    // MARK: - Distant Thunder Pulse（遠雷）

    /// 遠雷プリセット設定
    /// ブラウンノイズ + 低域パルス + ランダム間隔で遠雷の胸鳴りを表現
    public struct DistantThunderPulse {
        /// ベースはブラウンノイズ
        public static let noiseType: NoiseType = .brown
        public static let noiseAmplitude: Double = 0.15

        /// 遠雷の"胸鳴り"低域
        public static let pulseFrequencyRange: ClosedRange<Double> = 40.0...70.0
        public static let pulseAmplitude: Double = 0.08

        /// ランダムパルスの間隔
        public static let pulseMinInterval: Double = 2.0
        public static let pulseMaxInterval: Double = 7.0
    }

    // MARK: - Sinking Moon（沈む月）

    /// 沈む月プリセット設定
    /// 柔らかいサイン波 + 超低速フェード + 高域減衰で静けさの消失を表現
    public struct SinkingMoon {
        /// 柔らかいサイン波（432Hz）
        public static let sineFrequency: Double = 432.0
        public static let sineAmplitude: Double = 0.06

        /// 月が沈むような超低速フェード
        public static let lfoFrequency: Double = 0.04
        public static let lfoDepth: Double = 0.25

        /// 高域減衰（静けさの消失）
        public static let highFrequencyRollOff: Double = -9.0  // -9dB
    }

    // MARK: - Dawn Hint（朝の気配）

    /// 朝の気配プリセット設定
    /// ピンクノイズ + Shimmer帯域 + 明るく変化するLFOで夜明けの空気を表現
    public struct DawnHint {
        /// 夜の終わりを示す低めのピンクノイズ
        public static let noiseType: NoiseType = .pink
        public static let noiseAmplitude: Double = 0.10

        /// "空気の張り"を作るShimmer帯域
        public static let shimmerFrequency: ClosedRange<Double> = 2000.0...4000.0

        /// 明るく変化していくLFO
        public static let lfoFrequency: Double = 0.10
        public static let lfoDepth: Double = 0.40
    }
}
