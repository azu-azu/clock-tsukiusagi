import SwiftUI

enum MoonPainter {

    // MARK: - Public API
    static func draw(in ctx: GraphicsContext, size: CGSize, phase: Double, tone: SkyTone) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        let radius = min(size.width, size.height) * 0.18

        // phase から月相判定
        // 0.0 = 新月, 0.25 = 上弦, 0.5 = 満月, 0.75 = 下弦

        // 円形のphase範囲を考慮して、境界を跨いだ判定も含める
        func isInPhaseRange(_ p: Double, _ target: Double, _ threshold: Double) -> Bool {
            let diff = abs(p - target)
            // phaseは円形（0.0と1.0は隣接）なので、反対側もチェック
            return diff < threshold || diff > (1.0 - threshold)
        }

        let phaseThreshold = 0.08  // ±0.08（約±2.5日）

        let isNewMoon = isInPhaseRange(phase, 0.0, phaseThreshold)
        let isFullMoon = isInPhaseRange(phase, 0.5, phaseThreshold)
        let isFirstQuarter = isInPhaseRange(phase, 0.25, phaseThreshold)
        let isThirdQuarter = isInPhaseRange(phase, 0.75, phaseThreshold)

        #if DEBUG
        print(
            String(
                format: """
                    MoonPainter.draw: phase=%.6f,
                    isNewMoon=%@,
                    isFirstQuarter=%@,
                    isFullMoon=%@,
                    isThirdQuarter=%@
                    """,
                    phase,
                    isNewMoon ? "YES" : "NO",
                    isFirstQuarter ? "YES" : "NO",
                    isFullMoon ? "YES" : "NO",
                    isThirdQuarter ? "YES" : "NO"
                ))
        #endif

        // 新月（薄い黒円）
        if isNewMoon {
            #if DEBUG
            print("MoonPainter.draw: Drawing new moon template")
            #endif
            // 太陽方向（右=0°）: 位相から近似（waxingなら右、waningなら左）
            let isRightLit = sin(2.0 * .pi * phase) > 0
            let sunAngle: Angle = isRightLit ? .degrees(0) : .degrees(180)
            NewMoonPainter.draw(in: ctx, center: center, radius: radius, sunAngle: sunAngle)
            return
        }

        if isFullMoon {
            #if DEBUG
            print("MoonPainter.draw: Drawing full moon template")
            #endif

            // 満月テンプレートを使用
            let fullMoonPath = FullMoon.shape(center: center, radius: radius)

            // 放射グラデーションで塗る
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

            // 満月のグロー効果
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

            return
        }

        if isFirstQuarter {
            #if DEBUG
            print("MoonPainter.draw: Drawing first quarter moon template")
            #endif

            let quarterPath = FirstQuarterMoon.shape(center: center, radius: radius)

            // 放射グラデーションで塗る
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

            // ターミネーターの柔らか化（上弦の月）
            let circleDistance: CGFloat = 13.7750  // 上弦の月の実測値
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

            return
        }

        if isThirdQuarter {
            #if DEBUG
            print("MoonPainter.draw: Drawing third quarter moon template")
            #endif

            let quarterPath = ThirdQuarterMoon.shape(center: center, radius: radius)

            // 放射グラデーションで塗る
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

            // ターミネーターの柔らか化（下弦の月）
            let circleDistance: CGFloat = 31.7503  // 下弦の月の実測値
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

            return
        }

        // その他の月相は後で実装
    }
}
