import SwiftUI

/// 0=新月, 0.25=上弦, 0.5=満月, 0.75=下弦 の位相だけで
/// "白い本体"を正しく描く最小実装（グロー等なし）
enum MoonPainter {

    // MARK: - Phase normalization (0..1, rad, deg, days を受け入れ)
    @inline(__always)
    private static func normalizePhase(_ p: Double) -> Double {
        let twoPi = 2.0 * .pi, synodic = 29.530588861
        let ap = abs(p)
        let x: Double =
              ap <= 1.0                 ? p                    // already [0,1]
            : ap <= twoPi + 1e-6        ? p / twoPi            // radians -> turn
            : ap <= 360.0 + 1e-6        ? p / 360.0            // degrees -> turn
            : ap <= synodic + 2         ? p / synodic          // days from new
            : p
        var n = x - floor(x); if n < 0 { n += 1.0 }; return n  // [0,1)
    }

    // MARK: - Public API
    static func draw(in ctx: GraphicsContext, size: CGSize, phase: Double, tone: SkyTone) {
        let r = min(size.width, size.height) * 0.18
        let c0 = CGPoint(x: size.width * 0.5, y: size.height * 0.45)

        // 位相 φ（絶対にシフトしない）
        let φ = normalizePhase(phase)

        // 向き：sin(2πφ) > 0 なら右が明（waxing）、<0 なら左が明（waning）
        let isRightLit = sin(2.0 * .pi * φ) > 0

        // 影円は常に"暗い側"に置く：右が明→左に、左が明→右に
        let offset = CGFloat(abs(cos(2.0 * .pi * φ))) * r
        let c1 = CGPoint(x: c0.x + (isRightLit ? -offset : +offset), y: c0.y)

        // 白い“明部”の輪郭（2円法）
        let lit = makeLitPath(c0: c0, c1: c1, r: r, phase: φ, isRightLit: isRightLit)

        // 塗る（単色。必要なら .radialGradient に差し替え可）
        let bodyColor = Color.white.opacity(0.95)
        ctx.fill(lit, with: .color(bodyColor))
    }

    // MARK: - Two-circle shape
    private static func makeLitPath(
        c0: CGPoint, c1: CGPoint, r: CGFloat, phase φ: Double, isRightLit: Bool
    ) -> Path {

        // 照度（天文学的）0..1
        let illum = CGFloat(0.5 * (1.0 - cos(2.0 * .pi * φ)))

        // 端の扱い
        if illum < 0.001 { return Path() } // 新月 ≒ 何も描かない
        if illum > 0.999 {
            return Path(ellipseIn: CGRect(x: c0.x - r, y: c0.y - r, width: 2*r, height: 2*r))
        }

        // 円心距離
        let dx = c1.x - c0.x, dy = c1.y - c0.y
        let d = max(0.0, hypot(dx, dy))

        // ほぼ半月（d≈0）は直線ターミネーターの半円
        if d < 1e-4 {
            var p = Path()
            if isRightLit {
                p.addArc(center: c0, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            } else {
                p.addArc(center: c0, radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            }
            p.addLine(to: c0); p.closeSubpath()
            return p
        }

        // 交点（P,Q）
        let a  = d * 0.5
        let h2 = max(0, r*r - a*a)
        let h  = sqrt(h2)
        let ux = dx/d,  uy = dy/d
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

        let isCrescent = illum < 0.5
        var path = Path()
        path.move(to: CGPoint(x: px, y: py))

        if isCrescent {
            // 三日月系
            if isRightLit {
                path.addArc(center: c0, radius: r, startAngle: th0P, endAngle: th0Q, clockwise: false)
                path.addArc(center: c1, radius: r, startAngle: th1Q, endAngle: th1P, clockwise: true)
            } else {
                path.addArc(center: c0, radius: r, startAngle: th0Q, endAngle: th0P, clockwise: true)
                path.addArc(center: c1, radius: r, startAngle: th1P, endAngle: th1Q, clockwise: false)
            }
        } else {
            // 凸月系
            if isRightLit {
                path.addArc(center: c0, radius: r, startAngle: th0Q, endAngle: th0P, clockwise: true)
                path.addArc(center: c1, radius: r, startAngle: th1Q, endAngle: th1P, clockwise: true)
            } else {
                path.addArc(center: c0, radius: r, startAngle: th0P, endAngle: th0Q, clockwise: false)
                path.addArc(center: c1, radius: r, startAngle: th1P, endAngle: th1Q, clockwise: false)
            }
        }

        path.closeSubpath()
        return path
    }
}
