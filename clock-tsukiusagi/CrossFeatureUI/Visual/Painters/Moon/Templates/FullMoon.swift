import SwiftUI

/// 満月テンプレート
enum FullMoon {
    /// 満月の形状を生成
    /// - Parameters:
    ///   - center: 月の中心座標
    ///   - radius: 月の半径
    /// - Returns: 満月の形状を示すPath
    static func shape(center: CGPoint, radius: CGFloat) -> Path {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: 2 * radius,
            height: 2 * radius
        )
        return Path(ellipseIn: rect)
    }
}

// MARK: - Preview
#Preview("Full Moon Template") {
    Canvas { ctx, size in
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let radius = min(size.width, size.height) * 0.3
        let moonRect = CGRect(x: center.x - radius, y: center.y - radius, width: 2*radius, height: 2*radius)

        // 満月の形状を生成
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
    .background(Color.black)
    .padding()
}

