import SwiftUI

// MARK: - DotGrid (reusable component)
struct DotGrid: View {
    let dotSize: CGFloat
    let spacing: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let cols = Int(ceil(size.width / spacing))
                let rows = Int(ceil(size.height / spacing))
                let radius = dotSize / 2.0

                var path = Path()
                for r in 0..<rows {
                    let y = CGFloat(r) * spacing + spacing/2
                    for c in 0..<cols {
                        let x = CGFloat(c) * spacing + spacing/2
                        let rect = CGRect(x: x - radius, y: y - radius, width: dotSize, height: dotSize)
                        path.addEllipse(in: rect)
                    }
                }
                context.fill(path, with: .color(color))
            }
        }
    }
}

#Preview {
    DotGrid(dotSize: 2, spacing: 2, color: .white)
        .frame(width: 200, height: 100)
        .background(Color.black)
}
