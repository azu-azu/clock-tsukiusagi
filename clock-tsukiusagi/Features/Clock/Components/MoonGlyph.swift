import SwiftUI

struct MoonGlyph: View {
    let date: Date
    let tone: SkyTone
    private let thinThreshold: Double = 0.02

    init(date: Date, tone: SkyTone = .night) {
        self.date = date
        self.tone = tone
    }

    var body: some View {
        let mp = MoonPhaseCalculator.moonPhase(on: date)
        if mp.illumination < thinThreshold {
            Color.clear
        } else {
            Canvas { ctx, canvasSize in
                MoonPainter.draw(
                    in: ctx,
                    size: canvasSize,
                    phase: mp.phase,
                    tone: tone
                )
            }
            .accessibilityLabel(Text("Moon, phase: \(String(format: "%.0f", mp.illumination * 100))%"))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MoonGlyph(date: .now, tone: .night)
            .frame(width: 200, height: 200)
        MoonGlyph(date: Date().addingTimeInterval(7 * 86_400), tone: .dusk)
            .frame(width: 200, height: 200)
        MoonGlyph(date: Date().addingTimeInterval(14 * 86_400), tone: .day)
            .frame(width: 200, height: 200)
        MoonGlyph(date: Date().addingTimeInterval(21 * 86_400), tone: .dawn)
            .frame(width: 200, height: 200)
    }
    .padding()
    .background(.black)
}
