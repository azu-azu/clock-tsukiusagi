import SwiftUI

enum ClockDisplayMode {
    case normal
    case dotMatrix
    case sevenSeg
    case bunny
    case number
}

struct ClockScreenView: View {
    // MARK: - Constants
    private static let clockFontSize: CGFloat = DesignTokens.ClockTypography.clockFontSize
    private static let sevenSegHeight: CGFloat = DesignTokens.ClockTypography.sevenSegHeight

    @Binding var displayMode: ClockDisplayMode
    @StateObject private var vm = ClockScreenVM()
    @State private var use24HourFormat: Bool = true  // 24時間表記切り替えフラグ

    // DEBUG用途の固定日時（nilの場合は通常通り現在時刻）
    private let fixedDate: Date?

    init(displayMode: Binding<ClockDisplayMode>, fixedDate: Date? = nil) {
        self._displayMode = displayMode
        self.fixedDate = fixedDate
    }

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = use24HourFormat ? "H:mm" : "h:mm" // 24時間表記 or 12時間表記
        return f
    }

    // MARK: - Digital Clock Content
    @ViewBuilder
    private func digitalClockContent(snapshot: ClockScreenVM.Snapshot) -> some View {
        switch displayMode {
        case .normal:
            Text(formatter.string(from: snapshot.time))
                .font(.system(size: Self.clockFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ClockColors.textPrimary)

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

        case .bunny, .number:
            EmptyView()
        }
    }

    // MARK: - Analog Clock View (bunny/number mode)
    @ViewBuilder
    private func analogClockView(in geometry: GeometryProxy) -> some View {
        let isLandscape = geometry.size.width > geometry.size.height
        let clockSize = isLandscape
            ? min(geometry.size.height * 0.85, geometry.size.width * 0.5)
            : min(geometry.size.width * 0.85, geometry.size.height * 0.5)

        Group {
            switch displayMode {
            case .bunny:
                BunnyClockView()
            case .number:
                NumberClockView()
            default:
                EmptyView()
            }
        }
        .frame(width: clockSize, height: clockSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLandscape ? .center : .top)
        .offset(y: isLandscape ? -20 : 0)
        .padding(.top, isLandscape ? 0 : 100)
        .accessibilityLabel("Current time")
    }

    var body: some View {
		TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = fixedDate ?? context.date
            let snapshot = vm.snapshot(at: now)
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let isDigitalMode = displayMode != .bunny && displayMode != .number
                ZStack {
                    // 背景（朝/昼/夕/夜でフェード）
                    LinearGradient(
                        colors: [snapshot.skyTone.gradStart, snapshot.skyTone.gradEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    // 横向き＋デジタルモード: 左に月、右に時計
                    if isLandscape && isDigitalMode {
                        HStack(spacing: 0) {
                            // 左側: 月
                            MoonGlyph(
                                date: now,
                                tone: snapshot.skyTone
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityHidden(true)

                            // 右側: 時計 + キャプション
                            VStack(spacing: DesignTokens.ClockSpacing.timeCaptionSpacing) {
                                digitalClockContent(snapshot: snapshot)
                                    .frame(height: Self.clockFontSize)
                                    .accessibilityLabel("Current time")

                                Text(snapshot.caption)
                                    .font(
                                        .system(
                                            size: DesignTokens.ClockTypography.captionFontSize,
                                            weight: .regular,
                                            design: .serif
                                        )
                                    )
                                    .foregroundStyle(DesignTokens.ClockColors.captionBlue)
                                    .accessibilityLabel("Caption")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        // 縦向き or アナログモード: 従来のレイアウト

                        // 月（UTC位相は内部で計算）— bunny/numberモード時は非表示
                        if isDigitalMode {
                            MoonGlyph(
                                date: now,
                                tone: snapshot.skyTone
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .offset(y: -30)
                            .accessibilityHidden(true)
                        }

                        // bunny/numberモードのアナログ時計（共通化）
                        if displayMode == .bunny || displayMode == .number {
                            analogClockView(in: geometry)
                        }

                        // 時刻 + 一言（bunny/numberモード以外）または キャプションのみ（bunny/numberモード）
                        VStack(spacing: DesignTokens.ClockSpacing.timeCaptionSpacing) {
                            // 時刻表示（bunny/numberモード以外のみ）
                            if isDigitalMode {
                                digitalClockContent(snapshot: snapshot)
                                    // SevenSegは高さが小さいので、他と同じ高さのフレームで包む
                                    .frame(height: Self.clockFontSize)
                                    .accessibilityLabel("Current time")
                            }

                            // キャプション（全モード共通）— 横向き時はアナログ時計モードで非表示
                            if !(isLandscape && (displayMode == .bunny || displayMode == .number)) {
                                Text(snapshot.caption)
                                    .font(
                                        .system(
                                            size: DesignTokens.ClockTypography.captionFontSize,
                                            weight: .regular,
                                            design: .serif
                                        )
                                    )
                                    .foregroundStyle(DesignTokens.ClockColors.captionBlue)
                                    .accessibilityLabel("Caption")
                            }
                        }
                        .padding(.bottom, DesignTokens.ClockSpacing.bottomPadding)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.6), value: snapshot.skyTone) // 時間帯フェード
            // タップ範囲を画面中央部に限定（上部ナビバー領域を除外）
            .overlay(
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: geometry.size.height - 80)
                        .offset(y: 80)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                switch displayMode {
                                case .normal:
                                    displayMode = .dotMatrix
                                case .dotMatrix:
                                    displayMode = .sevenSeg
                                case .sevenSeg:
                                    displayMode = .bunny
                                case .bunny:
                                    displayMode = .number
                                case .number:
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
            )
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
        let mp = MoonPhaseCalculator.moonPhaseForLocalEvening(on: date)
        let caption = ClockCaption.forMoonPhase(phase: mp.phase, illumination: mp.illumination).captionKey
        return Snapshot(time: date, skyTone: tone, caption: caption)
    }
}

#Preview {
    ClockScreenView(displayMode: .constant(.dotMatrix))
}

#if DEBUG
#Preview("Phase debug") {
    // ←ここはお好きな日付でOK（例: 2025/10/13 21:00 JST）
    var comps = DateComponents()
    comps.year = 2025; comps.month = 10; comps.day = 24
    comps.hour = 21; comps.minute = 0
    comps.timeZone = .current
    let date = Calendar.current.date(from: comps)!

    // 位相・照度（あなたの MoonPhaseCalculator を使用）
    let mp = MoonPhaseCalculator.moonPhaseForLocalEvening(on: date)
    let φ  = mp.phase                      // 0=新月, 0.25=上弦, 0.5=満月, 0.75=下弦
    let illumPct = Int((mp.illumination * 100).rounded())
    let isRightLit = sin(2.0 * .pi * φ) > 0 // 右が明るい＝waxing

    // ───────── 位相イベントの最近接を計算（過去/未来を別々に） ─────────
    func labelForQuarter(phase φ: Double) -> (name: String, tag: String) {
        struct Q { let idx:Int; let name:String }
        let quarters: [Q] = [
            .init(idx: 0, name: "新月"),
            .init(idx: 1, name: "上弦の月"),
            .init(idx: 2, name: "満月"),
            .init(idx: 3, name: "下弦の月")
        ]
        func norm(_ x: Double) -> Double { var t = x - floor(x); if t < 0 { t += 1 }; return t }
        let synodic = 29.530588861

        // 直近の「過去」と「未来」の四分位を別々に求める
        let x = norm(φ) * 4.0
        let prevIdx = Int(floor(x)) & 3
        let nextIdx = (prevIdx + 1) & 3
        let prevTurn = Double(prevIdx) / 4.0
        let nextTurn = Double(nextIdx) / 4.0

        // φ からの位相差（回転）：過去は負、未来は正になるようにとる
        // 過去側: φ - prevTurn の距離を計算
        var dPrevTurn = φ - prevTurn
        if dPrevTurn < 0 { dPrevTurn += 1.0 }       // 0..1
        dPrevTurn = min(dPrevTurn, 1.0 - dPrevTurn)   // 0..0.5
        dPrevTurn = -dPrevTurn  // 負（過去）

        // 未来側: nextTurn - φ の距離を計算
        var dNextTurn = nextTurn - φ
        if dNextTurn < 0 { dNextTurn += 1.0 }       // 0..1
        dNextTurn = min(dNextTurn, 1.0 - dNextTurn)   // 0..0.5
        // dNextTurn は正（未来）のまま

        let daysPrev = dPrevTurn * synodic   // 負（過去）
        let daysNext = dNextTurn * synodic   // 正（未来）

        // どちらが近いかでラベルを決定
        let (pickIdx, tag): (Int, String) = {
            if abs(daysPrev) <= abs(daysNext) {
                let days = Int(round(-daysPrev))
                return (prevIdx, days == 0 ? "" : "（\(days)日後）") // 0日は表示しない
            } else {
                let days = Int(round(daysNext))
                return (nextIdx, days == 0 ? "" : "（\(days)日前）")   // 0日は表示しない
            }
        }()

        return (quarters[pickIdx].name, tag)
    }

    let (phaseName, tag) = labelForQuarter(phase: φ)


    let litSide = (mp.illumination > 0.05 && mp.illumination < 0.95)
                  ? (isRightLit ? "右側" : "左側") : nil

    return VStack(spacing: 8) {
        Text(
            DateFormatter.localizedString(
                from: date,
                dateStyle: .short,
                timeStyle: .none
            )
        )
            .font(.headline).foregroundColor(.white)

        Text(phaseName + tag)
            .font(.title2).foregroundColor(.yellow)

        Text("照度: \(illumPct)%")
            .font(.body).foregroundColor(.white)

        if let litSide { Text("光っている側: \(litSide)") .foregroundColor(.white) }

        Text(String(format: "位相: %.3f", φ))
            .font(.caption).foregroundColor(.gray)

        // オフセット（半月からの幾何オフセット量 |cos| も参考表示）
        let offset = abs(cos(2.0 * .pi * φ))
        Text(String(format: "オフセット: %.1f", offset))
            .font(.caption).foregroundColor(.gray)

        ClockScreenView(displayMode: .constant(.dotMatrix), fixedDate: date)
    }
    .background(.black)
}

#Preview("Fixed 10/13 左明,third") {
    var comps = DateComponents()
    comps.year = 2025; comps.month = 10; comps.day = 13
    comps.hour = 7; comps.minute = 5
    comps.timeZone = .current
    let date = Calendar.current.date(from: comps)!
    return ClockScreenView(displayMode: .constant(.dotMatrix), fixedDate: date)
}

#Preview("Fixed 10/29 右明,first") {
    var comps = DateComponents()
    comps.year = 2025; comps.month = 10; comps.day = 29
    comps.hour = 7; comps.minute = 5
    comps.timeZone = .current
    let date = Calendar.current.date(from: comps)!
    return ClockScreenView(displayMode: .constant(.dotMatrix), fixedDate: date)
}

#Preview("Fixed 10/30 右明") {
    var comps = DateComponents()
    comps.year = 2025; comps.month = 10; comps.day = 30
    comps.hour = 7; comps.minute = 5
    comps.timeZone = .current
    let date = Calendar.current.date(from: comps)!
    return ClockScreenView(displayMode: .constant(.dotMatrix), fixedDate: date)
}

#Preview("Full-moon-ish (+14d)") {
    ClockScreenView(displayMode: .constant(.dotMatrix), fixedDate: Date().addingTimeInterval(14 * 86_400))
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
    return ClockScreenView(displayMode: .constant(.dotMatrix), fixedDate: fullMoonDate)
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
    return ClockScreenView(displayMode: .constant(.dotMatrix), fixedDate: firstQuarterDate)
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
    return ClockScreenView(displayMode: .constant(.dotMatrix), fixedDate: thirdQuarterDate)
}
#endif
