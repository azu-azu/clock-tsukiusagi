import Foundation

public struct MoonPhaseValue: Sendable {
    /// 0.0 = New, 0.5 = Full, 1.0 = New
    public let phase: Double
    /// 0.0 ... 1.0 apparent illumination
    public let illumination: Double
}

public enum MoonPhaseCalculator {
    // Reference: 2000-01-06 18:14:00 UTC (New Moon)
    private static let referenceDateUTC: Date = {
        var comps = DateComponents()
        comps.year = 2000; comps.month = 1; comps.day = 6
        comps.hour = 18; comps.minute = 14; comps.second = 0
        let cal = Calendar(identifier: .gregorian)
        let utc = TimeZone(secondsFromGMT: 0)!
        var calUTC = cal
        calUTC.timeZone = utc
        return calUTC.date(from: comps)!
    }()

    /// Mean synodic month length in days
    private static let synodicMonthDays: Double = 29.530588853
    private static let secondsPerDay: Double = 86_400.0

    public static func moonPhase(on date: Date) -> MoonPhaseValue {
        // Date is absolute (UTC-based), so direct difference is fine
        let dt = date.timeIntervalSince(referenceDateUTC)
        let days = dt / secondsPerDay

        // Normalize phase to [0, 1)
        let raw = days / synodicMonthDays
        let phase = positiveModulo(raw, 1.0)
        // Apparent illumination: 0.5 * (1 - cos(2πφ))
        let illumination = 0.5 * (1.0 - cos(2.0 * .pi * phase))
        return MoonPhaseValue(phase: phase, illumination: illumination)
    }

    private static func positiveModulo(_ x: Double, _ m: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: m)
        return r < 0 ? r + m : r
    }
}
