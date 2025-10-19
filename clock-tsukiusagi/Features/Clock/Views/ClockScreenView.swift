import SwiftUI

enum ClockDisplayMode {
    case normal
    case dotMatrix
    case sevenSeg
}

struct ClockScreenView: View {
    // MARK: - Constants
    private static let clockFontSize: CGFloat = 56
    private static let sevenSegHeight: CGFloat = 44

    @State private var displayMode: ClockDisplayMode = .dotMatrix      // 表示モード切り替えフラグ
    @StateObject private var vm = ClockScreenVM()
    @State private var use24HourFormat: Bool = true  // 24時間表記切り替えフラグ

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = use24HourFormat ? "H:mm" : "h:mm" // 24時間表記 or 12時間表記
        return f
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let snapshot = vm.snapshot(at: context.date)
            ZStack {
                // 背景（朝/昼/夕/夜でフェード）
                LinearGradient(
                    colors: [snapshot.skyTone.gradStart, snapshot.skyTone.gradEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // 月
                Canvas { ctx, size in
                    MoonPainter.draw(in: ctx, size: size,
                                    angle: snapshot.phaseAngle,
                                    tone: snapshot.skyTone)
                }
                .accessibilityHidden(true)

                // 時刻 + 一言
                VStack(spacing: 8) {
                    // 時刻表示（表示モードに応じて切り替え）
                    Group {
                        switch displayMode {
                        case .normal:
                            let timeText = Text(formatter.string(from: snapshot.time))
                                .font(.system(size: Self.clockFontSize, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.95))
                            timeText

                        case .dotMatrix:
                            let timeText = Text(formatter.string(from: snapshot.time))
                                .font(.system(size: Self.clockFontSize, weight: .semibold, design: .monospaced))
                                .monospacedDigit()

                            let textColor = Color.white.opacity(0.95)

                            timeText
                                .foregroundStyle(.clear)
                                .overlay(
                                    DotGrid(dotSize: 2, spacing: 2, color: textColor, enableGlow: true)
                                        .mask(timeText)
                                )

                        case .sevenSeg:
                            SevenSegDotClockView(targetHeight: Self.sevenSegHeight, formatter: formatter)
                                .offset(y: -8)
                        }
                    }
                    .accessibilityLabel("Current time")

                    // キャプション（共通）
                    Text(snapshot.caption)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityLabel("Caption")
                }
                .padding(.bottom, 48)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .animation(.easeInOut(duration: 0.6), value: snapshot.skyTone) // 時間帯フェード
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
        let phaseAngle: Double
        let skyTone: SkyTone
        let caption: String
    }

    func snapshot(at date: Date) -> Snapshot {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let angle = Double(minutes) / 1440.0 * 360.0
        let tone = SkyTone.forHour(comps.hour ?? 0)
        let cap = tone.captionKey.localized // Localizable対応想定
        return Snapshot(time: date, phaseAngle: angle, skyTone: tone, caption: cap)
    }
}

#Preview {
    ClockScreenView()
}
