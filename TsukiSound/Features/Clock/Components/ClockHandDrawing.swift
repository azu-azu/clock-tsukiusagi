import SwiftUI

/// アナログ時計の針描画ユーティリティ
enum ClockHandDrawing {

    /// 時刻から各針の角度を計算
    static func angles(from date: Date) -> (hour: Angle, minute: Angle, second: Angle) {
        let cal = Calendar.current
        let s = Double(cal.component(.second, from: date))
        let m = Double(cal.component(.minute, from: date)) + s / 60.0
        let h = Double(cal.component(.hour, from: date) % 12) + m / 60.0

        let secAngle = Angle.degrees(s / 60.0 * 360.0 - 90)
        let minAngle = Angle.degrees(m / 60.0 * 360.0 - 90)
        let hourAngle = Angle.degrees(h / 12.0 * 360.0 - 90)

        return (hourAngle, minAngle, secAngle)
    }

    /// 中心点から角度と長さで終点を計算
    static func endPoint(center: CGPoint, angle: Angle, length: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(angle.radians)) * length,
            y: center.y + CGFloat(sin(angle.radians)) * length
        )
    }

    /// 時針・分針を描画
    static func drawHand(
        context: inout GraphicsContext,
        center: CGPoint,
        angle: Angle,
        length: CGFloat,
        width: CGFloat,
        color: Color,
        opacity: CGFloat
    ) {
        var path = Path()
        path.move(to: center)
        path.addLine(to: endPoint(center: center, angle: angle, length: length))
        let style = StrokeStyle(lineWidth: width, lineCap: .round)
        context.stroke(path, with: .color(color.opacity(opacity)), style: style)
    }

    /// 秒針を描画（別色）
    static func drawSecondHand(
        context: inout GraphicsContext,
        center: CGPoint,
        angle: Angle,
        length: CGFloat,
        width: CGFloat,
        color: Color,
        opacity: CGFloat
    ) {
        var path = Path()
        path.move(to: center)
        path.addLine(to: endPoint(center: center, angle: angle, length: length))
        let style = StrokeStyle(lineWidth: width, lineCap: .round)
        context.stroke(path, with: .color(color.opacity(opacity)), style: style)
    }

    /// 中心円を描画
    static func drawCenterCircle(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGFloat,
        color: Color
    ) {
        let halfSize = size / 2
        let circle = Path(ellipseIn: CGRect(
            x: center.x - halfSize,
            y: center.y - halfSize,
            width: size,
            height: size
        ))
        context.fill(circle, with: .color(color))
    }

    /// 全ての針と中心円をまとめて描画
    static func drawAllHands(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        date: Date,
        handColor: Color,
        secondHandColor: Color,
        centerColor: Color
    ) {
        let angles = angles(from: date)
        let tokens = DesignTokens.AnalogClock.self

        // 時針
        drawHand(
            context: &context,
            center: center,
            angle: angles.hour,
            length: radius * tokens.hourHandLength,
            width: tokens.hourHandWidth,
            color: handColor,
            opacity: tokens.handOpacity
        )

        // 分針
        drawHand(
            context: &context,
            center: center,
            angle: angles.minute,
            length: radius * tokens.minuteHandLength,
            width: tokens.minuteHandWidth,
            color: handColor,
            opacity: tokens.handOpacity
        )

        // 秒針
        drawSecondHand(
            context: &context,
            center: center,
            angle: angles.second,
            length: radius * tokens.secondHandLength,
            width: tokens.secondHandWidth,
            color: secondHandColor,
            opacity: tokens.secondHandOpacity
        )

        // 中心円
        drawCenterCircle(
            context: &context,
            center: center,
            size: tokens.centerCircleSize,
            color: centerColor
        )
    }
}
