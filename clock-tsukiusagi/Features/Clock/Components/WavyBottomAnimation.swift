import SwiftUI

struct SineWave: Shape {
    var phase: CGFloat      // 位相
    var amplitude: CGFloat  // 振幅（波の高さ）

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY
        let width = rect.width
        let step: CGFloat = 2  // 描画精度

        p.move(to: CGPoint(x: 0, y: midY))
        var x: CGFloat = 0
        while x <= width {
            let relative = x / width
            let y = midY + sin((relative * .pi * 2) + phase) * amplitude
            p.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        // 下を塗りつぶして”海面”に
        p.addLine(to: CGPoint(x: width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
}

struct WavyBottomView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let speed: Double = 0.8
            let t = CGFloat(now * speed)

            ZStack(alignment: .bottom) {
                // 波レイヤ1（ゆっくり）
                SineWave(phase: t, amplitude: 14)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: 160)
                    .blur(radius: 1)

                // 波レイヤ2（少し速い＆浅い）— パララックスで奥行き
                SineWave(phase: t * 1.35, amplitude: 8)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: 140)
                    .offset(y: 6)
                    .blur(radius: 0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview {
    ZStack {
		LinearGradient(
			colors: [.black, .blue.opacity(0.8)],
			startPoint: .top,
			endPoint: .bottom
		)
        .ignoresSafeArea()

        WavyBottomView()
    }
}

// #Preview {
//     ZStack {
// 		LinearGradient(
// 			gradient: Gradient(stops: [
// 				.init(color: .black, location: 0.0),
// 				.init(color: Color.cyan.opacity(1.0), location: 0.5),
// 				.init(color: Color.blue.opacity(0.9), location: 1.0)
// 			]),
// 			startPoint: .top,
// 			endPoint: .bottom
// 		)
//         .ignoresSafeArea()

//         WavyBottomView()
//     }
// }
