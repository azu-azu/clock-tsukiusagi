import SwiftUI

struct DotMatrixClockView: View {
    // Inputs
    private let timeString: String
    private let fontSize: CGFloat
    private let fontWeight: Font.Weight
    private let fontDesign: Font.Design
    private let dotSize: CGFloat
    private let dotSpacing: CGFloat
    private let color: Color
    private let enableGlow: Bool

    init(
        timeString: String,
        fontSize: CGFloat = DesignTokens.ClockTypography.clockFontSize,
        fontWeight: Font.Weight = .semibold,
        fontDesign: Font.Design = .monospaced,
        dotSize: CGFloat = 2,
        dotSpacing: CGFloat = 2,
        color: Color = DesignTokens.ClockColors.textPrimary,
        enableGlow: Bool = true
    ) {
        self.timeString = timeString
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.fontDesign = fontDesign
        self.dotSize = dotSize
        self.dotSpacing = dotSpacing
        self.color = color
        self.enableGlow = enableGlow
    }

    var body: some View {
        // 元のレイアウトに合わせて、透明テキストへオーバーレイでDotGridを重ねる
        let timeText = Text(timeString)
            .font(.system(size: fontSize, weight: fontWeight, design: fontDesign))
            .monospacedDigit()

        timeText
            .foregroundStyle(.clear)
            .overlay(
                DotGrid(dotSize: dotSize, spacing: dotSpacing, color: color, enableGlow: enableGlow)
                    .mask(timeText)
            )
    }
}

// DotGrid is now defined in CrossFeatureUI/Visual/Primitives/DotGrid.swift

#Preview {
    DotMatrixClockView(timeString: "14:30")
        .frame(height: 260)
        .background(.black)
}
