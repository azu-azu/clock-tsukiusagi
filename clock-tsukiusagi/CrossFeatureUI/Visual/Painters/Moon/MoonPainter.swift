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

        // デバッグログ
        #if DEBUG
        let d = hypot(c1.x - c0.x, c1.y - c0.y)
        let threshold = r * 0.02
        print(String(format: "MoonPainter: φ=%.6f  rightLit=%@  offset=%.4f  d=%.4f  r=%.2f  threshold=%.4f  isHalfMoon=%@",
                    φ, isRightLit ? "R" : "L", offset, d, r, threshold, d < threshold ? "YES" : "NO"))
        #endif

        // 白い"明部"の輪郭（2円法）
        let lit = makeLitPath(c0: c0, c1: c1, r: r, phase: φ, isRightLit: isRightLit, offset: offset)

        // 塗る（backup と同じ放射グラデーション）
        ctx.fill(
            lit,
            with: .radialGradient(
                Gradient(colors: [DesignTokens.MoonColors.centerColor, DesignTokens.MoonColors.edgeColor]),
                center: .init(x: c0.x, y: c0.y),
                startRadius: r * 0.08,
                endRadius: r
            )
        )

        // 2円法でターミネーターが存在する時に柔らか化を適用
        let circleDistance = hypot(c1.x - c0.x, c1.y - c0.y)
        let terminatorThreshold = r * 0.5  // 2円が近く交差している範囲（距離 < 0.5r）
        #if DEBUG
        print("MoonPainter: circleDistance=\(circleDistance), terminatorThreshold=\(terminatorThreshold), hasTerminator=\(circleDistance < terminatorThreshold)")
        #endif
        if circleDistance < terminatorThreshold {
            softenTerminator(ctx: ctx, center: c0, radius: r, isRightLit: isRightLit, litPath: lit, tone: tone, circleDistance: circleDistance)
        }

        // 青いグロー効果を追加（月本体の描画の後）
        addGlowEffect(ctx: ctx, litPath: lit, center: c0, radius: r, phase: φ, isRightLit: isRightLit)
    }

    // MARK: - Two-circle shape
    private static func makeLitPath(
        c0: CGPoint, c1: CGPoint, r: CGFloat, phase φ: Double, isRightLit: Bool, offset: CGFloat
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
        // 厳しい条件で半月判定（約±0.5日程度）
        let threshold = r * 0.02
        #if DEBUG
        print(String(format: "makeLitPath: d=%.4f  threshold=%.4f  isHalfMoon=%@", d, threshold, d < threshold ? "YES" : "NO"))
        #endif

        if d < threshold {
            #if DEBUG
            print("makeLitPath: Using half-moon path")
            #endif
            var p = Path()
            if isRightLit {
                p.addArc(center: c0, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            } else {
                p.addArc(center: c0, radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            }
            p.addLine(to: c0); p.closeSubpath()
            return p
        }

        #if DEBUG
        print("makeLitPath: Using two-circle path")
        #endif

        // 交点（P,Q）
        let a  = d * 0.5
        let h2 = max(0, r*r - a*a)
        let h  = sqrt(h2)
        let ux = dx/d,  uy = dy/d
        let mx = c0.x + a*ux, my = c0.y + a*uy
        let nx = -uy, ny = ux
        let px = mx + h*nx, py = my + h*ny
        let qx = mx - h*nx, qy = my - h*ny

        #if DEBUG
        print(String(format: "Circle centers: c0(%.2f,%.2f) c1(%.2f,%.2f)", c0.x, c0.y, c1.x, c1.y))
        print(String(format: "Intersection calc: a=%.2f h2=%.2f h=%.2f", a, h2, h))
        print(String(format: "Unit vector: ux=%.4f uy=%.4f nx=%.4f ny=%.4f", ux, uy, nx, ny))
        #endif

        func ang(_ cx: CGFloat, _ cy: CGFloat, _ x: CGFloat, _ y: CGFloat) -> Angle {
            .radians(atan2(Double(y - cy), Double(x - cx)))
        }
        let th0P = ang(c0.x, c0.y, px, py)
        let th0Q = ang(c0.x, c0.y, qx, qy)
        let th1P = ang(c1.x, c1.y, px, py)
        let th1Q = ang(c1.x, c1.y, qx, qy)

        #if DEBUG
        print(String(format: "Two-circle: P(%.2f,%.2f) Q(%.2f,%.2f) h=%.2f", px, py, qx, qy, h))
        print(String(format: "Angles: th0P=%.2f th0Q=%.2f th1P=%.2f th1Q=%.2f",
                    th0P.degrees, th0Q.degrees, th1P.degrees, th1Q.degrees))
        #endif

        // offsetが大きいほど三日月、小さいほど凸月
        // より厳しい閾値で凸月判定（下弦の1日前も凸月として表示）
        let isCrescent = offset > r * 0.5
        var path = Path()
        path.move(to: CGPoint(x: px, y: py))

        #if DEBUG
        print(String(format: "Path: isCrescent=%@ rightLit=%@ illum=%.2f",
                    isCrescent ? "YES" : "NO", isRightLit ? "R" : "L", illum))
        #endif

        // 2円法の正しいロジック
        if isRightLit {
            // 右が明るい場合
            if isCrescent {
                // 右が明るい三日月：右側のアーク（c0）と左側のターミネーター（c1）
                path.addArc(center: c0, radius: r, startAngle: th0P, endAngle: th0Q, clockwise: false)
                path.addArc(center: c1, radius: r, startAngle: th1Q, endAngle: th1P, clockwise: true)
            } else {
                // 右が明るい凸月：右側の大部分（c0）と左側の一部（c1）
                path.addArc(center: c0, radius: r, startAngle: th0Q, endAngle: th0P, clockwise: true)
                path.addArc(center: c1, radius: r, startAngle: th1Q, endAngle: th1P, clockwise: true)
            }
        } else {
            // 左が明るい場合
            if isCrescent {
                // 左が明るい三日月：左側のアーク（c0）と右側のターミネーター（c1）
                path.addArc(center: c0, radius: r, startAngle: th0Q, endAngle: th0P, clockwise: true)
                path.addArc(center: c1, radius: r, startAngle: th1P, endAngle: th1Q, clockwise: false)
            } else {
                // 左が明るい凸月：左側の大部分（c0）と右側の一部（c1）
                path.addArc(center: c0, radius: r, startAngle: th0P, endAngle: th0Q, clockwise: false)
                path.addArc(center: c1, radius: r, startAngle: th1P, endAngle: th1Q, clockwise: false)
            }
        }

        path.closeSubpath()
        return path
    }

    // MARK: - Glow Effect
    private static func addGlowEffect(
        ctx: GraphicsContext,
        litPath: Path,
        center: CGPoint,
        radius: CGFloat,
        phase: Double,
        isRightLit: Bool
    ) {
        // 天文学的照度
        let astroIllum = CGFloat(0.5 * (1.0 - cos(2.0 * .pi * phase)))

        // 動的な閾値調整: 極細の時はより厳しく、通常時は緩く
        let baseGlowThreshold: CGFloat = 0.03
        let dynamicGlowThreshold = astroIllum < 0.1 ? baseGlowThreshold * 2.0 : baseGlowThreshold

        // 極細三日月の判定
        let thinCrescentThreshold: Double = 0.15
        let isThinCrescent = astroIllum <= thinCrescentThreshold

        // 満月近くの判定
        let fullMoonThreshold: Double = 0.95
        let fullMoonTransition: Double = 0.08
        let isFullish = (abs(phase - 0.5) < fullMoonTransition) || (astroIllum > fullMoonThreshold)

        // 月の境界に沿ったリング領域を作成
        let moonRect = CGRect(x: center.x - radius, y: center.y - radius, width: 2*radius, height: 2*radius)
        let outwardMax = radius * 0.01
        let inwardMax = radius * 0.36
        let outerRect = moonRect.insetBy(dx: -outwardMax, dy: -outwardMax)
        let innerRect = moonRect.insetBy(dx: inwardMax, dy: inwardMax)

        var ringClip = Path()
        ringClip.addRect(CGRect(origin: .zero, size: CGSize(width: 1000, height: 1000)))
        ringClip.addEllipse(in: outerRect)
        ringClip.addEllipse(in: innerRect) // even-odd: 外側 - 内側 = リング

        ctx.drawLayer { glow in
            if isFullish {
                // 満月: クリップなしで直接ぼかし効果を適用
                let moonPath = Path(ellipseIn: moonRect)

                // 内側のブルーグロー（ぼかし効果付き）
                glow.drawLayer { layer in
                    layer.blendMode = .normal
                    layer.addFilter(.blur(radius: radius * 0.25))
                    layer.fill(moonPath, with: .color(Color.cyan.opacity(0.15)))
                }

                // 外側の白いグロー（ぼかし効果付き）
                glow.drawLayer { layer in
                    layer.blendMode = .plusLighter
                    layer.addFilter(.blur(radius: radius * 0.18))
                    layer.fill(moonPath, with: .color(Color.white.opacity(0.05)))
                }

                // 外側への拡散グロー
                glow.drawLayer { layer in
                    layer.blendMode = .plusLighter
                    layer.addFilter(.blur(radius: radius * 0.45))
                    layer.fill(moonPath, with: .color(Color.cyan.opacity(0.08)))
                }
            } else if !isThinCrescent {
                // 極細三日月以外: 通常のグロー処理
                glow.clip(to: ringClip, style: FillStyle(eoFill: true))

                // Skip glow entirely when extremely thin (動的閾値使用)
                guard astroIllum > dynamicGlowThreshold else { return }

                // 明るい側の角度幅
                let centerDeg: Double = isRightLit ? 0.0 : 180.0
                let wedgeSweep: Double = 120.0
                let startDeg: Double = centerDeg - wedgeSweep / 2
                let endDeg: Double = centerDeg + wedgeSweep / 2

                var outerArc = Path()
                outerArc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startDeg),
                    endAngle: .degrees(endDeg),
                    clockwise: false
                )

                // ベース青（端は丸キャップで自然にフェード）
                glow.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.18))
                    layer.blendMode = .normal
                    layer.stroke(
                        outerArc,
                        with: .color(Color.cyan.opacity(0.15)),
                        style: StrokeStyle(
                            lineWidth: radius * 0.28,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                // 白加算（ごく薄く）
                glow.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.14))
                    layer.blendMode = .plusLighter
                    layer.stroke(
                        outerArc,
                        with: .color(Color.white.opacity(0.025)),
                        style: StrokeStyle(
                            lineWidth: radius * 0.18,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                // 仕上げ青（極薄）
                glow.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.20))
                    layer.blendMode = .plusLighter
                    layer.stroke(
                        outerArc,
                        with: .color(Color.cyan.opacity(0.05)),
                        style: StrokeStyle(
                            lineWidth: radius * 0.18,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
            // 極細三日月ではグロー効果を完全に無効化
        }
    }

    // MARK: - Terminator Softening
    private static func softenTerminator(
        ctx: GraphicsContext,
        center c: CGPoint,
        radius r: CGFloat,
        isRightLit: Bool,
        litPath: Path,
        tone: SkyTone,
        circleDistance d: CGFloat
    ) {
        #if DEBUG
        print("softenTerminator: center=\(c), radius=\(r), isRightLit=\(isRightLit), d=\(d), isNearTwoCircleTransition=\(d > r * 0.2 && d < r * 0.5)")
        #endif

        // ターミネーターの曲率パラメータ
        let curvature: CGFloat = 0.12
        let feather: CGFloat = 3.0
        let jitter: CGFloat = 0.8

        // Waxing(右が明) / Waning(左が明) - 統一されたisRightLitを使用
        let sign: CGFloat = isRightLit ? 1 : -1

        // ターミネーター曲線 x(y) = sign * k * sqrt(r^2 - y^2)
        // 境界に重なるよう、中心位置を調整
        let steps = 96
        var terminator = Path()
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)          // 0→1
            let yy = (t * 2 - 1) * r                     // -r→+r
            let xr = curvature * sqrt(max(0, r*r - yy*yy))
            // 境界に重なるよう、中心から少し外側にオフセット
            // 2円法の直後と直前（10/12, 10/16付近）では境界により近づける
            let isNearTwoCircleTransition = (d > r * 0.2 && d < r * 0.5)  // 2円法の直後と直前の範囲（上限を調整）
            let offset = isNearTwoCircleTransition ? r * 0.3 : r * 0.2
            let j = (jitter > 0) ? (CGFloat.random(in: -jitter...jitter)) : 0
            let x = c.x + sign * (xr - offset) + j
            let y = c.y + yy
            (i == 0) ? terminator.move(to: CGPoint(x: x, y: y))
                     : terminator.addLine(to: CGPoint(x: x, y: y))
        }

        // Apply terminator softening with clipping to lit portion
        ctx.drawLayer { layer in
            layer.clip(to: litPath)
            layer.blendMode = .normal
            layer.addFilter(.blur(radius: feather))

            // Apply multiple stroke passes for feathering effect
            let passes = 20
            for p in 0..<passes {
                let w = feather * (1.6 - 0.25 * CGFloat(p))
                layer.stroke(
                    terminator,
                    with: .color(Color.black.opacity(0.6)),  // より濃い色でターミネーターを目立たせる
                    lineWidth: max(1, w)
                )
            }
        }
    }
}
