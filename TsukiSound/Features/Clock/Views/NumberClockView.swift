import SwiftUI

struct NumberClockView: View {
    // MARK: - Constants
    static let markerColor = DesignTokens.CommonTextColors.secondary
    static let handColor = DesignTokens.CommonTextColors.primary
    static let secondHandColor = DesignTokens.ClockColors.captionBlue
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
                        .font(DesignTokens.ClockTypography.analogClockNumberFont)

                    // 3,6,9,12は濃く（1.0）、その他は薄く
                    let isCardinal = (i % 3 == 0)
                    let opacity = isCardinal ? 1.0 : 0.3

                    let resolved = context.resolve(
                        numText.foregroundStyle(markerColor.opacity(opacity))
                    )

                    context.draw(resolved, at: p, anchor: .center)
                }

                // 針と中心円の描画
                ClockHandDrawing.drawAllHands(
                    context: &context,
                    center: center,
                    radius: radius,
                    date: date,
                    handColor: NumberClockView.handColor,
                    secondHandColor: NumberClockView.secondHandColor,
                    centerColor: NumberClockView.centerCircleColor
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(radius: 1.5, y: 0.5)
    }
}

#Preview {
    NumberClockView()
}
