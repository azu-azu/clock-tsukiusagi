import SwiftUI

/// 左向き三日月（細）テンプレート（左が明るい細い三日月）
enum CrescentLeftThin {
    /// 左向き三日月（細）の形状を生成（2円法で正確に再現）
    /// - Parameters:
    ///   - center: 月の中心座標
    ///   - radius: 月の半径
    /// - Returns: 左向き三日月（細）の形状を示すPath
    /// - 11/10の状態: c0(201, 276.3), c1(239.87, 276.3), d=38.8732, th0P=74.42°, th0Q=-74.42°
    static func shape(center: CGPoint, radius: CGFloat) -> Path {
        // 2円法の交点計算
        let c0 = center  // 月の中心
        let d: CGFloat = 38.8732  // 11/10の実測値
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

        // 三日月（isCrescent=YES）かつ左が明（rightLit=L=false）の場合
        // c0(Q→P, CW) + c1(P→Q, CCW)
        var path = Path()
        path.move(to: CGPoint(x: px, y: py))
        path.addArc(center: c0, radius: radius, startAngle: th0Q, endAngle: th0P, clockwise: true)
        path.addArc(center: c1, radius: radius, startAngle: th1P, endAngle: th1Q, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview
#Preview("Crescent Left Thin Template") {
    Canvas { ctx, size in
        // 11/10の状態を正確に再現するため、MoonGlyphと同じサイズを使用
        // center: CGPoint(x: 201, y: 276.3), radius: 72.36
        let center = CGPoint(x: 201.0, y: 276.3)
        let radius: CGFloat = 72.36

        // 左向き三日月（細）の形状を生成
        let crescentPath = CrescentLeftThin.shape(center: center, radius: radius)

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

        // 三日月にはターミネーターを表示しない（circleDistance < threshold で false）

        // 左向き三日月のグロー効果（左側のみ）
        let glowArc = Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(270),
                clockwise: false
            )
        }

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.18))
            layer.blendMode = .normal
            layer.stroke(
                glowArc,
                with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.15)),
                style: StrokeStyle(
                    lineWidth: radius * 0.28,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
    .background(Color.black)
    .padding()
}

