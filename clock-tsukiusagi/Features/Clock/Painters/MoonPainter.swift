import SwiftUI

// MARK: - MoonPainter
enum MoonPainter {
    // MARK: - Colors
    private static let moonCenterColor = Color(hex: "#fff").opacity(0.95)
    private static let moonEdgeColor   = Color(hex: "#fff").opacity(0.6)

    // === GLOW: 外周アークだけ発光（ストローク→ブラー→内側を消す） ===
    static func draw(in ctx: GraphicsContext, size: CGSize, angle: Double, tone: SkyTone) {
        let radius = min(size.width, size.height) * 0.18
        let center = CGPoint(
            x: size.width * 0.5 + cos(angle.radian) * (size.width * 0.25),
            y: size.height * 0.45 + sin(angle.radian) * (size.height * 0.18)
        )

        // 位相とオフセット（実形生成と同一の定義に統一）
        let phase = calculateMoonPhase(from: angle)
        let s = (2 * phase - 1) * radius
        // Illumination indicator (0=new/thin, 1=full)
        let illum = max(0, min(1, 1 - abs(s) / radius))
        let glowSkipThreshold: CGFloat = 0.03
        // Helpers for interpolation
        func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
        func smooth(_ x: CGFloat) -> CGFloat { let t = max(0, min(1, x)); return t * t * (3 - 2 * t) }
        let t = smooth(illum)
        let isFullish = abs(s) < radius * 0.015 // near-full: shadow overlaps moon

        // 満月円 / 影円
        let moonRect   = CGRect(x: center.x - radius,     y: center.y - radius, width: 2*radius, height: 2*radius)
        let shadowRect = CGRect(x: center.x + s - radius, y: center.y - radius, width: 2*radius, height: 2*radius)
        let moonPath   = Path(ellipseIn: moonRect)
        let shadowPath = Path(ellipseIn: shadowRect)

        // --- 月本体（満月→影でくり抜き） ---
        ctx.drawLayer { body in
            body.fill(
                moonPath,
                with: .radialGradient(
                    Gradient(colors: [moonCenterColor, moonEdgeColor]),
                    center: .init(x: center.x, y: center.y),
                    startRadius: radius * 0.08,
                    endRadius: radius
                )
            )
            if !isFullish {
                body.blendMode = .destinationOut
                body.fill(shadowPath, with: .color(.black))
            }
        }

        // --- OUTER GLOW：月の縁に沿った“薄いリング領域”に限定（外へ出さず、内側寄り） ---
        // 外側は極小、内側へ広げる
        let outwardMax = radius * 0.01
        let inwardMax  = radius * 0.36
        let outerRect  = moonRect.insetBy(dx: -outwardMax, dy: -outwardMax) // わずかに拡大
        let innerRect  = moonRect.insetBy(dx:  inwardMax, dy:  inwardMax)   // だいぶ縮小
        var ringClip = Path()
        ringClip.addRect(CGRect(origin: .zero, size: size))
        ringClip.addEllipse(in: outerRect)
        ringClip.addEllipse(in: innerRect) // even-odd: Rect - (outer - inner) = 薄いリング

        // 点灯側の角度幅（位相に応じて補間）
        let isRightLit = phase < 0.5
        let wedgeSweep: Double = Double(lerp(120, 150, t))

        ctx.drawLayer { glow in
            if isFullish {
                // Full moon: use a 360° inward-biased ring halo (no wedge cap)
                let outer = moonRect.insetBy(dx: -radius * 0.02, dy: -radius * 0.02)
                let inner = moonRect.insetBy(dx:  radius * 0.32, dy:  radius * 0.32)
                var ring = Path()
                ring.addEllipse(in: outer)
                ring.addEllipse(in: inner)
                glow.clip(to: ring, style: FillStyle(eoFill: true))

                glow.blendMode = .plusLighter
                glow.addFilter(.blur(radius: radius * 0.35))
                glow.fill(moonPath, with: .color(Color.cyan.opacity(0.18)))

                glow.addFilter(.blur(radius: radius * 0.18))
                glow.fill(moonPath, with: .color(Color.white.opacity(0.05)))
            } else {
                glow.clip(to: ringClip, style: FillStyle(eoFill: true))
                // Skip glow entirely when extremely thin
                guard illum > glowSkipThreshold else { return }

                // 外周アークに沿ったストロークをぼかして重ねる（内側寄りに見えるよう控えめ）
                let startDeg: Double = isRightLit ? (360 - wedgeSweep / 2) : (180 - wedgeSweep / 2)
                let endDeg: Double   = isRightLit ? (wedgeSweep / 2)       : (180 + wedgeSweep / 2)
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
                        with: .color(Color.cyan.opacity(cyanAlpha)),
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
                        with: .color(Color.white.opacity(whiteAlpha)),
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
                        with: .color(Color.cyan.opacity(0.05)),
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
        let s = (2 * phase - 1) * radius

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

    // MARK: - Moon Phase Calculation（簡易）
    private static func calculateMoonPhase(from angle: Double) -> Double {
        let hour = (angle / 360.0) * 24.0
        switch hour {
        case 0..<6:   return 0.5 + (hour / 6.0) * 0.1
        case 6..<12:  return 0.1 - (hour - 6) / 6.0 * 0.1
        case 12..<18: return 0.0 + (hour - 12) / 6.0 * 0.1
        case 18..<24: return 0.1 + (hour - 18) / 6.0 * 0.4
        default:      return 0.0
        }
    }
}
