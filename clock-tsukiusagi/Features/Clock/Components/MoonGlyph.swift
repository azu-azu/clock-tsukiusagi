import SwiftUI

struct MoonGlyph: View {
    let phase: Double
    let lightAngle: Angle
    let skyTone: SkyTone

    init(phase: Double, lightAngle: Angle, skyTone: SkyTone = .night) {
        self.phase = phase
        self.lightAngle = lightAngle
        self.skyTone = skyTone
    }

    var body: some View {
        Canvas { ctx, canvasSize in
            MoonPainter.draw(
                in: ctx,
                size: canvasSize,
                angle: lightAngle.degrees,
                tone: skyTone
            )
        }
        .accessibilityLabel(Text("Moon phase"))
    }
}

#Preview {
    VStack(spacing: 20) {
        MoonGlyph(phase: 0.0, lightAngle: .degrees(0), skyTone: .night)
            .frame(width: 200, height: 200)
        MoonGlyph(phase: 0.25, lightAngle: .degrees(90), skyTone: .dusk)
            .frame(width: 200, height: 200)
        MoonGlyph(phase: 0.5, lightAngle: .degrees(180), skyTone: .day)
            .frame(width: 200, height: 200)
        MoonGlyph(phase: 0.75, lightAngle: .degrees(270), skyTone: .dawn)
            .frame(width: 200, height: 200)
    }
    .padding()
    .background(.black)
}
