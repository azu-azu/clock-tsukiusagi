//
//  UISoundPreset.swift
//  clock-tsukiusagi
//
//  UI display layer for sound presets (separate from technical parameters)
//

import Foundation

/// Sound preset for UI display (decoupled from technical implementation)
/// This enum represents what users see in the app, not how sounds are generated.
public enum UISoundPreset: String, CaseIterable, Identifiable {
    case oceanWavesSeagulls // 波 + 海鳥
    case moonlitSea         // 深夜の海
    case pentatonic         // ペンタトニックチャイム（PureTone module）
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
    case treeChimeOnly      // TreeChimeのみ（テスト用）

    public var id: String { rawValue }

    /// Indicates if this is a test/development preset
    public var isTest: Bool {
        [
            .pentatonic,
            .stardustNoise,
            .lunarDustStorm,
            .silentLibrary,
            .distantThunder,
            .sinkingMoon,
            .dawnHint,
            .treeChimeOnly
        ].contains(self)
    }

    /// Display name for UI (Japanese with emoji)
    public var displayName: String {
        switch self {
        case .oceanWavesSeagulls:
            return "波 + 海鳥"
        case .moonlitSea:
            return "🌊 深夜の海"
        case .pentatonic:
            return "🎵 ペンタトニックチャイム"
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
        case .treeChimeOnly:
            return "♟️ 🎐 TreeChime単体"
        }
    }

    /// English title for selected display
    public var englishTitle: String {
        switch self {
        case .oceanWavesSeagulls:
            return "Ocean Waves + Seagulls"
        case .moonlitSea:
            return "Moonlit Silent Sea"
        case .pentatonic:
            return "Pentatonic Chime"
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
        case .treeChimeOnly:
            return "TreeChime Only (Test)"
        }
    }
}
