import SwiftUI

struct QuietClockView: View {
    @StateObject private var vm = QuietClockVM()
    @State private var useDotMatrix: Bool = true  // 切り替えフラグ
    @State private var use24HourFormat: Bool = true  // 24時間表記切り替えフラグ

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = use24HourFormat ? "H:mm" : "h:mm a" // 24時間表記 or 12時間表記
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
                    // 時刻表示（同じTextコンポーネント、見た目だけ変更）
                    Text(formatter.string(from: snapshot.time))
                        .font(.system(size: 56, weight: .semibold, design: useDotMatrix ? .monospaced : .rounded))
                        .monospacedDigit()
                        .foregroundStyle(useDotMatrix ? .clear : .white.opacity(0.95))
                        .overlay(
                            // ドットマトリックス表示時のみオーバーレイでDotGridを表示
                            useDotMatrix ?
                            DotGrid(dotSize: 2, spacing: 2, color: .white.opacity(0.95))
                                .mask(
                                    Text(formatter.string(from: snapshot.time))
                                        .font(.system(size: 56, weight: .semibold, design: .monospaced))
                                        .monospacedDigit()
                                )
                                .shadow(color: .white.opacity(0.25), radius: 6, x: 0, y: 0)
                                .shadow(color: .white.opacity(0.12), radius: 16, x: 0, y: 0)
                            : nil
                        )
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
                    useDotMatrix.toggle()
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
final class QuietClockVM: ObservableObject {
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
    QuietClockView()
}
