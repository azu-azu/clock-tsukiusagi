import SwiftUI

/// デザイントークン - アプリ全体で使用する色、フォント、スペーシングなどの統一された値
struct DesignTokens {

    // MARK: - Clock Colors
    enum ClockColors {
        /// メインのテキスト色（時刻表示など）
        static let textPrimary = Color.white.opacity(0.95)

        /// グロー効果の色
        static let glow = Color.white.opacity(0.6)

        /// セカンダリテキスト色（キャプションなど）
        static let textSecondary = Color.white.opacity(0.8)

        /// アクティブ状態の不透明度（7セグ表示など）
        static let activeOpacity: CGFloat = 1.0

        /// 非アクティブ状態の不透明度（7セグ表示など）
        static let inactiveOpacity: CGFloat = 0.18
    }

    // MARK: - Clock Typography
    enum ClockTypography {
        /// メインの時刻フォントサイズ
        static let clockFontSize: CGFloat = 56

        /// キャプションフォントサイズ
        static let captionFontSize: CGFloat = 16

        /// 7セグ表示の高さ
        static let sevenSegHeight: CGFloat = 44
    }

    // MARK: - Clock Spacing
    enum ClockSpacing {
        /// 時刻とキャプションの間隔
        static let timeCaptionSpacing: CGFloat = 8

        /// 下部パディング
        static let bottomPadding: CGFloat = 48
    }
}
