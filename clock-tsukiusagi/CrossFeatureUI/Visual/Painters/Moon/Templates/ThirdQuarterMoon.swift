import SwiftUI

/// 下弦の月テンプレート（左が明るい半月）
enum ThirdQuarterMoon {
    /// 下弦の月の形状を生成（2円法で正確に再現）
    /// - Parameters:
    ///   - center: 月の中心座標
    ///   - radius: 月の半径
    /// - Returns: 下弦の月の形状を示すPath
    /// - 10/12の状態: c0(201, 276.3), c1(232.75, 276.3), d=31.7503, th0P=77.33°, th0Q=-77.33°
    static func shape(center: CGPoint, radius: CGFloat) -> Path {
        // 2円法の交点計算
        let c0 = center  // 月の中心
        let d: CGFloat = 31.7503  // 10/12の実測値
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

        // 凸月（isCrescent=NO）かつ左が明（rightLit=L=false）の場合
        // c0(P→Q, CCW) + c1(P→Q, CCW)
        var path = Path()
        path.move(to: CGPoint(x: px, y: py))
        path.addArc(center: c0, radius: radius, startAngle: th0P, endAngle: th0Q, clockwise: false)
        path.addArc(center: c1, radius: radius, startAngle: th1P, endAngle: th1Q, clockwise: false)
        path.closeSubpath()
        return path
    }

    /// ターミネーターの柔らか化パス（直線ターミネーターに曲率を加える）
    static func terminatorPath(center: CGPoint, radius: CGFloat, circleDistance: CGFloat = 0) -> Path {
        let curvature: CGFloat = 0.12
        let jitter: CGFloat = 0.8
        let isRightLit = false  // 下弦の月は常に左が明

        // Waxing(右が明) / Waning(左が明) - 統一されたisRightLitを使用
        let sign: CGFloat = isRightLit ? 1 : -1

        // 境界に重なるよう、中心位置を調整
        let steps = 96
        var terminator = Path()
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)          // 0→1
            let yy = (t * 2 - 1) * radius                     // -r→+r
            let xr = curvature * sqrt(max(0, radius*radius - yy*yy))
            // 境界に重なるよう、中心から少し外側にオフセット
            let isNearTwoCircleTransition = (circleDistance > radius * 0.2 && circleDistance < radius * 0.5)
            let offset = isNearTwoCircleTransition ? radius * 0.3 : radius * 0.2
            let j = (jitter > 0) ? (CGFloat.random(in: -jitter...jitter)) : 0
            let x = center.x + sign * (xr - offset) + j
            let y = center.y + yy
            (i == 0) ? terminator.move(to: CGPoint(x: x, y: y))
                     : terminator.addLine(to: CGPoint(x: x, y: y))
        }
        return terminator
    }
}

// MARK: - Preview
#Preview("Third Quarter Moon Template") {
    Canvas { ctx, size in
        // 10/12の状態を正確に再現するため、MoonGlyphと同じサイズを使用
        // center: CGPoint(x: 201, y: 276.3), radius: 72.36
        let center = CGPoint(x: 201.0, y: 276.3)
        let radius: CGFloat = 72.36

        // 下弦の月の形状を生成
        let quarterMoonPath = ThirdQuarterMoon.shape(center: center, radius: radius)

        // 放射グラデーションで塗る
        ctx.fill(
            quarterMoonPath,
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

        // ターミネーターの柔らか化
        // 10/12の状態: circleDistance=31.7503, threshold=36.18, hasTerminator=true
        let circleDistance: CGFloat = 31.7503
        let terminatorThreshold: CGFloat = radius * 0.5  // 36.18
        let hasTerminator = circleDistance < terminatorThreshold

        if hasTerminator {
            let terminatorPath = ThirdQuarterMoon.terminatorPath(
                center: center,
                radius: radius,
                circleDistance: circleDistance
            )
            ctx.drawLayer { layer in
                layer.clip(to: quarterMoonPath)
                layer.blendMode = .normal
                layer.addFilter(.blur(radius: 3.0))

                // Apply multiple stroke passes for feathering effect
                let passes = 20
                for p in 0..<passes {
                    let w = 3.0 * (1.6 - 0.25 * CGFloat(p))
                    layer.stroke(
                        terminatorPath,
                        with: .color(Color.black.opacity(0.6)),  // より濃い色でターミネーターを目立たせる
                        lineWidth: max(1, w)
                    )
                }
            }
        }

        // 下弦の月のグロー効果（左側のみ）
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

