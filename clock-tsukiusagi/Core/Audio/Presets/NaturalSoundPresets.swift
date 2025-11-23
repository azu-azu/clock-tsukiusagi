//
//  NaturalSoundPresets.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  自然音プリセット（環境音・ノイズ系のみ）
//  Active: darkShark, midnightTrain, distantThunder
//

import Foundation

/// 自然音プリセット（環境音・ノイズ系のみ）
/// Note: 純音系（PentatonicChime等）は PureTone module で実装（Core/Audio/PureTone/）
public enum NaturalSoundPreset: String, CaseIterable, Identifiable {
    case darkShark          // 黒いサメの影
    case midnightTrain      // 夜汽車
    case distantThunder     // 遠雷

    public var id: String { rawValue }

    /// Indicates if this is a test/development preset
    public var isTest: Bool {
        false  // Both are production presets
    }

    /// Display name for UI (Japanese with emoji)
    /// Note: This is deprecated - use UISoundPreset.displayName instead
    public var displayName: String {
        switch self {
        case .darkShark:
            return "🦈 黒いサメの影"
        case .midnightTrain:
            return "🚂 夜汽車"
        case .distantThunder:
            return "⚡ 遠雷"
        }
    }

    /// English title for selected display
    /// Note: This is deprecated - use UISoundPreset.englishTitle instead
    public var englishTitle: String {
        switch self {
        case .darkShark:
            return "Dark Shape Underwater"
        case .midnightTrain:
            return "Midnight Train in the Distance"
        case .distantThunder:
            return "Distant Thunder Rumble"
        }
    }
}

/// 自然音プリセットの設定（アクティブなプリセットのみ）
public struct NaturalSoundPresets {

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

}
