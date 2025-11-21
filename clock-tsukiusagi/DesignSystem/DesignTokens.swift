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

    // MARK: - Moon Colors
    enum MoonColors {
        /// 月の中心色
        static let centerColor = Color.white.opacity(0.95)

        /// 月の縁色
        static let edgeColor = Color.white.opacity(0.6)

        /// 月のグロー色（シアン）
        static let glowCyan = Color.cyan

        /// 月のグロー色（白）
        static let glowWhite = Color.white

        /// グロー効果の不透明度（ベース）
        static let glowBaseOpacity: CGFloat = 0.15

        /// グロー効果の不透明度（ソフト）
        static let glowSoftOpacity: CGFloat = 0.025

        /// グロー効果の不透明度（仕上げ）
        static let glowFinishOpacity: CGFloat = 0.05
    }

    // MARK: - Cosmos Colors
    enum CosmosColors {
        /// 宇宙空間の背景色（濃紺）
        static let background = Color(hex: "#0A0F1C")

        /// カード背景色（代替・subtle用）
        /// 例: サイドメニューのブロック背景
        static let cardBackgroundAlt = Color.white.opacity(0.10)
    }

    // MARK: - Settings Colors
    enum SettingsColors {
        /// 背景グラデーション（夜のトーン）
        static let backgroundGradient = LinearGradient(
            colors: [SkyTone.night.gradStart, SkyTone.night.gradEnd],
            startPoint: .top,
            endPoint: .bottom
        )

        /// カード背景色
        static let cardBackground = Color.white.opacity(0.1)

        /// アクセントカラー（システムのアクセントカラー）
        static let accent = Color.accentColor

        /// プライマリテキスト色
        static let textPrimary = Color.white

        /// セカンダリテキスト色（説明文など）
        static let textSecondary = Color.white.opacity(0.7)

        /// Tertiary テキスト色（キャプションなど）
        static let textTertiary = Color.white.opacity(0.6)

        /// 薄いテキスト色（ヒントなど）
        static let textQuaternary = Color.white.opacity(0.5)

        /// 強調テキスト色（時刻表示など）
        static let textHighlight = Color.white.opacity(0.9)

        /// 危険色（停止ボタンなど）
        static let danger = Color(hex: "#FF5C5C")

        /// 警告色（注意メッセージなど）
        static let warning = Color(hex: "#FFC069")

        /// 成功色（再生中ステータスなど）
        static let success = Color(hex: "#4ADE80")

        /// 非アクティブ色
        static let inactive = Color.white.opacity(0.25)
    }

    // MARK: - Settings Typography
    enum SettingsTypography {
        /// セクションタイトルのサイズ
        static let sectionTitleSize: CGFloat = 18
        static let sectionTitleWeight: Font.Weight = .semibold

        /// 項目タイトルのサイズ
        static let itemTitleSize: CGFloat = 17
        static let itemTitleWeight: Font.Weight = .regular

        /// キャプションのサイズ
        static let captionSize: CGFloat = 12
        static let captionWeight: Font.Weight = .regular

        /// 見出しのサイズ
        static let headlineSize: CGFloat = 17
        static let headlineWeight: Font.Weight = .semibold

        /// サブ見出しのサイズ
        static let subheadlineSize: CGFloat = 15
        static let subheadlineWeight: Font.Weight = .regular
    }

    // MARK: - Settings Spacing
    enum SettingsSpacing {
        /// 画面の水平パディング
        static let screenHorizontal: CGFloat = 24

        /// 画面の下部パディング
        static let screenBottom: CGFloat = 40

        /// 上部スペーサー
        static let topSpacer: CGFloat = 64

        /// セクション間のスペーシング
        static let sectionSpacing: CGFloat = 24

        /// カード内のパディング
        static let cardPadding: CGFloat = 16

        /// セクション内のアイテム間隔
        static let itemSpacing: CGFloat = 16

        /// セクション内の小さな間隔
        static let sectionInnerSpacing: CGFloat = 12

        /// 垂直方向の小さなパディング
        static let verticalSmall: CGFloat = 8

        /// 垂直方向の中程度のパディング
        static let verticalMedium: CGFloat = 12

        /// 最小のボトムスペーサー
        static let bottomSpacer: CGFloat = 40
    }

    // MARK: - Settings Layout
    enum SettingsLayout {
        /// カードの角丸半径
        static let cardCornerRadius: CGFloat = 12

        /// ボタンの角丸半径
        static let buttonCornerRadius: CGFloat = 12

        /// ボタンの高さ
        static let buttonHeight: CGFloat = 50

        /// ボタンのパディング
        static let buttonPadding: CGFloat = 16

        /// ステッパーの値表示部分の共通幅
        static let stepperValueWidth: CGFloat = 80
    }

    // MARK: - SideMenu Colors
    enum SideMenuColors {
        /// メニュー背景色（宇宙空間の濃紺）
        static let background = CosmosColors.background.opacity(0.9)

        /// オーバーレイ背景色
        static let overlay = Color.black.opacity(0.35)

        /// 区切り線色
        static let divider = Color.white.opacity(0.2)

        /// アイコン色
        static let iconColor = Color.white.opacity(0.8)

        /// シェブロン色
        static let chevronColor = Color.white.opacity(0.5)
    }

    // MARK: - SideMenu Layout
    enum SideMenuLayout {
        /// メニュー幅の画面比率
        static let menuWidthRatio: CGFloat = 0.8

        /// メニューの最大幅
        static let menuMaxWidth: CGFloat = 300

        /// メニューの水平パディング
        static let menuHorizontalPadding: CGFloat = 16

        /// メニュー非表示時のオフセット
        static let menuHideOffset: CGFloat = 20

        /// 最小のleadingオフセット
        static let minLeadingOffset: CGFloat = 16

        /// メニューの角丸半径
        static let cornerRadius: CGFloat = 10

        /// ヘッダーの上部パディング
        static let headerTopPadding: CGFloat = 40

        /// メニュー項目の垂直パディング
        static let itemVerticalPadding: CGFloat = 14

        /// メニュー項目間のスペーシング
        static let itemSpacing: CGFloat = 20
    }

    // MARK: - SideMenu Typography
    enum SideMenuTypography {
        /// ヘッダータイトルのサイズ
        static let headerTitleSize: CGFloat = 20
        static let headerTitleWeight: Font.Weight = .bold

        /// メニュー項目タイトルのサイズ
        static let itemTitleSize: CGFloat = 17
        static let itemTitleWeight: Font.Weight = .regular

        /// アイコンのサイズ
        static let itemIconSize: CGFloat = 18

        /// シェブロンのサイズ
        static let chevronSize: CGFloat = 13

        /// フッター用のサイズ
        static let footerInfoSize: CGFloat = 12
        static let footerInfoWeight: Font.Weight = .regular
    }
}
