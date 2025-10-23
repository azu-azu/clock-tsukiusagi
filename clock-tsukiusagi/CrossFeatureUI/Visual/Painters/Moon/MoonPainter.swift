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
        // Glow intensity for halo strength (visual only) and astronomical illumination for geometry
        let illum = glowIntensity(phase: phase, s: s, radius: radius)
        let astroIllum = illumAstronomical(phase)
        // 動的な閾値調整: 極細の時はより厳しく、通常時は緩く
        let baseGlowThreshold: CGFloat = 0.03
        let dynamicGlowThreshold = astroIllum < 0.1 ? baseGlowThreshold * 2.0 : baseGlowThreshold
        // Helpers for interpolation
        func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
        func smooth(_ x: CGFloat) -> CGFloat { let t = max(0, min(1, x)); return t * t * (3 - 2 * t) }
        let t = smooth(illum)
        // Near-full detection: より滑らかな遷移
        let fullMoonThreshold: Double = 0.95
        let fullMoonTransition: Double = 0.08  // より広い遷移範囲
        let isFullish = (abs(phase - 0.5) < fullMoonTransition) || (astroIllum > fullMoonThreshold)

        // 極細三日月の判定（早期定義）
        let thinCrescentThreshold: Double = 0.15  // 15%以下は極細とみなす
        let isThinCrescent = astroIllum <= thinCrescentThreshold

        // ※ 幾何も左右も s に従わせて"同じソース"にする
        let shadowCenter = CGPoint(x: center.x + s, y: center.y)
        let isRightLit = s < 0   // 影円を +s に置くなら、明部は s<0 が右、s>0 は左
        let litPath = isThinCrescent ?
            makeSmoothThinCrescentPath(center: center, radius: radius, isRightLit: isRightLit, illumination: astroIllum) :
            makeLitPath(c0: center, c1: shadowCenter, r: radius, phase: phase, s: s, illumination: astroIllum, isRightLit: isRightLit)

        // --- 月本体（litPath を直接塗る） ---
        ctx.drawLayer { body in
            if isThinCrescent {
                // 極細三日月: 明るい部分だけを描画、ストロークは一切描画しない
                body.fill(
                    litPath,
                    with: .radialGradient(
                        Gradient(colors: [moonCenterColor, moonEdgeColor]),
                        center: .init(x: center.x, y: center.y),
                        startRadius: radius * 0.08,
                        endRadius: radius
                    )
                )
                // ストロークを完全に無効化（境界線を一切描画しない）
            } else {
                // 通常の月: 従来通りの描画
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
        }

        // --- 境界グラデーション（直線部分を薄く） ---
        // 極細三日月では境界グラデーションを無効化（ターミネーターを目立たせない）
        if !isThinCrescent {
            let (boundaryGradient, gradientWidth) = createBoundaryGradient(
                center: center, radius: radius, phase: phase, isRightLit: isRightLit
            )
            ctx.drawLayer { gradient in
                // 月の明るい部分（litPath）との交差部分のみにグラデーションを適用
                gradient.clip(to: litPath)

                // 境界で濃く、弧の方に向かって薄くなるグラデーション（段階的フェード）
                let gradientColors = [
                    tone.gradEnd.opacity(1.0),    // 境界側：濃い背景色
                    tone.gradEnd.opacity(0.8),    // 少し薄く
                    tone.gradEnd.opacity(0.4),    // さらに薄く
                    tone.gradEnd.opacity(0.1),    // ほぼ透明
                    Color.clear                    // 完全に透明
                ]

                if isRightLit {
                    // 右側が明るい場合：中央（直線境界）から右（弧）へ
                    gradient.fill(
                        boundaryGradient,
                        with: .linearGradient(
                            Gradient(colors: gradientColors),
                            startPoint: CGPoint(x: center.x, y: center.y),
                            endPoint: CGPoint(x: center.x + gradientWidth, y: center.y)
                        )
                    )
                } else {
                    // 左側が明るい場合：中央（直線境界）から左（弧）へ
                    gradient.fill(
                        boundaryGradient,
                        with: .linearGradient(
                            Gradient(colors: gradientColors),
                            startPoint: CGPoint(x: center.x, y: center.y),
                            endPoint: CGPoint(x: center.x - gradientWidth, y: center.y)
                        )
                    )
                }
            }
        }

        // --- ターミネーターの柔らか化（半月近辺のみ適用、極細三日月では無効化） ---
        // φ が 0.25±δ または 0.75±δ の範囲のみ許可し、極細三日月では適用しない
        let delta: Double = 0.035
        let nearFirstQuarter  = abs(phase - 0.25) < delta
        let nearThirdQuarter  = abs(phase - 0.75) < delta

        if (nearFirstQuarter || nearThirdQuarter) && !isThinCrescent {
            let quarterEmphasis = CGFloat(1.0) // 四半期のみなので常に最大で良い
            let k: CGFloat = 0.12 * quarterEmphasis + 0.02           // 曲率（直線→弧）
            var ctxMutable = ctx
            softenTerminator(&ctxMutable, center: center, radius: radius,
                            phase: phase, tone: tone, litPath: litPath, curvature: k, feather: 3, jitter: 0.8)
        }

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
        let wedgeSweep: Double = Double(lerp(120, 150, t))

        ctx.drawLayer { glow in
            if isFullish {
                // Full moon: クリップなしで直接ぼかし効果を適用
                let moonPath = Path(ellipseIn: moonRect)

                // 内側のブルーグロー（ぼかし効果付き）
                glow.drawLayer { layer in
                    layer.blendMode = .normal
                    layer.addFilter(.blur(radius: radius * 0.25))
                    layer.fill(moonPath, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.15)))
                }

                // 外側の白いグロー（ぼかし効果付き）
                glow.drawLayer { layer in
                    layer.blendMode = .plusLighter
                    layer.addFilter(.blur(radius: radius * 0.18))
                    layer.fill(moonPath, with: .color(DesignTokens.MoonColors.glowWhite.opacity(0.05)))
                }

                // 外側への拡散グロー
                glow.drawLayer { layer in
                    layer.blendMode = .plusLighter
                    layer.addFilter(.blur(radius: radius * 0.45))
                    layer.fill(moonPath, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.08)))
                }
            } else if !isThinCrescent {
                // 極細三日月以外: 通常のグロー処理
                glow.clip(to: ringClip, style: FillStyle(eoFill: true))
                // Skip glow entirely when extremely thin (動的閾値使用)
                guard illum > dynamicGlowThreshold else { return }

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
            // 極細三日月ではグロー効果を完全に無効化（境界線を目立たせない）
        }
    }


    // MARK: - Smooth Thin Crescent Path Generation
    private static func makeSmoothThinCrescentPath(
        center: CGPoint, radius: CGFloat, isRightLit: Bool, illumination: CGFloat
    ) -> Path {
        // 極細三日月: 単純な弧を使用して鋭い境界線を避ける
        let crescentWidth = radius * CGFloat(illumination) * 2.0  // 照明度に応じた幅

        var path = Path()

        if isRightLit {
            // 右側が明るい: 右側の弧を描画
            let startAngle: Angle = .degrees(-90)
            let endAngle: Angle = .degrees(90)
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)

            // 内側の弧で三日月の形を作る
            let innerRadius = radius - crescentWidth
            if innerRadius > 0 {
                path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
            }
        } else {
            // 左側が明るい: 左側の弧を描画
            let startAngle: Angle = .degrees(90)
            let endAngle: Angle = .degrees(270)
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)

            // 内側の弧で三日月の形を作る
            let innerRadius = radius - crescentWidth
            if innerRadius > 0 {
                path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
            }
        }

        path.closeSubpath()
        return path
    }

    // MARK: - Two-Circle Lit Path Generation (final & robust)
    private static func makeLitPath(
        c0: CGPoint, c1: CGPoint, r: CGFloat,
        phase: Double, s: CGFloat, illumination illum: CGFloat,
        isRightLit: Bool
    ) -> Path {

        // 1) 端ケース
        if illum < 0.001 { return Path() } // new
        if illum > 0.999 { // full
            return Path(ellipseIn: CGRect(x: c0.x - r, y: c0.y - r, width: 2*r, height: 2*r))
        }

        // 幾何
        let dx = c1.x - c0.x, dy = c1.y - c0.y
        let d  = max(0.0, hypot(dx, dy))
        // 同心（≒半月）近傍は半円で出す
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

        // 2) 交点計算
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

        // 3) 明るさタイプ
        let crescent = illum < 0.5   // 三日月系 / 凸月系

        // 4) 単一輪郭で確実に閉じる（P→Q→P）
        var path = Path()
        path.move(to: CGPoint(x: px, y: py))

        if crescent {
            if isRightLit {
                // 右が点灯の三日月: c0(P→Q, CCW) + c1(Q→P, CW)
                path.addArc(center: c0, radius: r, startAngle: th0P, endAngle: th0Q, clockwise: false)
                path.addArc(center: c1, radius: r, startAngle: th1Q, endAngle: th1P, clockwise: true)
            } else {
                // 左が点灯の三日月: c0(Q→P, CW) + c1(P→Q, CCW)
                path.addArc(center: c0, radius: r, startAngle: th0Q, endAngle: th0P, clockwise: true)
                path.addArc(center: c1, radius: r, startAngle: th1P, endAngle: th1Q, clockwise: false)
            }
        } else {
            if isRightLit {
                // 右が点灯の凸月: c0(Q→P, CW) + c1(Q→P, CW)（補側）
                path.addArc(center: c0, radius: r, startAngle: th0Q, endAngle: th0P, clockwise: true)
                path.addArc(center: c1, radius: r, startAngle: th1Q, endAngle: th1P, clockwise: true)
            } else {
                // 左が点灯の凸月: c0(P→Q, CCW) + c1(P→Q, CCW)
                path.addArc(center: c0, radius: r, startAngle: th0P, endAngle: th0Q, clockwise: false)
                path.addArc(center: c1, radius: r, startAngle: th1P, endAngle: th1Q, clockwise: false)
            }
        }

        path.closeSubpath()
        return path
    }

    // MARK: - Boundary Gradient
    private static func createBoundaryGradient(
        center: CGPoint, radius: CGFloat, phase: Double, isRightLit: Bool
    ) -> (path: Path, width: CGFloat) {
        // 四半期（φ≈0.25/0.75）でのみ境界グラデーションを適用
        let nearQuarter = abs(phase - 0.25) < 0.1 || abs(phase - 0.75) < 0.1
        guard nearQuarter else { return (Path(), 0) }

        let gradientWidth = radius * 0.3 // グラデーションの幅
        let gradientDepth = radius * 2  // 内側への深さ

        var path = Path()

        if isRightLit {
            // 右側が明るい場合（First Quarter）：中央（直線境界）から右にグラデーション
            let gradientRect = CGRect(
                x: center.x,  // 月の中央（直線境界）から開始
                y: center.y - radius, // 円の上端から開始
                width: gradientWidth,
                height: gradientDepth
            )
            path.addRect(gradientRect)
        } else {
            // 左側が明るい場合（Third Quarter）：中央（直線境界）から左にグラデーション
            let gradientRect = CGRect(
                x: center.x - gradientWidth,  // 月の中央（直線境界）から左にgradientWidth分
                y: center.y - radius, // 円の上端から開始
                width: gradientWidth,
                height: gradientDepth
            )
            path.addRect(gradientRect)
        }

        return (path, gradientWidth)
    }

    // MARK: - Terminator Softening
    private static func softenTerminator(
        _ ctx: inout GraphicsContext,
        center c: CGPoint,
        radius r: CGFloat,
        phase φ: Double,
        tone: SkyTone,
        litPath: Path,
        curvature k: CGFloat,       // 0 = 直線, 0.1〜0.18 くらいが自然
        feather: CGFloat,           // 3〜10px くらい
        jitter: CGFloat = 0         // 0〜2px（テクスチャのザラつき）
    ) {
        // Waxing(右が明) / Waning(左が明) - sの符号で統一
        let s = CGFloat(cos(2.0 * .pi * φ)) * r
        let isRightLit = s < 0   // 影円を +s に置くなら、明部は s<0 が右、s>0 は左
        let waxing = isRightLit   // 右が明るい＝waxing と定義を合わせる
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

        // Apply terminator softening with clipping to lit portion
        ctx.drawLayer { layer in
            layer.clip(to: litPath)
            layer.blendMode = .normal
            layer.addFilter(.blur(radius: feather))

            // Apply multiple stroke passes for feathering effect
            let passes = 5
            for p in 0..<passes {
                let w = feather * (1.6 - 0.25 * CGFloat(p))
                layer.stroke(
                    terminator,
                    with: .color(tone.gradEnd),
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
