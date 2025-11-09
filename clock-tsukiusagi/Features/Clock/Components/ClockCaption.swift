import SwiftUI

// MARK: - ClockCaption
struct ClockCaption {
    let captionKey: String

    static func forMoonPhase(phase: Double, illumination: Double? = nil) -> ClockCaption {
        // phase から月相判定
        // 0.0 = 新月, 0.25 = 上弦, 0.5 = 満月, 0.75 = 下弦

        // 円形のphase範囲を考慮して、境界を跨いだ判定も含める
        func isInPhaseRange(_ p: Double, _ target: Double, _ threshold: Double) -> Bool {
            let diff = abs(p - target)
            // phaseは円形（0.0と1.0は隣接）なので、反対側もチェック
            return diff < threshold || diff > (1.0 - threshold)
        }

        let phaseThreshold = 0.08  // ±0.08（約±2.5日）

        // 主要月相の範囲内かチェック
        if isInPhaseRange(phase, 0.0, phaseThreshold) {
            return .newMoon
        } else if isInPhaseRange(phase, 0.5, phaseThreshold) {
            return .fullMoon
        } else if isInPhaseRange(phase, 0.25, phaseThreshold) {
            return .firstQuarter
        } else if isInPhaseRange(phase, 0.75, phaseThreshold) {
            return .thirdQuarter
        } else {
            // 中間の月相の場合、各主要月相からの距離を計算して最も近いものを返す
            let normalizedPhase = phase - floor(phase)

            // 円形距離を計算する関数（0.0と1.0が隣接していることを考慮）
            func circularDistance(_ a: Double, _ b: Double) -> Double {
                let diff = abs(a - b)
                return min(diff, 1.0 - diff)
            }

            let distances: [(Double, ClockCaption)] = [
                (circularDistance(normalizedPhase, 0.0), .newMoon),
                (circularDistance(normalizedPhase, 0.25), .firstQuarter),
                (circularDistance(normalizedPhase, 0.5), .fullMoon),
                (circularDistance(normalizedPhase, 0.75), .thirdQuarter)
            ]

            #if DEBUG
            print("ClockCaption: normalizedPhase=\(String(format: "%.6f", normalizedPhase))")
            if let illum = illumination {
                print("ClockCaption: illumination=\(String(format: "%.2f%%", illum * 100))")
            }
            for (dist, caption) in distances {
                print("  Distance to \(caption.captionKey): \(String(format: "%.6f", dist))")
            }
            #endif

            // 照度を考慮した判定
            // 照度が高い（>80%）場合は満月寄り、低い（<20%）場合は新月寄りと判定
            if let illum = illumination {
                // 照度が非常に高い（>85%）場合、満月寄りと判定
                if illum > 0.85 {
                    // 満月と下弦の間で、照度が高い場合は満月を優先
                    let fullMoonDist = circularDistance(normalizedPhase, 0.5)
                    let thirdQuarterDist = circularDistance(normalizedPhase, 0.75)
                    // 距離が近い場合（0.15以内）は照度を優先
                    if abs(fullMoonDist - thirdQuarterDist) < 0.15 {
                        #if DEBUG
                        print("ClockCaption: High illumination, preferring FullMoon")
                        #endif
                        return .fullMoon
                    }
                }
                // 照度が非常に低い（<15%）場合、新月寄りと判定
                else if illum < 0.15 {
                    let newMoonDist = circularDistance(normalizedPhase, 0.0)
                    let firstQuarterDist = circularDistance(normalizedPhase, 0.25)
                    if abs(newMoonDist - firstQuarterDist) < 0.15 {
                        #if DEBUG
                        print("ClockCaption: Low illumination, preferring NewMoon")
                        #endif
                        return .newMoon
                    }
                }
            }

            // 最も近い月相を返す
            let result = distances.min(by: { $0.0 < $1.0 })?.1 ?? .fullMoon
            #if DEBUG
            print("ClockCaption: Selected \(result.captionKey)")
            #endif
            return result
        }
    }

    static let newMoon = ClockCaption(captionKey: "NewMoon")
    static let firstQuarter = ClockCaption(captionKey: "FirstQuarter")
    static let fullMoon = ClockCaption(captionKey: "FullMoon")
    static let thirdQuarter = ClockCaption(captionKey: "ThirdQuarter")

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

