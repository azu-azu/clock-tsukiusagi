import SwiftUI

// MARK: - Public View
struct SevenSegDotClockView: View {
    @State private var now = Date()

    // Sizing constants
    private let digitWidth: CGFloat = 60
    private let digitHeight: CGFloat = 90
    private let digitSpacing: CGFloat = 14
    private let dotSize: CGFloat = 2
    private let spacing: CGFloat = 4
    private let activeOpacity: CGFloat = 0.98
    private let inactiveOpacity: CGFloat = 0.18

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let t = Self.fmt.string(from: ctx.date) // "HH:mm"
            HStack(spacing: digitSpacing) {
                ForEach(Array(t), id: \.self) { ch in
                    if ch == ":" {
                        ColonDotCell()
                    } else if let d = ch.wholeNumberValue {
                        SevenSegDigitDotCell(
                            lit: SevenSegDigitDotCell.litMap[d],
                            dotSize: dotSize,
                            spacing: spacing,
                            activeOpacity: activeOpacity,
                            inactiveOpacity: inactiveOpacity
                        )
                        .frame(width: digitWidth, height: digitHeight)
                    }
                }
            }
            .padding(.horizontal, 8)
            .background(Color.black.ignoresSafeArea())
        }
        .statusBarHidden(true)
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm" // 秒が欲しければ "HH:mm:ss"
        return f
    }()
}

// MARK: - 7セグ ドット桁
struct SevenSegDigitDotCell: View {
    /// 7つのセグメントの点灯状態（A〜G）。true=点灯
    let lit: [Bool]
    let dotSize: CGFloat
    let spacing: CGFloat
    let activeOpacity: CGFloat
    let inactiveOpacity: CGFloat

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
            DigitalDotGrid(dotSize: dotSize, spacing: spacing, color: .white.opacity(inactiveOpacity))
                .mask(segmentsPath(in: rect, lit: Array(repeating: true, count: 7)))

            // 現在点灯するセグメントだけ「濃い」レイヤー
            DigitalDotGrid(dotSize: dotSize, spacing: spacing, color: .white.opacity(activeOpacity))
                .mask(segmentsPath(in: rect, lit: lit))
                .shadow(color: .white.opacity(0.25), radius: 6) // ほのかな発光
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
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let dot = size * 0.12
            let spacing = size * 0.28
            let up = CGRect(x: geo.size.width/2 - dot/2,
                            y: geo.size.height/2 - spacing - dot/2,
                            width: dot, height: dot)
            let down = up.offsetBy(dx: 0, dy: spacing * 2)

            ZStack {
                // 薄い（常時うっすら）
                DigitalDotGrid(dotSize: 3, spacing: 6, color: .white.opacity(0.18))
                    .mask(
                        Path { p in
                            p.addEllipse(in: up.insetBy(dx: -dot, dy: -dot))
                            p.addEllipse(in: down.insetBy(dx: -dot, dy: -dot))
                        }
                    )
                // 濃い（コロン自体は常時点灯扱いでOK）
                DigitalDotGrid(dotSize: 3, spacing: 6, color: .white.opacity(0.98))
                    .mask(
                        Path { p in
                            p.addEllipse(in: up)
                            p.addEllipse(in: down)
                        }
                    )
                    .shadow(color: .white.opacity(0.25), radius: 6)
            }
        }
        .frame(width: 30, height: 180)
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
    SevenSegDotClockView()
        .background(.black)
}

