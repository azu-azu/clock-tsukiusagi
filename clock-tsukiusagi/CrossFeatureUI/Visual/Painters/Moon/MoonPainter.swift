import SwiftUI

enum MoonPainter {

    // MARK: - Public API
    static func draw(in ctx: GraphicsContext, size: CGSize, phase: Double, tone: SkyTone) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        let radius = min(size.width, size.height) * 0.18

        // phase から月相判定
        // 0.0 = 新月, 0.25 = 上弦, 0.5 = 満月, 0.75 = 下弦
        let firstQuarterPhase = 0.25
        let fullMoonPhase = 0.5
        let thirdQuarterPhase = 0.75
        let phaseThreshold = 0.05

        let isFirstQuarter = abs(phase - firstQuarterPhase) < phaseThreshold
        let isFullMoon = abs(phase - fullMoonPhase) < phaseThreshold
        let isThirdQuarter = abs(phase - thirdQuarterPhase) < phaseThreshold

        #if DEBUG
        print(String(format: "MoonPainter.draw: phase=%.6f, isFirstQuarter=%@, isFullMoon=%@, isThirdQuarter=%@",
                    phase, isFirstQuarter ? "YES" : "NO", isFullMoon ? "YES" : "NO", isThirdQuarter ? "YES" : "NO"))
        #endif

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
            let terminatorPath = FirstQuarterMoon.terminatorPath(center: center, radius: radius, circleDistance: circleDistance)
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
                path.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
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
            let terminatorPath = ThirdQuarterMoon.terminatorPath(center: center, radius: radius, circleDistance: circleDistance)
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
                path.addArc(center: center, radius: radius, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
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
