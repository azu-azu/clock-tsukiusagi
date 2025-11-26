import SwiftUI

// MARK: - ClockCaption
struct ClockCaption {
    let captionKey: String

    static func forMoonPhase(phase: Double, illumination: Double? = nil) -> ClockCaption {
        // 8-phase range-based classification
        // 0.0 = New Moon, 0.25 = First Quarter, 0.5 = Full Moon, 0.75 = Third Quarter

        // Special case: Force new moon if illumination is nearly zero
        if let illum = illumination, illum < 0.05 {
            return .newMoon
        }

        // Normalize phase to 0.0-1.0 range
        let p = phase.truncatingRemainder(dividingBy: 1.0)

        switch p {
        case 0.97..<1.0, 0.0..<0.03:
            return .newMoon
        case 0.03..<0.22:
            return .waxingCrescent
        case 0.22..<0.28:
            return .firstQuarter
        case 0.28..<0.47:
            return .waxingGibbous
        case 0.47..<0.53:
            return .fullMoon
        case 0.53..<0.72:
            return .waningGibbous
        case 0.72..<0.78:
            return .thirdQuarter
        case 0.78..<0.97:
            return .waningCrescent
        default:
            return .newMoon
        }
    }

    // 8 moon phases
    static let newMoon = ClockCaption(captionKey: "NewMoon")
    static let waxingCrescent = ClockCaption(captionKey: "WaxingCrescent")
    static let firstQuarter = ClockCaption(captionKey: "FirstQuarter")
    static let waxingGibbous = ClockCaption(captionKey: "WaxingGibbous")
    static let fullMoon = ClockCaption(captionKey: "FullMoon")
    static let waningGibbous = ClockCaption(captionKey: "WaningGibbous")
    static let thirdQuarter = ClockCaption(captionKey: "ThirdQuarter")
    static let waningCrescent = ClockCaption(captionKey: "WaningCrescent")

    static func forHour(_ h: Int) -> ClockCaption {
        switch h {
        case 4..<8:   return .dawn
        case 8..<16:  return .day
        case 16..<18: return .dusk
        default:      return .night
        }
    }

    static let dawn = ClockCaption(captionKey: "caption_dawn")
    static let day = ClockCaption(captionKey: "caption_day")
    static let dusk = ClockCaption(captionKey: "caption_dusk")
    static let night = ClockCaption(captionKey: "caption_night")
}

