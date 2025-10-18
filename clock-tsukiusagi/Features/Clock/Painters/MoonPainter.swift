import SwiftUI

// MARK: - MoonPainter
enum MoonPainter {
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
        
        ctx.fill(circle, with: .radialGradient(
            Gradient(colors: [
                Color.white.opacity(0.95),
                Color(hex: "#C9D6FF").opacity(0.25)
            ]),
            center: .init(x: center.x, y: center.y),
            startRadius: radius * 0.1,
            endRadius: radius
        ))
        
        // グロー
        var blurredCtx = ctx
        blurredCtx.addFilter(.blur(radius: 6))
        blurredCtx.stroke(circle, with: .color(Color.white.opacity(0.08)), lineWidth: 2)
    }
}