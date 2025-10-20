import SwiftUI

// MARK: - SkyTone
struct SkyTone: Equatable {
    let gradStart: Color
    let gradEnd: Color
    let captionKey: String

    static func forHour(_ h: Int) -> SkyTone {
        switch h {
        case 4..<8:   return .dusk
        case 8..<16:  return .dusk
        case 16..<18: return .dusk
        default:      return .night
        }
    }

    static let dawn = SkyTone(
        // 少し紫っぽい
        gradStart: Color(hex: "#293f72"),
        gradEnd: Color(hex: "#ca9cff"),
        captionKey: "caption_dawn"
    )

    static let day = SkyTone(
        // 全体的に水色
        gradStart: Color(hex: "#3a61a1"),
        gradEnd: Color(hex: "#b6d7ff"),

        // 白すぎ
        // gradStart: Color(hex: "#DDE3F0"),
        // gradEnd: Color(hex: "#EEF2F7"),
        captionKey: "caption_day"
    )

    static let dusk = SkyTone(
        // 濃紺
        gradStart: Color(hex: "#0F1420"),
        gradEnd: Color(hex: "#1A2030"),
        captionKey: "caption_dusk"
    )

    static let night = SkyTone(
        gradStart: Color(hex: "#0B0F18"),
        gradEnd: Color(hex: "#141A26"),
        captionKey: "caption_night"
    )
}


// 夜明け
        // gradStart: Color(hex: "#1B2330"),
        // gradEnd: Color(hex: "#EEF2F7"),


// 結構くらい
        // gradStart: Color(hex: "#0F1420"),
        // gradEnd: Color(hex: "#1A2030"),