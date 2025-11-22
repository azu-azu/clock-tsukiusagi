import SwiftUI

/// 新月レンダラ：地球照・リムグロー・影の3レイヤ
enum NewMoonPainter {

    /// sunAngle: 太陽の方向（0°=右, 90°=上）
    static func draw(in ctx: GraphicsContext,
                    center c: CGPoint,
                    radius r: CGFloat,
                    sunAngle: Angle)
    {
        // 1) 円盤の幾何
        let disk = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2*r, height: 2*r))

        // 2) 影（背景をわずかに落とす：星空を隠す感じ）
        ctx.drawLayer { layer in
            layer.clip(to: disk)
            layer.blendMode = .multiply
            // 中心が最も暗いラジアルグラデーション
            let g = Gradient(colors: [
                Color.black.opacity(0.20),  // 中心
                Color.black.opacity(0.08)   // 外縁
            ])
            layer.fill(disk, with: .radialGradient(
                g,
                center: c,
                startRadius: 0,
                endRadius: r
            ))
        }

        // 3) 地球照（非常に弱い灰色の“見える気がする”円盤）
        ctx.drawLayer { layer in
            layer.clip(to: disk)
            layer.blendMode = .screen
            layer.addFilter(.blur(radius: r * 0.05))
            let g = Gradient(colors: [
                Color.white.opacity(0.035), // 外縁ほどやや明るく
                Color.white.opacity(0.010)
            ])
            layer.fill(disk, with: .radialGradient(
                g,
                center: c,
                startRadius: 0,
                endRadius: r
            ))
        }

        // 4) リムグロー（太陽方向だけ外側に薄いグロー）
        let rimSweep: Double = 70  // グローの扇角（控えめ）
        let start = sunAngle.radians - rimSweep * .pi/360
        let end   = sunAngle.radians + rimSweep * .pi/360

        var rimArc = Path()
        rimArc.addArc(center: c, radius: r * 1.02, // 外縁ちょい外
                    startAngle: .radians(start),
                    endAngle: .radians(end),
                    clockwise: false)

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: r * 0.18))
            layer.blendMode = .plusLighter
            layer.stroke(
                rimArc,
                with: .color(Color.cyan.opacity(0.10)),
                style: StrokeStyle(lineWidth: r * 0.22, lineCap: .round)
            )
        }

        // 5) ぼかした外周の"気配"の線（視認性アップ・幾何学的な黒丸感の軽減）
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: r * 0.06))  // 枠をぼかす
            layer.blendMode = .normal
            layer.stroke(disk, with: .color(Color.black.opacity(0.35)), lineWidth: max(2, r * 0.04))
        }
    }
}

// === Preview / 使用例 =========================================================
#Preview("New Moon") {
    Canvas { ctx, size in
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
        let r = min(size.width, size.height) * 0.28
        // 例: 太陽は右やや上（30°）
        NewMoonPainter.draw(in: ctx, center: c, radius: r, sunAngle: .degrees(30))
    }
    .background(
        LinearGradient(colors: [SkyTone.night.gradStart, SkyTone.night.gradEnd],
                    startPoint: .top, endPoint: .bottom)
    )
    .padding()
}
