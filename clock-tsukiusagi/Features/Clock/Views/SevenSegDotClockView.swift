import SwiftUI

// MARK: - Public View
struct SevenSegDotClockView: View {
    @State private var now = Date()

    // Sizing parameters
    private let targetHeight: CGFloat
    private let formatter: DateFormatter
    private let textColor: Color
    private let activeOpacity: CGFloat
    private let inactiveOpacity: CGFloat

    init(targetHeight: CGFloat = 90, formatter: DateFormatter,
         textColor: Color = DesignTokens.ClockColors.textPrimary,
         activeOpacity: CGFloat = DesignTokens.ClockColors.activeOpacity,
         inactiveOpacity: CGFloat = DesignTokens.ClockColors.inactiveOpacity) {
        self.targetHeight = targetHeight
        self.formatter = formatter
        self.textColor = textColor
        self.activeOpacity = activeOpacity
        self.inactiveOpacity = inactiveOpacity
    }

    // Sizing constants (calculated from targetHeight)
    private var digitHeight: CGFloat { targetHeight }
    private var digitWidth: CGFloat { targetHeight * 0.67 }  // 60/90 ratio
    private var digitSpacing: CGFloat { targetHeight * 0.16 }  // 14/90 ratio
    private var dotSize: CGFloat { max(2, targetHeight * 0.033) }  // 3/90 ratio (larger dots)
    private var spacing: CGFloat { max(2, targetHeight * 0.033) }  // 3/90 ratio (tighter spacing)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let t = formatter.string(from: ctx.date)
            HStack(spacing: digitSpacing) {
                ForEach(Array(t), id: \.self) { ch in
                    if ch == ":" {
                        ColonDotCell(digitHeight: digitHeight, inactiveOpacity: inactiveOpacity, dotSize: dotSize, spacing: spacing, textColor: textColor)
                    } else if let d = ch.wholeNumberValue {
                        SevenSegDigitDotCell(
                            lit: SevenSegDigitDotCell.litMap[d],
                            dotSize: dotSize,
                            spacing: spacing,
                            activeOpacity: activeOpacity,
                            inactiveOpacity: inactiveOpacity,
                            textColor: textColor
                        )
                        .frame(width: digitWidth, height: digitHeight)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - 7セグ ドット桁
struct SevenSegDigitDotCell: View {
    /// 7つのセグメントの点灯状態（A〜G）。true=点灯
    let lit: [Bool]
    let dotSize: CGFloat
    let spacing: CGFloat
    let activeOpacity: CGFloat
    let inactiveOpacity: CGFloat
    let textColor: Color

    // 7セグの各セグメントのオン/オフ定義（0〜9）
    static let litMap: [[Bool]] = [
        // A, B, C, D, E, F, G   （A=上横、B=右上、C=右下、D=下横、E=左下、F=左上、G=中央）
        [true,  true,  true,  true,  true,  true,  false], // 0
        [false, true,  true,  false, false, false, false], // 1
        [true,  true,  false, true,  true,  false, true ], // 2
        [true,  true,  true,  true,  false, false, true ], // 3
        [false, true,  true,  false, false, true,  true ], // 4
        [true,  false, true,  true,  false, true,  true ], // 5
        [true,  false, true,  true,  true,  true,  true ], // 6
        [true,  true,  true,  false, false, false, false], // 7
        [true,  true,  true,  true,  true,  true,  true ], // 8
        [true,  true,  true,  true,  false, true,  true ]  // 9
    ]

    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)

            // 8の形（=全セグメント）を「薄い」レイヤー
            DigitalDotGrid(dotSize: dotSize, spacing: spacing, color: textColor.opacity(inactiveOpacity * 0.3))
                .mask(segmentsPath(in: rect, lit: Array(repeating: true, count: 7)))

            // 現在点灯するセグメントだけ「濃い」レイヤー
            DigitalDotGrid(dotSize: dotSize, spacing: spacing, color: textColor.opacity(activeOpacity))
                .mask(segmentsPath(in: rect, lit: lit))
                .shadow(color: textColor.opacity(0.4), radius: 8, x: 0, y: 0)
                .shadow(color: textColor.opacity(0.2), radius: 16, x: 0, y: 0)
        }
    }

    // 7セグ全体のパス（角丸セグメント）
    private func segmentsPath(in r: CGRect, lit: [Bool]) -> Path {
        var path = Path()
        // セグメントの太さなど
        let w = r.width, h = r.height
        let thickness = min(w, h) * 0.16
        let inset = thickness * 0.6
        let corner: CGFloat = thickness * 0.45

        // セグメント矩形（位置定義）
        let A = CGRect(x: r.minX + inset, y: r.minY,
                       width: w - inset * 2, height: thickness)
        let D = CGRect(x: r.minX + inset, y: r.maxY - thickness,
                       width: w - inset * 2, height: thickness)
        let G = CGRect(x: r.minX + inset, y: r.midY - thickness/2,
                       width: w - inset * 2, height: thickness)

        let F = CGRect(x: r.minX, y: r.minY + inset,
                    width: thickness, height: h/2 - inset - thickness/2)
        let E = CGRect(x: r.minX, y: r.midY + thickness/2,
                    width: thickness, height: h/2 - inset - thickness/2)

        let B = CGRect(x: r.maxX - thickness, y: r.minY + inset,
                    width: thickness, height: h/2 - inset - thickness/2)
        let C = CGRect(x: r.maxX - thickness, y: r.midY + thickness/2,
                    width: thickness, height: h/2 - inset - thickness/2)

        let rects = [A,B,C,D,E,F,G]
        for (i, on) in lit.enumerated() where on {
            path.addRoundedRect(in: rects[i], cornerSize: .init(width: corner, height: corner))
        }
        return path
    }
}

// MARK: - コロン（中央に2点）
struct ColonDotCell: View {
    let digitHeight: CGFloat
    let inactiveOpacity: CGFloat
    let dotSize: CGFloat
    let spacing: CGFloat
    let textColor: Color

    init(digitHeight: CGFloat, inactiveOpacity: CGFloat, dotSize: CGFloat, spacing: CGFloat, textColor: Color) {
        self.digitHeight = digitHeight
        self.inactiveOpacity = inactiveOpacity
        self.dotSize = dotSize
        self.spacing = spacing
        self.textColor = textColor
    }
    var body: some View {
        GeometryReader { geo in
            let size = CGSize(width: geo.size.width, height: geo.size.height)

            // 直径は格子に合わせて整数倍で決める
            let dot = max(dotSize * 2, spacing)             // 例: ドット2コ分 or ピッチ1コ分
            let gap = spacing * 3                            // 上下の間隔（お好みで）

            // 中心を格子にスナップ
            let cx = (round((size.width / 2) / spacing)) * spacing
            let cy = (round((size.height / 2) / spacing)) * spacing

            let up   = CGRect(x: cx - dot/2, y: cy - gap - dot/2, width: dot, height: dot)
            let down = CGRect(x: cx - dot/2, y: cy + gap - dot/2, width: dot, height: dot)

            ZStack {
                // 薄い（同じ円をスケールで拡大 → 楕円化しない）
                DigitalDotGrid(dotSize: dotSize, spacing: spacing, color: textColor.opacity(inactiveOpacity * 0.3))
                    .mask(
                        Path { p in
                            p.addEllipse(in: up)
                            p.addEllipse(in: down)
                        }
                        .applying(.init(scaleX: 1.6, y: 1.6)) // 中心からスケール
                    )

                // 濃い（そのまま）
                DigitalDotGrid(dotSize: dotSize, spacing: spacing, color: textColor.opacity(0.98))
                    .mask(
                        Path { p in
                            p.addEllipse(in: up)
                            p.addEllipse(in: down)
                        }
                    )
                    .shadow(color: textColor.opacity(0.25), radius: 6)
            }
        }
        // 幅も格子に寄せるとさらに安定
        .frame(width: spacing * 5, height: digitHeight)
    }
}

// MARK: - ドット格子（描画範囲=数字領域のみに限定）
private struct DigitalDotGrid: View {
    let dotSize: CGFloat
    let spacing: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
                let cols = Int(ceil(size.width / spacing))
                let rows = Int(ceil(size.height / spacing))
                let r = dotSize / 2

                var path = Path()
                for y in 0..<rows {
                    let cy = CGFloat(y) * spacing + spacing/2
                    for x in 0..<cols {
                        let cx = CGFloat(x) * spacing + spacing/2
                        let rect = CGRect(x: cx - r, y: cy - r, width: dotSize, height: dotSize)
                        path.addEllipse(in: rect)
                    }
                }
                ctx.fill(path, with: .color(color))
            }
        }
        .drawingGroup() // アンチエイリアス&パフォーマンス
    }
}

#Preview{
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return SevenSegDotClockView(targetHeight: 56, formatter: formatter)
        .background(.black)
}
