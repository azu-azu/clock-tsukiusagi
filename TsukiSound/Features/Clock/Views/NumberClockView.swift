import SwiftUI
import Foundation

struct NumberClockView: View {
    // MARK: - Constants
    static let markerColor = DesignTokens.CommonTextColors.secondary
    static let handColor = DesignTokens.CommonTextColors.primary
    static let centerCircleColor = DesignTokens.CommonTextColors.primary

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            NumberClockFace(date: context.date)
                .padding(24)
        }
    }
}

// MARK: - Clock Face
private struct NumberClockFace: View {
    let date: Date

    var body: some View {
        GeometryReader { geo in
            let markerColor = NumberClockView.markerColor

            let size = geo.size
            let center = CGPoint(x: size.width/2, y: size.height/2)
            let radius = min(size.width, size.height) * 0.42

            Canvas { context, _ in
                // ---- 12個の数字インデックス ----
                for i in 1...12 {
                    let angle = Angle.degrees(Double(i) / 12.0 * 360.0 - 90)
                    let p = CGPoint(
                        x: center.x + CGFloat(cos(angle.radians)) * radius,
                        y: center.y + CGFloat(sin(angle.radians)) * radius
                    )

                    // 数字を描画（Text → resolve → context.draw）
                    let numText = Text("\(i)")
                        .font(.custom("AmericanTypewriter-CondensedBold", size: 22))

                    // 3,6,9,12は濃く（1.0）、その他は薄く
                    let isCardinal = (i % 3 == 0)
                    let opacity = isCardinal ? 1.0 : 0.3

                    let resolved = context.resolve(
                        numText.foregroundStyle(markerColor.opacity(opacity))
                    )

                    context.draw(resolved, at: p, anchor: .center)
                }

                // ---- 針計算（BunnyClockViewとほぼ同じ） ----
                let cal = Calendar.current
                let s = Double(cal.component(.second, from: date))
                let m = Double(cal.component(.minute, from: date)) + s/60.0
                let h = Double(cal.component(.hour, from: date) % 12) + m/60.0

                let secAngle  = Angle.degrees(s/60.0 * 360.0 - 90)
                let minAngle  = Angle.degrees(m/60.0 * 360.0 - 90)
                let hourAngle = Angle.degrees(h/12.0 * 360.0 - 90)

                func endPoint(_ angle: Angle, _ length: CGFloat) -> CGPoint {
                    CGPoint(
                        x: center.x + CGFloat(cos(angle.radians)) * length,
                        y: center.y + CGFloat(sin(angle.radians)) * length
                    )
                }

                func drawHand(angle: Angle, length: CGFloat, width: CGFloat, alpha: Double) {
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: endPoint(angle, length))
                    let style = StrokeStyle(lineWidth: width, lineCap: .round)

                    context.stroke(
                        path,
                        with: .color(NumberClockView.handColor.opacity(alpha)),
                        style: style
                    )
                }

                drawHand(angle: hourAngle, length: radius * 0.55, width: 6, alpha: 0.95)
                drawHand(angle: minAngle,  length: radius * 0.78, width: 5, alpha: 0.95)
                drawHand(angle: secAngle,  length: radius * 0.88, width: 2, alpha: 0.65)

                // 中心点
                let dot = Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
                context.fill(dot, with: .color(NumberClockView.centerCircleColor))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(radius: 1.5, y: 0.5)
    }
}

#Preview {
    NumberClockView()
}
