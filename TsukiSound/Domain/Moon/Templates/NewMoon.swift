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

        // 2) ベース：ぼんやり見える程度の黒い円（色のグラデーション）
        // blurを使わず、より滑らかなグラデーションで柔らかさを表現
        ctx.drawLayer { layer in
            layer.clip(to: disk)  // diskの範囲内に限定
            layer.blendMode = .normal
            // 色のグラデーション（中心から外側へ、差を小さく）
            let gradient = Gradient(colors: [
                Color(white: 0.03, opacity: 0.25),  // 中心（少し濃く）
                Color(white: 0.02, opacity: 0.25)   // 外縁（少し濃く）
            ])
            layer.fill(disk, with: .radialGradient(
                gradient,
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
            layer.addFilter(.blur(radius: r * 0.18))  // 元の実装通り
            layer.blendMode = .plusLighter
            layer.stroke(
                rimArc,
                with: .color(Color.cyan.opacity(0.10)),
                style: StrokeStyle(lineWidth: r * 0.22, lineCap: .round)
            )
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
