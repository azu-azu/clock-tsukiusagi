import SwiftUI

struct MoonGlyph: View {
    let date: Date
    let tone: SkyTone
    private let thinThreshold: Double = 0.02
    private let fadeStartThreshold: Double = 0.05  // 5%からフェード開始

    init(date: Date, tone: SkyTone = .night) {
        self.date = date
        self.tone = tone
    }

    var body: some View {
        let mp = MoonPhaseCalculator.moonPhaseForLocalEvening(on: date)

        // デバッグログを別の場所で実行
        let _ = {
            #if DEBUG
            print("MoonGlyph: illumination=\(mp.illumination), thinThreshold=\(thinThreshold)")
            #endif
        }()

        if mp.illumination < thinThreshold {
            Color.clear
        } else {
            Canvas { ctx, canvasSize in
                #if DEBUG
                print("MoonGlyph: Calling MoonPainter.draw")
                #endif
                MoonPainter.draw(
                    in: ctx,
                    size: canvasSize,
                    phase: mp.phase,
                    tone: tone
                )
            }
            .opacity(calculateOpacity(illumination: mp.illumination))
            .accessibilityLabel(Text("Moon, phase: \(String(format: "%.0f", mp.illumination * 100))%"))
        }
    }

    private func calculateOpacity(illumination: Double) -> Double {
        if illumination >= fadeStartThreshold {
            return 1.0  // 完全に表示
        } else if illumination <= thinThreshold {
            return 0.0  // 完全に透明
        } else {
            // 段階的フェード: thinThreshold から fadeStartThreshold の間で滑らかに変化
            let fadeRange = fadeStartThreshold - thinThreshold
            let fadeProgress = (illumination - thinThreshold) / fadeRange
            return fadeProgress
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
