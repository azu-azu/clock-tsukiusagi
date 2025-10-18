import SwiftUI

struct DotMatrixClockView: View {
    @State private var now = Date()

    private let clockSize: CGFloat = 100
    private let dotSize: CGFloat = 2
    private let dotSpacing: CGFloat = 2
    private let dotColor: Color = .white
    private let dotDesign: Font.Design = .monospaced
    // private let dotDesign: Font.Design = .rounded

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            // 1) 表示文字列（24h/12h切り替えはお好みで）
            let time = Self.formatTime(context.date)

            ZStack {
                // 2) 背景（お好みで）
                Color.black.ignoresSafeArea()

                // 3) ドット格子をテキストでマスク
                DotGrid(dotSize: dotSize, spacing: dotSpacing, color: dotColor)
                    .mask(
                        Text(time)
                            .font(.system(size: clockSize, weight: .bold, design: dotDesign))
                            .monospacedDigit()
                    )
                    // 4) ほのかな発光っぽさ
                    .shadow(color: .white.opacity(0.25), radius: 6, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.12), radius: 16, x: 0, y: 0)
                    .padding(.horizontal)
            }
        }
        .statusBarHidden(true)
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }
}

// DotGrid is now defined in Features/Clock/Components/DotGrid.swift

#Preview {
    DotMatrixClockView()
        .frame(height: 260)
}
