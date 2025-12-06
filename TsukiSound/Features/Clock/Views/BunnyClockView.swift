import SwiftUI
import Foundation

struct BunnyClockView: View {
    // MARK: - Constants
    static let markerColor = DesignTokens.CommonTextColors.tertiary
    static let handColor = DesignTokens.CommonTextColors.primary
    static let secondHandColor = DesignTokens.ClockColors.captionBlue
    static let centerCircleColor = DesignTokens.CommonTextColors.primary
    static let trackColor = DesignTokens.CommonTextColors.tertiary
    static let trackSize: CGFloat = 12
    static let moonSize: CGFloat = 34
    static let starSize: CGFloat = 14
    static let hareSize: CGFloat = 20 // うさぎ

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            // 文字盤 & 針（背景はClockScreenViewのものを使用）
            ClockFace(date: date)
                .padding(24)
        }
    }
}

private struct ClockFace: View {
    let date: Date

    var body: some View {
        GeometryReader { geo in
            let markerColor = BunnyClockView.markerColor

            let size = geo.size
            let center = CGPoint(x: size.width/2, y: size.height/2)
            let radius = min(size.width, size.height) * 0.42

            Canvas { context, _ in
                // 文字盤インデックス
                for i in 0..<12 {
                    let angle = Angle.degrees(Double(i) / 12.0 * 360.0 - 90)
                    let p = CGPoint(
                        x: center.x + CGFloat(Foundation.cos(angle.radians)) * radius,
                        y: center.y + CGFloat(Foundation.sin(angle.radians)) * radius
                    )

                    // 12時だけ「月＋星」ペア
                    if i == 0 {
                        // 小さな月
						let moon = Text(Image(systemName: "moon.fill"))
                            .font(.system(size: 36))
                        let moonResolved = context.resolve(
                            moon.foregroundStyle(markerColor)
                        )
                        // 12時位置より少し左下に寄せる
                        let moonPoint = CGPoint(x: p.x - 10, y: p.y + 3)
                        context.draw(moonResolved, at: moonPoint, anchor: .center)

                        // 小さな星（月の右上）
						let star = Text(Image(systemName: "star.fill"))
                            .font(.system(size: BunnyClockView.starSize, weight: .semibold))
                        let starResolved = context.resolve(
                            star.foregroundStyle(markerColor)
                        )
                        let starPoint = CGPoint(x: p.x + 12, y: p.y - 8)
                        context.draw(starResolved, at: starPoint, anchor: .center)

                        } else if i % 3 == 0 {
                            // 🐇 3/6/9 = うさぎ（SF Symbols）
							let hare = Text(Image(systemName: "hare.fill"))
                            .font(.system(size: BunnyClockView.hareSize))
                            let hareResolved = context.resolve(
                                hare.foregroundStyle(markerColor)
                            )
                            context.draw(hareResolved, at: p, anchor: .center)
                        } else {

                        // 🐾 足あと（BunnyTrackGlyph を SwiftUI Image に変換して描画）— UIKit 不使用
                        let trackView = BunnyTrackGlyph(color: BunnyClockView.trackColor)
                            .opacity(0.9)
                            .frame(width: BunnyClockView.trackSize, height: BunnyClockView.trackSize)

                        let renderer = ImageRenderer(content: trackView)
                        renderer.proposedSize = .init(CGSize(width: BunnyClockView.trackSize, height: BunnyClockView.trackSize))
                        // renderer.scale は指定不要（Canvas 側で解像度管理される）

                        if let cg = renderer.cgImage {
                            // ← UIKit いらず：CGImage から SwiftUI.Image を作る
                            let img = Image(decorative: cg, scale: 1, orientation: .up)
                            let w: CGFloat = BunnyClockView.trackSize
                            let rect = CGRect(x: p.x - w/2, y: p.y - w/2, width: w, height: w)
                            context.draw(img, in: rect)
                        }
                    }
                }

                // --- 針の計算と描画（既存のまま） ---
                let cal = Calendar.current
                let s = Double(cal.component(.second, from: date))
                let m = Double(cal.component(.minute, from: date)) + s/60.0
                let h = Double(cal.component(.hour,   from: date) % 12) + m/60.0

				let secAngle  = Angle.degrees(s/60.0 * 360.0 - 90)
                let minAngle  = Angle.degrees(m/60.0 * 360.0 - 90)
                let hourAngle = Angle.degrees(h/12.0 * 360.0 - 90)

                func endPoint(_ angle: Angle, _ length: CGFloat) -> CGPoint {
                    CGPoint(
                        x: center.x + CGFloat(Foundation.cos(angle.radians)) * length,
                        y: center.y + CGFloat(Foundation.sin(angle.radians)) * length
                    )
                }

                // 時針・分針の描画
                func drawHand(angle: Angle, length: CGFloat, width: CGFloat, alpha: Double) {
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: endPoint(angle, length))
                    let style = StrokeStyle(lineWidth: width, lineCap: .round)
                    context.stroke(
                        path,
                        with: .color(BunnyClockView.handColor.opacity(alpha)),
                        style: style
                    )
                }

                // 秒針の描画（別色・薄め）
                func drawSecondHand(angle: Angle, length: CGFloat, width: CGFloat) {
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: endPoint(angle, length))
                    let style = StrokeStyle(lineWidth: width, lineCap: .round)
                    context.stroke(
                        path,
                        with: .color(BunnyClockView.secondHandColor.opacity(0.7)),
                        style: style
                    )
                }

                // 呼び出し
                drawHand(angle: hourAngle, length: radius * 0.55, width: 6, alpha: 0.95)
                drawHand(angle: minAngle, length: radius * 0.78, width: 5, alpha: 0.95)
                drawSecondHand(angle: secAngle, length: radius * 0.55, width: 2)


                let centerCircle = Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
                context.fill(centerCircle, with: .color(BunnyClockView.centerCircleColor))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(radius: 1.5, y: 0.5)
    }
}

struct BunnyTrackGlyph: View {
    var color: Color = BunnyClockView.trackColor
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            // 指4つ（上2・下2）を細長い楕円で
            Group {
                Ellipse() // 左上
                    .frame(width: w*0.22, height: h*0.32)
                    .offset(x: w*0.18, y: h*0.05)
                Ellipse() // 右上
                    .frame(width: w*0.22, height: h*0.32)
                    .offset(x: w*0.60, y: h*0.05)
                Ellipse() // 左下（やや外側へ）
                    .frame(width: w*0.24, height: h*0.36)
                    .offset(x: w*0.10, y: h*0.45)
                Ellipse() // 右下
                    .frame(width: w*0.24, height: h*0.36)
                    .offset(x: w*0.66, y: h*0.45)
            }
            .foregroundStyle(color)
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
    }
}

#Preview {
    BunnyClockView()
}
