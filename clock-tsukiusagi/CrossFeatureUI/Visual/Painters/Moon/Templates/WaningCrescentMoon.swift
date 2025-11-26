import SwiftUI

/// 二十六夜テンプレート（左側に細い弧）
/// phase: 0.78〜0.97 の範囲で使用
enum WaningCrescentMoon {
    /// 二十六夜の形状を生成（2円法で正確に再現）
    /// - Parameters:
    ///   - center: 月の中心座標
    ///   - radius: 月の半径
    /// - Returns: 二十六夜の形状を示すPath
    static func shape(center: CGPoint, radius: CGFloat) -> Path {
        // 2円法の交点計算
        // 三日月の左右反転版
        let c0 = center  // 月の中心
        let d: CGFloat = radius * 0.65  // 三日月と同じ比率
        let c1 = CGPoint(x: c0.x + d, y: c0.y)  // 影円の中心（左が明なので右へ）

        let a = d * 0.5
        let h2 = max(0, radius*radius - a*a)
        let h = sqrt(h2)
        let ux: CGFloat = 1.0, uy: CGFloat = 0.0  // c0→c1の方向
        let mx = c0.x + a*ux, my = c0.y + a*uy
        let nx = -uy, ny = ux
        let px = mx + h*nx, py = my + h*ny
        let qx = mx - h*nx, qy = my - h*ny

        func ang(_ cx: CGFloat, _ cy: CGFloat, _ x: CGFloat, _ y: CGFloat) -> Angle {
            .radians(atan2(Double(y - cy), Double(x - cx)))
        }
        let th0P = ang(c0.x, c0.y, px, py)
        let th0Q = ang(c0.x, c0.y, qx, qy)
        let th1P = ang(c1.x, c1.y, px, py)
        let th1Q = ang(c1.x, c1.y, qx, qy)

        // 三日月（isCrescent=YES）かつ左が明（rightLit=L）の場合
        // c0(Q→P, CW) + c1(Q→P, CW)
        var path = Path()
        path.move(to: CGPoint(x: px, y: py))
        path.addArc(center: c0, radius: radius, startAngle: th0P, endAngle: th0Q, clockwise: true)
        path.addArc(center: c1, radius: radius, startAngle: th1Q, endAngle: th1P, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview
#Preview("Waning Crescent Moon Template") {
    Canvas { ctx, size in
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        let radius: CGFloat = min(size.width, size.height) * 0.18

        // 二十六夜の形状を生成
        let crescentPath = WaningCrescentMoon.shape(center: center, radius: radius)

        // 放射グラデーションで塗る
        ctx.fill(
            crescentPath,
            with: .radialGradient(
                Gradient(colors: [
                    DesignTokens.MoonColors.centerColor,
                    DesignTokens.MoonColors.edgeColor
                ]),
                center: center,
                startRadius: radius * 0.08,
                endRadius: radius
            )
        )

        // 二十六夜のグロー効果（左側のみ）
        let glowArc = Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(120),
                endAngle: .degrees(240),
                clockwise: false
            )
        }

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.18))
            layer.blendMode = .normal
            layer.stroke(
                glowArc,
                with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.12)),
                style: StrokeStyle(
                    lineWidth: radius * 0.2,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
    .background(Color.black)
    .padding()
}
