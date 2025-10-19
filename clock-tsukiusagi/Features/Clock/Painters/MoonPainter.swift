import SwiftUI

// MARK: - MoonPainter
enum MoonPainter {
    // MARK: - Colors
    private static let moonCenterColor = Color(hex: "#fff").opacity(0.95)
    private static let moonEdgeColor = Color(hex: "#fff").opacity(0.6)

    static func draw(in ctx: GraphicsContext, size: CGSize, angle: Double, tone: SkyTone) {
        let radius = min(size.width, size.height) * 0.18
        let center = CGPoint(
            x: size.width * 0.5 + cos(angle.radian) * (size.width * 0.25),
            y: size.height * 0.45 + sin(angle.radian) * (size.height * 0.18)
        )

        // 月本体
        let circle = Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        // 月本体を先に描画
        ctx.fill(circle, with: .radialGradient(
            Gradient(colors: [
                moonCenterColor,
                moonEdgeColor
            ]),
            center: .init(x: center.x, y: center.y),
            startRadius: radius * 0.1,
            endRadius: radius
        ))

        // グロウ（青の影を多層で重ねる）- 月の外側に描画
        var shadowCtx1 = ctx
        shadowCtx1.addFilter(.blur(radius: 12))
        shadowCtx1.stroke(circle, with: .color(Color.cyan.opacity(0.35)), lineWidth: 8)

        var shadowCtx2 = ctx
        shadowCtx2.addFilter(.blur(radius: 28))
        shadowCtx2.stroke(circle, with: .color(Color.cyan.opacity(0.25)), lineWidth: 16)

        var shadowCtx3 = ctx
        shadowCtx3.addFilter(.blur(radius: 48))
        shadowCtx3.stroke(circle, with: .color(Color.cyan.opacity(0.18)), lineWidth: 24)

        // 元のグロー
        var blurredCtx = ctx
        blurredCtx.addFilter(.blur(radius: 6))
        blurredCtx.stroke(circle, with: .color(Color(hex: "#fff").opacity(0.08)), lineWidth: 2)
    }
}