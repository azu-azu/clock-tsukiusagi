import SwiftUI

enum MoonPainter {

    // MARK: - Public API
    static func draw(in ctx: GraphicsContext, size: CGSize, phase: Double, tone: SkyTone) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        let radius = min(size.width, size.height) * 0.18

        // ClockCaptionと同じ範囲で8段階に分岐
        // 新月: 0.97〜1.0, 0.0〜0.03
        if phase < 0.03 || phase >= 0.97 {
            let isRightLit = sin(2.0 * .pi * phase) > 0
            let sunAngle: Angle = isRightLit ? .degrees(0) : .degrees(180)
            NewMoonPainter.draw(in: ctx, center: center, radius: radius, sunAngle: sunAngle)
            return
        }

        // 三日月 (Waxing Crescent): 0.03〜0.22
        if phase < 0.22 {
            drawWaxingCrescent(in: ctx, center: center, radius: radius)
            return
        }

        // 上弦 (First Quarter): 0.22〜0.28
        if phase < 0.28 {
            drawFirstQuarter(in: ctx, center: center, radius: radius)
            return
        }

        // 十日夜 (Waxing Gibbous): 0.28〜0.47
        if phase < 0.47 {
            drawWaxingGibbous(in: ctx, center: center, radius: radius)
            return
        }

        // 満月 (Full Moon): 0.47〜0.53
        if phase < 0.53 {
            drawFullMoon(in: ctx, center: center, radius: radius)
            return
        }

        // 十三夜 (Waning Gibbous): 0.53〜0.72
        if phase < 0.72 {
            drawWaningGibbous(in: ctx, center: center, radius: radius)
            return
        }

        // 下弦 (Third Quarter): 0.72〜0.78
        if phase < 0.78 {
            drawThirdQuarter(in: ctx, center: center, radius: radius)
            return
        }

        // 二十六夜 (Waning Crescent): 0.78〜0.97
        drawWaningCrescent(in: ctx, center: center, radius: radius)
    }

    // MARK: - Private Drawing Functions

    /// 三日月の描画
    private static func drawWaxingCrescent(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let crescentPath = WaxingCrescentMoon.shape(center: center, radius: radius)

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

        // グロー効果（右側のみ）
        let glowArc = Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-60),
                endAngle: .degrees(60),
                clockwise: false
            )
        }
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.18))
            layer.blendMode = .normal
            layer.stroke(glowArc, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.12)),
                       style: StrokeStyle(lineWidth: radius * 0.2, lineCap: .round, lineJoin: .round))
        }
    }

    /// 上弦の月の描画
    private static func drawFirstQuarter(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let quarterPath = FirstQuarterMoon.shape(center: center, radius: radius)

        ctx.fill(
            quarterPath,
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
        let circleDistance: CGFloat = 13.7750
        let terminatorPath = FirstQuarterMoon.terminatorPath(
            center: center,
            radius: radius,
            circleDistance: circleDistance
        )
        ctx.drawLayer { layer in
            layer.clip(to: quarterPath)
            layer.blendMode = .normal
            layer.addFilter(.blur(radius: 3.0))

            let passes = 20
            for p in 0..<passes {
                let w = 3.0 * (1.6 - 0.25 * CGFloat(p))
                layer.stroke(
                    terminatorPath,
                    with: .color(Color.black.opacity(0.6)),
                    lineWidth: max(1, w)
                )
            }
        }

        // グロー効果（右側のみ）
        let glowArc = Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: false
            )
        }
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.18))
            layer.blendMode = .normal
            layer.stroke(glowArc, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.15)),
                       style: StrokeStyle(lineWidth: radius * 0.28, lineCap: .round, lineJoin: .round))
        }
    }

    /// 十日夜の描画
    private static func drawWaxingGibbous(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let gibbousPath = WaxingGibbousMoon.shape(center: center, radius: radius)

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

        // グロー効果（右側中心）
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
            layer.stroke(glowArc, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.14)),
                       style: StrokeStyle(lineWidth: radius * 0.25, lineCap: .round, lineJoin: .round))
        }
    }

    /// 満月の描画
    private static func drawFullMoon(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let fullMoonPath = FullMoon.shape(center: center, radius: radius)

        ctx.fill(
            fullMoonPath,
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

        let moonRect = CGRect(x: center.x - radius, y: center.y - radius, width: 2*radius, height: 2*radius)
        let moonPath = Path(ellipseIn: moonRect)

        // 内側のブルーグロー
        ctx.drawLayer { layer in
            layer.blendMode = .normal
            layer.addFilter(.blur(radius: radius * 0.25))
            layer.fill(moonPath, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.15)))
        }

        // 外側の白いグロー
        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.addFilter(.blur(radius: radius * 0.18))
            layer.fill(moonPath, with: .color(DesignTokens.MoonColors.glowWhite.opacity(0.05)))
        }

        // 外側への拡散グロー
        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.addFilter(.blur(radius: radius * 0.45))
            layer.fill(moonPath, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.08)))
        }
    }

    /// 十三夜の描画
    private static func drawWaningGibbous(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let gibbousPath = WaningGibbousMoon.shape(center: center, radius: radius)

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

        // グロー効果（左側中心）
        let glowArc = Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(100),
                endAngle: .degrees(260),
                clockwise: false
            )
        }
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.18))
            layer.blendMode = .normal
            layer.stroke(glowArc, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.14)),
                       style: StrokeStyle(lineWidth: radius * 0.25, lineCap: .round, lineJoin: .round))
        }
    }

    /// 下弦の月の描画
    private static func drawThirdQuarter(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let quarterPath = ThirdQuarterMoon.shape(center: center, radius: radius)

        ctx.fill(
            quarterPath,
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
        let circleDistance: CGFloat = 31.7503
        let terminatorPath = ThirdQuarterMoon.terminatorPath(
            center: center,
            radius: radius,
            circleDistance: circleDistance
        )
        ctx.drawLayer { layer in
            layer.clip(to: quarterPath)
            layer.blendMode = .normal
            layer.addFilter(.blur(radius: 3.0))

            let passes = 20
            for p in 0..<passes {
                let w = 3.0 * (1.6 - 0.25 * CGFloat(p))
                layer.stroke(
                    terminatorPath,
                    with: .color(Color.black.opacity(0.6)),
                    lineWidth: max(1, w)
                )
            }
        }

        // グロー効果（左側のみ）
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
            layer.stroke(glowArc, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.15)),
                       style: StrokeStyle(lineWidth: radius * 0.28, lineCap: .round, lineJoin: .round))
        }
    }

    /// 二十六夜の描画
    private static func drawWaningCrescent(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let crescentPath = WaningCrescentMoon.shape(center: center, radius: radius)

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

        // グロー効果（左側のみ）
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
            layer.stroke(glowArc, with: .color(DesignTokens.MoonColors.glowCyan.opacity(0.12)),
                       style: StrokeStyle(lineWidth: radius * 0.2, lineCap: .round, lineJoin: .round))
        }
    }
}
