import SwiftUI

/// 十日夜テンプレート（右側が大きく光り、左端に少し影）
/// phase: 0.28〜0.47 の範囲で使用
enum WaxingGibbousMoon {
    /// 十日夜の形状を生成（2円法で正確に再現）
    /// - Parameters:
    ///   - center: 月の中心座標
    ///   - radius: 月の半径
    /// - Returns: 十日夜の形状を示すPath
    /// ターミネーターの柔らか化パス（凸月の境界線に曲率を加える）
    static func terminatorPath(center: CGPoint, radius: CGFloat) -> Path {
        let curvature: CGFloat = 0.12
        let jitter: CGFloat = 0.8
        let isRightLit = true  // 十日夜は右が明
        let sign: CGFloat = isRightLit ? 1 : -1

        // 凸月用: 境界が月の外側寄りなのでオフセットを調整
        let offset = radius * 0.35  // d値と同じ

        let steps = 96
        var terminator = Path()
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let yy = (t * 2 - 1) * radius
            let xr = curvature * sqrt(max(0, radius*radius - yy*yy))
            let j = (jitter > 0) ? CGFloat.random(in: -jitter...jitter) : 0
            let x = center.x + sign * (xr - offset) + j
            let y = center.y + yy
            (i == 0) ? terminator.move(to: CGPoint(x: x, y: y))
                     : terminator.addLine(to: CGPoint(x: x, y: y))
        }
        return terminator
    }

    static func shape(center: CGPoint, radius: CGFloat) -> Path {
        // 2円法の交点計算
        // 凸月（gibbous）は影円を月の外側に配置
        let c0 = center  // 月の中心
        let d: CGFloat = radius * 0.35  // 十日夜用: 小さめのdで大きな光部分
        let c1 = CGPoint(x: c0.x - d, y: c0.y)  // 影円の中心（右が明なので左へ）

        let a = d * 0.5
        let h2 = max(0, radius*radius - a*a)
        let h = sqrt(h2)
        let ux: CGFloat = -1.0, uy: CGFloat = 0.0  // c0→c1の方向
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

        // 凸月（isCrescent=NO）かつ右が明（rightLit=R）の場合
        // c0(Q→P, CW) + c1(Q→P, CW)
        var path = Path()
        path.move(to: CGPoint(x: px, y: py))
        path.addArc(center: c0, radius: radius, startAngle: th0Q, endAngle: th0P, clockwise: true)
        path.addArc(center: c1, radius: radius, startAngle: th1Q, endAngle: th1P, clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview
#Preview("Waxing Gibbous Moon Template") {
    Canvas { ctx, size in
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        let radius: CGFloat = min(size.width, size.height) * 0.18

        // 十日夜の形状を生成
        let gibbousPath = WaxingGibbousMoon.shape(center: center, radius: radius)

        // 放射グラデーションで塗る
        ctx.fill(
            gibbousPath,
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

        // 十日夜のグロー効果（右側中心）
        let glowArc = Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-80),
                endAngle: .degrees(80),
                clockwise: false
            )
        }

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.18))
            layer.blendMode = .normal
            layer.stroke(
                glowArc,
                with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.14)),
                style: StrokeStyle(
                    lineWidth: radius * 0.25,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
    .background(Color.black)
    .padding()
}
