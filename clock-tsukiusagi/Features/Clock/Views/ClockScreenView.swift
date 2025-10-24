import SwiftUI

enum ClockDisplayMode {
    case normal
    case dotMatrix
    case sevenSeg
}

struct ClockScreenView: View {
    // MARK: - Constants
    private static let clockFontSize: CGFloat = DesignTokens.ClockTypography.clockFontSize
    private static let sevenSegHeight: CGFloat = DesignTokens.ClockTypography.sevenSegHeight

    @State private var displayMode: ClockDisplayMode = .dotMatrix      // 表示モード切り替えフラグ
    @StateObject private var vm = ClockScreenVM()
    @State private var use24HourFormat: Bool = true  // 24時間表記切り替えフラグ

    // DEBUG用途の固定日時（nilの場合は通常通り現在時刻）
    private let fixedDate: Date?

    init(fixedDate: Date? = nil) {
        self.fixedDate = fixedDate
    }

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = use24HourFormat ? "H:mm" : "h:mm" // 24時間表記 or 12時間表記
        return f
    }

    var body: some View {
		TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = fixedDate ?? context.date
            let snapshot = vm.snapshot(at: now)
            ZStack {
                // 背景（朝/昼/夕/夜でフェード）
                LinearGradient(
                    colors: [snapshot.skyTone.gradStart, snapshot.skyTone.gradEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // 月（UTC位相は内部で計算）
                MoonGlyph(
                    date: now,
                    tone: snapshot.skyTone
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

                // 時刻 + 一言
                VStack(spacing: DesignTokens.ClockSpacing.timeCaptionSpacing) {
                    // /		 時刻表示（表示モードに応じて切り替え）
                    Group {
                        switch displayMode {
                        case .normal:
                            let timeText = Text(formatter.string(from: snapshot.time))
                                .font(.system(size: Self.clockFontSize, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(DesignTokens.ClockColors.textPrimary)
                            timeText

                        case .dotMatrix:
                            DotMatrixClockView(
                                timeString: formatter.string(from: snapshot.time),
                                fontSize: Self.clockFontSize,
                                fontWeight: .semibold,
                                fontDesign: .monospaced,
                                dotSize: 2,
                                dotSpacing: 2,
                                color: DesignTokens.ClockColors.textPrimary,
                                enableGlow: true
                            )

                        case .sevenSeg:
                            SevenSegDotClockView(
                                targetHeight: Self.sevenSegHeight,
                                formatter: formatter,
                                textColor: DesignTokens.ClockColors.textPrimary
                            )
                            .offset(y: -8)
                        }
                    }
                    .accessibilityLabel("Current time")

                    // キャプション（共通）
                    Text(snapshot.caption)
                        .font(
                            .system(
                                size: DesignTokens.ClockTypography.captionFontSize,
                                weight: .regular,
                                design: .serif
                            )
                        )
                        .foregroundStyle(DesignTokens.ClockColors.textSecondary)
                        .accessibilityLabel("Caption")
                }
                .padding(.bottom, DesignTokens.ClockSpacing.bottomPadding)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .animation(.easeInOut(duration: 0.6), value: snapshot.skyTone) // 時間帯フェード

            // タップすると表示モードが変わる
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    switch displayMode {
                    case .normal:
                        displayMode = .dotMatrix
                    case .dotMatrix:
                        displayMode = .sevenSeg
                    case .sevenSeg:
                        displayMode = .normal
                    }
                }
            }
            .onLongPressGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    use24HourFormat.toggle()
                }
            }
        }
    }
}

// MARK: - ViewModel（導出専用・副作用なし）
final class ClockScreenVM: ObservableObject {
    struct Snapshot {
        let time: Date
        let skyTone: SkyTone
        let caption: String
    }

    func snapshot(at date: Date) -> Snapshot {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let tone = SkyTone.forHour(comps.hour ?? 0)
        let cap = tone.captionKey.localized // Localizable対応想定
        return Snapshot(time: date, skyTone: tone, caption: cap)
    }
}

#Preview {
    ClockScreenView()
}

#if DEBUG
#Preview("Fixed 10/9 左明") {
    var comps = DateComponents()
    comps.year = 2025; comps.month = 10; comps.day = 8
    comps.hour = 5; comps.minute = 35
    comps.timeZone = .current
    let date = Calendar.current.date(from: comps)!
    return ClockScreenView(fixedDate: date)
    .overlay(alignment: .bottom) {
        WavyBottomView()
            .allowsHitTesting(false)
    }
}

#Preview("Fixed 10/13 左明,third") {
    var comps = DateComponents()
    comps.year = 2025; comps.month = 10; comps.day = 13
    comps.hour = 7; comps.minute = 5
    comps.timeZone = .current
    let date = Calendar.current.date(from: comps)!
    return ClockScreenView(fixedDate: date)
}

#Preview("Fixed 10/29 右明,first") {
    var comps = DateComponents()
    comps.year = 2025; comps.month = 10; comps.day = 29
    comps.hour = 7; comps.minute = 5
    comps.timeZone = .current
    let date = Calendar.current.date(from: comps)!
    return ClockScreenView(fixedDate: date)
}

#Preview("Fixed 10/30 右明") {
    var comps = DateComponents()
    comps.year = 2025; comps.month = 10; comps.day = 30
    comps.hour = 7; comps.minute = 5
    comps.timeZone = .current
    let date = Calendar.current.date(from: comps)!
    return ClockScreenView(fixedDate: date)
}

#Preview("Full-moon-ish (+14d)") {
    ClockScreenView(fixedDate: Date().addingTimeInterval(14 * 86_400))
}

#Preview("True Full Moon") {
    // Calculate actual full moon date (phase ≈ 0.5)
    let now = Date()
    let mp = MoonPhaseCalculator.moonPhase(on: now)
    let targetPhase = 0.5 // Full moon phase

    // Calculate phase difference considering circular nature (0-1)
    var phaseDifference = targetPhase - mp.phase
    if phaseDifference < 0 {
        phaseDifference += 1.0 // Next full moon
    }

    let synodicMonthDays: Double = 29.530588853
    let daysToFullMoon = phaseDifference * synodicMonthDays
    let fullMoonDate = now.addingTimeInterval(daysToFullMoon * 86_400)
    return ClockScreenView(fixedDate: fullMoonDate)
}

#Preview("True First Quarter") {
    // Calculate actual first quarter date (phase ≈ 0.25)
    let now = Date()
    let mp = MoonPhaseCalculator.moonPhase(on: now)
    let targetPhase = 0.25 // First quarter phase

    // Calculate phase difference considering circular nature (0-1)
    var phaseDifference = targetPhase - mp.phase
    if phaseDifference < 0 {
        phaseDifference += 1.0 // Next first quarter
    }

    let synodicMonthDays: Double = 29.530588853
    let daysToFirstQuarter = phaseDifference * synodicMonthDays
    let firstQuarterDate = now.addingTimeInterval(daysToFirstQuarter * 86_400)
    return ClockScreenView(fixedDate: firstQuarterDate)
}

#Preview("True Third Quarter") {
    // Calculate actual third quarter date (phase ≈ 0.75)
    let now = Date()
    let mp = MoonPhaseCalculator.moonPhase(on: now)
    let targetPhase = 0.75 // Third quarter phase

    // Calculate phase difference considering circular nature (0-1)
    var phaseDifference = targetPhase - mp.phase
    if phaseDifference < 0 {
        phaseDifference += 1.0 // Next third quarter
    }

    let synodicMonthDays: Double = 29.530588853
    let daysToThirdQuarter = phaseDifference * synodicMonthDays
    let thirdQuarterDate = now.addingTimeInterval(daysToThirdQuarter * 86_400)
    return ClockScreenView(fixedDate: thirdQuarterDate)
}
#endif
