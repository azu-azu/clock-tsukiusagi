import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            QuietClockView()

            // 底辺に重ねる波アニメーション（背景は描かない）
            WavyBottomView()
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    ContentView()
}
