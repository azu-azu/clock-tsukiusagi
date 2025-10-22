import SwiftUI

// MARK: - MoonPainter
enum MoonPainter {
    // MARK: - Colors
    private static let moonCenterColor = DesignTokens.MoonColors.centerColor
    private static let moonEdgeColor   = DesignTokens.MoonColors.edgeColor

    // === GLOW: 外周アークだけ発光（ストローク→ブラー→内側を消す） ===
    static func draw(in ctx: GraphicsContext, size: CGSize, phase: Double, tone: SkyTone) {
        let radius = min(size.width, size.height) * 0.18
        let center = CGPoint(
            x: size.width * 0.5,
            y: size.height * 0.45
        )

        // 位相とオフセット（二円法の余弦マッピング）
        // φ=0.25/0.75 → s=0 (perfect half-moon), φ=0.5 → s=-r (full), φ=0 → s=+r (new)
        let s = CGFloat(cos(2.0 * .pi * phase)) * radius
        // Glow intensity strategy
        let illum = glowIntensity(phase: phase, s: s, radius: radius)
        let glowSkipThreshold: CGFloat = 0.03
        // Helpers for interpolation
        func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
        func smooth(_ x: CGFloat) -> CGFloat { let t = max(0, min(1, x)); return t * t * (3 - 2 * t) }
        let t = smooth(illum)
        // Near-full detection: phase-based threshold (near φ=0.5)
        let isFullish = abs(phase - 0.5) < 0.02

        // 二円法による litPath 生成
        let shadowCenter = CGPoint(x: center.x + s, y: center.y)
        let litPath = makeLitPath(c0: center, c1: shadowCenter, r: radius, phase: phase, s: s)

        // --- 月本体（litPath を直接塗る） ---
        ctx.drawLayer { body in
            body.fill(
                litPath,
                with: .radialGradient(
                    Gradient(colors: [moonCenterColor, moonEdgeColor]),
                    center: .init(x: center.x, y: center.y),
                    startRadius: radius * 0.08,
                    endRadius: radius
                )
            )
        }

        // --- ターミネーターの柔らか化（四半期で強調） ---
        let quarterEmphasis = abs(sin(.pi * 2 * phase))          // 上弦/下弦で最大
        let k: CGFloat = 0.12 * quarterEmphasis + 0.02           // 曲率（直線→弧）
        var ctxMutable = ctx
        softenTerminator(&ctxMutable, center: center, radius: radius,
                        phase: phase, curvature: k, feather: 6, jitter: 0.8)

        // --- OUTER GLOW：月の縁に沿った"薄いリング領域"に限定（外へ出さず、内側寄り） ---
        // 外側は極小、内側へ広げる
        let moonRect = CGRect(x: center.x - radius, y: center.y - radius, width: 2*radius, height: 2*radius)
        let outwardMax = radius * 0.01
        let inwardMax  = radius * 0.36
        let outerRect  = moonRect.insetBy(dx: -outwardMax, dy: -outwardMax) // わずかに拡大
        let innerRect  = moonRect.insetBy(dx:  inwardMax, dy:  inwardMax)   // だいぶ縮小
        var ringClip = Path()
        ringClip.addRect(CGRect(origin: .zero, size: size))
        ringClip.addEllipse(in: outerRect)
        ringClip.addEllipse(in: innerRect) // even-odd: Rect - (outer - inner) = 薄いリング

        // 点灯側の角度幅（位相に応じて補間）
        let isRightLit = phase < 0.5  // First Quarter (φ<0.5) = right lit
        let wedgeSweep: Double = Double(lerp(120, 150, t))

        ctx.drawLayer { glow in
            if isFullish {
                // Full moon: use a 360° inward-biased ring halo (no wedge cap)
                let moonPath = Path(ellipseIn: moonRect)
                let outer = moonRect.insetBy(dx: -radius * 0.02, dy: -radius * 0.02)
                let inner = moonRect.insetBy(dx:  radius * 0.32, dy:  radius * 0.32)
                var ring = Path()
                ring.addEllipse(in: outer)
                ring.addEllipse(in: inner)
                glow.clip(to: ring, style: FillStyle(eoFill: true))

                glow.blendMode = .plusLighter
                glow.addFilter(.blur(radius: radius * 0.35))
                glow.fill(moonPath, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.18)))

                glow.addFilter(.blur(radius: radius * 0.18))
                glow.fill(moonPath, with: .color(DesignTokens.MoonColors.glowWhite.opacity(0.05)))
            } else {
                glow.clip(to: ringClip, style: FillStyle(eoFill: true))
                // Skip glow entirely when extremely thin
                guard illum > glowSkipThreshold else { return }

                // 外周アークに沿ったストロークをぼかして重ねる（内側寄りに見えるよう控えめ）
                // Center on lit side: 0° (right-lit), 180° (left-lit)
                let centerDeg: Double = isRightLit ? 0.0 : 180.0
                let startDeg: Double = centerDeg - wedgeSweep / 2
                let endDeg: Double   = centerDeg + wedgeSweep / 2
                var outerArc = Path()
                outerArc.addArc(center: center, radius: radius,
                                startAngle: .degrees(startDeg), endAngle: .degrees(endDeg), clockwise: false)

                // ベース青（端は丸キャップで自然にフェード）
                glow.drawLayer { layer in
                    let blurBase = lerp(radius * 0.18, radius * 0.28, t)
                    let cyanAlpha = lerp(0.15, 0.11, t)
                    layer.addFilter(.blur(radius: blurBase))
                    layer.blendMode = .normal
                    layer.stroke(
                        outerArc,
                        with: .color(DesignTokens.MoonColors.glowCyan.opacity(cyanAlpha)),
                        style: StrokeStyle(
                            lineWidth: radius * 0.28,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                // 白加算（ごく薄く）
                glow.drawLayer { layer in
                    let blurSoft = lerp(radius * 0.14, radius * 0.22, t)
                    let whiteAlpha = lerp(0.025, 0.035, t)
                    layer.addFilter(.blur(radius: blurSoft))
                    layer.blendMode = .plusLighter
                    layer.stroke(
                        outerArc,
                        with: .color(DesignTokens.MoonColors.glowWhite.opacity(whiteAlpha)),
                        style: StrokeStyle(
                            lineWidth: radius * 0.18,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                // 仕上げ青（極薄）
                glow.drawLayer { layer in
                    layer.addFilter(.blur(radius: lerp(radius * 0.20, radius * 0.36, t)))
                    layer.blendMode = .plusLighter
                    layer.stroke(
                        outerArc,
                        with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.05)),
                        style: StrokeStyle(
                            lineWidth: radius * 0.18,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
        }
    }

    // MARK: - Moon Shape Generation
    private static func getActualMoonShape(center: CGPoint, radius: CGFloat, phase: Double) -> Path {
        var path = Path()
        let s = CGFloat(sin(2.0 * .pi * phase)) * radius

        if phase < 0.5 {
            // 右側が光る（外側は右半分）
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
            let innerCenter = CGPoint(x: center.x + s, y: center.y)
            path.addArc(center: innerCenter, radius: radius,
                        startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        } else {
            // 左側が光る（外側は左半分）
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            let innerCenter = CGPoint(x: center.x - s, y: center.y)
            path.addArc(center: innerCenter, radius: radius,
                        startAngle: .degrees(270), endAngle: .degrees(90), clockwise: true)
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Two-Circle Lit Path Generation
    private static func makeLitPath(c0: CGPoint, c1: CGPoint, r: CGFloat, phase: Double, s: CGFloat) -> Path {
        let dx = c1.x - c0.x
        let dy = c1.y - c0.y
        let d = max(0.0, hypot(dx, dy))

        // Calculate illumination
        let illum = 0.5 * (1.0 - cos(2.0 * .pi * phase))

        // Edge cases
        if illum < 0.001 {
            return Path() // New moon - empty
        }
        if illum > 0.999 {
            return Path(ellipseIn: CGRect(x: c0.x - r, y: c0.y - r, width: 2*r, height: 2*r)) // Full moon
        }

        // Half-moon case (circles nearly coincident)
        if d < 1e-4 {
            let isRightLit = phase < 0.5  // First Quarter (φ<0.5) = right lit

            var path = Path()
            if isRightLit {
                // Right-lit: draw right semicircle (-90° to +90°)
                path.addArc(center: c0, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            } else {
                // Left-lit: draw left semicircle (+90° to +270°)
                path.addArc(center: c0, radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            }
            path.addLine(to: c0)
            path.closeSubpath()
            return path
        }

        // General case: calculate intersection points
        let a = d * 0.5
        let h2 = r * r - a * a

        if h2 <= 0 {
            // Circles don't intersect - fallback to half-moon
            let isRightLit = phase < 0.5  // First Quarter (φ<0.5) = right lit

            var path = Path()
            if isRightLit {
                // Right-lit: draw right semicircle (-90° to +90°)
                path.addArc(center: c0, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            } else {
                // Left-lit: draw left semicircle (+90° to +270°)
                path.addArc(center: c0, radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            }
            path.addLine(to: c0)
            path.closeSubpath()
            return path
        }

        let h = sqrt(h2)

        // Unit vector along line connecting centers
        let ux = dx / d
        let uy = dy / d

        // Midpoint between centers
        let mx = c0.x + a * ux
        let my = c0.y + a * uy

        // Intersection points (perpendicular to line connecting centers)
        let nx = -uy
        let ny = ux
        let px = mx + h * nx
        let py = my + h * ny
        let qx = mx - h * nx
        let qy = my - h * ny

        // Calculate angles for arc generation
        let angleFromCenter = { (cx: CGFloat, cy: CGFloat, x: CGFloat, y: CGFloat) -> Angle in
            Angle(radians: atan2(Double(y - cy), Double(x - cx)))
        }

        let th0P = angleFromCenter(c0.x, c0.y, px, py)
        let th0Q = angleFromCenter(c0.x, c0.y, qx, qy)
        let th1P = angleFromCenter(c1.x, c1.y, px, py)
        let th1Q = angleFromCenter(c1.x, c1.y, qx, qy)

        // Determine crescent vs gibbous and waxing vs waning
        let crescent = illum < 0.5
        let isRightLit = phase < 0.5  // First Quarter (φ<0.5) = right lit

        var path = Path()

        if crescent {
            // Crescent: narrow arcs
            path.move(to: CGPoint(x: px, y: py))
            path.addArc(center: c0, radius: r, startAngle: th0P, endAngle: th0Q, clockwise: isRightLit ? false : true)
            path.addArc(center: c1, radius: r, startAngle: th1Q, endAngle: th1P, clockwise: isRightLit ? false : true)
            path.closeSubpath()
        } else {
            // Gibbous: wide arcs (complement)
            path.move(to: CGPoint(x: px, y: py))
            path.addArc(center: c0, radius: r, startAngle: th0P, endAngle: th0Q, clockwise: isRightLit ? true : false)
            path.addArc(center: c1, radius: r, startAngle: th1Q, endAngle: th1P, clockwise: isRightLit ? true : false)
            path.closeSubpath()
        }

        return path
    }

    // MARK: - Terminator Softening
    private static func softenTerminator(
        _ ctx: inout GraphicsContext,
        center c: CGPoint,
        radius r: CGFloat,
        phase φ: Double,
        curvature k: CGFloat,       // 0 = 直線, 0.1〜0.18 くらいが自然
        feather: CGFloat,           // 3〜10px くらい
        jitter: CGFloat = 0         // 0〜2px（テクスチャのザラつき）
    ) {
        // Waxing(右が明) / Waning(左が明)
        let waxing = (φ > 0 && φ < 0.5)
        let sign: CGFloat = waxing ? 1 : -1

        // ターミネーター曲線 x(y) = sign * k * sqrt(r^2 - y^2)
        // 境界に重なるよう、中心位置を調整
        let steps = 96
        var terminator = Path()
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)          // 0→1
            let yy = (t * 2 - 1) * r                     // -r→+r
            let xr = k * sqrt(max(0, r*r - yy*yy))
            // 境界に重なるよう、中心から少し外側にオフセット
            let offset = r * 0.1  // 境界に重なるよう調整
            let j = (jitter > 0) ? (CGFloat.random(in: -jitter...jitter)) : 0
            let x = c.x + sign * (xr - offset) + j
            let y = c.y + yy
            (i == 0) ? terminator.move(to: CGPoint(x: x, y: y))
                     : terminator.addLine(to: CGPoint(x: x, y: y))
        }

        // ① ぼかしレイヤーを作成（デバッグ用：赤で可視化）
        ctx.drawLayer { layer in
            // ブラーで"ふち"を柔らかく
            layer.addFilter(.blur(radius: feather))

            // ② フェザー帯を何回か重ね塗り（中心が濃く端が薄いイメージ）
            let passes = 5
            for p in 0..<passes {
                let w = feather * (1.6 - 0.25 * CGFloat(p))   // 少しずつ細く
                let a = 0.22 - 0.03 * Double(p)               // 少しずつ薄く
                layer.stroke(
                    terminator,
                    with: .color(.black.opacity(a)),             // デバッグ用：赤で可視化
                    lineWidth: max(1, w)
                )
            }
        }
    }

    // MARK: - Glow Intensity Strategy
    private enum GlowCurve {
        case astronomical
        case legacy
        case blend(weight: Double) // 0.0=legacy, 1.0=astronomical
    }

    private static let glowCurveStrategy: GlowCurve = .blend(weight: 0.6)

    @inline(__always)
    private static func illumAstronomical(_ phase: Double) -> CGFloat {
        let v = 0.5 * (1.0 - cos(2.0 * .pi * phase))
        return CGFloat(max(0.0, min(1.0, v)))
    }

    @inline(__always)
    private static func illumLegacy(from s: CGFloat, radius r: CGFloat) -> CGFloat {
        let v = 1.0 - abs(s) / r
        return max(0.0, min(1.0, v))
    }

    @inline(__always)
    private static func glowIntensity(phase: Double, s: CGFloat, radius r: CGFloat) -> CGFloat {
        switch glowCurveStrategy {
        case .astronomical:
            return illumAstronomical(phase)
        case .legacy:
            return illumLegacy(from: s, radius: r)
        case .blend(let w):
            let a = Double(illumAstronomical(phase))
            let l = Double(illumLegacy(from: s, radius: r))
            let v = (1.0 - w) * l + w * a
            return CGFloat(max(0.0, min(1.0, v)))
        }
    }
}
