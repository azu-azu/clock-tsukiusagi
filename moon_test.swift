import Foundation

// 10/11 2025 の日付を作成
var comps = DateComponents()
comps.year = 2025; comps.month = 10; comps.day = 11
comps.hour = 21; comps.minute = 0; comps.second = 0
comps.timeZone = TimeZone.current
let date = Calendar.current.date(from: comps)!

// 月相計算（現在の実装を模擬）
let referenceDateUTC = Date(timeIntervalSince1970: 947_200_440) // 2000-01-06 18:14:00 UTC
let dt = date.timeIntervalSince(referenceDateUTC)
let days = dt / 86400.0
let synodicMonthDays = 29.530588853
let raw = days / synodicMonthDays
let phase = raw - floor(raw)
let illumination = 0.5 * (1.0 - cos(2.0 * .pi * phase))

print(String(format: "10/11 21:00 - Phase: %.6f, Illumination: %.2f%%", phase, illumination * 100))

// 追加: 10/13 (下弦) も計算
var comps2 = DateComponents()
comps2.year = 2025; comps2.month = 10; comps2.day = 13
comps2.hour = 21; comps2.minute = 0; comps2.second = 0
comps2.timeZone = TimeZone.current
let date2 = Calendar.current.date(from: comps2)!

let dt2 = date2.timeIntervalSince(referenceDateUTC)
let days2 = dt2 / 86400.0
let raw2 = days2 / synodicMonthDays
let phase2 = raw2 - floor(raw2)
let illumination2 = 0.5 * (1.0 - cos(2.0 * .pi * phase2))

print(String(format: "10/13 21:00 - Phase: %.6f, Illumination: %.2f%%", phase2, illumination2 * 100))

// offset計算も確認
let offset1 = abs(cos(2.0 * .pi * phase))
let offset2 = abs(cos(2.0 * .pi * phase2))
print(String(format: "10/11 offset: %.6f", offset1))
print(String(format: "10/13 offset: %.6f", offset2))
