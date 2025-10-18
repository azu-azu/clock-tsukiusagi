import SwiftUI

// MARK: - DotGrid (reusable component)
struct DotGrid: View {
    let dotSize: CGFloat
    let spacing: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let cols = Int(ceil(size.width / spacing))
                let rows = Int(ceil(size.height / spacing))
                let radius = dotSize / 2.0

                var path = Path()
                for r in 0..<rows {
                    let y = CGFloat(r) * spacing + spacing/2
                    for c in 0..<cols {
                        let x = CGFloat(c) * spacing + spacing/2
                        let rect = CGRect(x: x - radius, y: y - radius, width: dotSize, height: dotSize)
                        path.addEllipse(in: rect)
                    }
                }
                context.fill(path, with: .color(color))
            }
        }
    }
}

struct QuietClockView: View {
    @StateObject private var vm = QuietClockVM()
    @State private var useDotMatrix: Bool = true  // 切り替えフラグ

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
                    Text(snapshot.time, style: .time)
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(useDotMatrix ? .clear : .white.opacity(0.95))
                        .overlay(
                            // ドットマトリックス表示時のみオーバーレイでDotGridを表示
                            useDotMatrix ?
                            DotGrid(dotSize: 2, spacing: 2, color: .white.opacity(0.95))
                                .mask(
                                    Text(snapshot.time, style: .time)
                                        .font(.system(size: 56, weight: .semibold, design: .rounded))
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
