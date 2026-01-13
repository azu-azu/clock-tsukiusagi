import SwiftUI

/// デザイントークン - アプリ全体で使用する色、スペーシング、レイアウトなどの統一された値
///
/// 📌 **設計方針**
///
/// - **DesignTokens**: 色、スペーシング、レイアウトなどの固定値を定義
/// - **DynamicTheme**: フォントなど環境・設定に依存する値を定義
///
/// **使用ガイドライン**:
/// - フォント関連は `DynamicTheme.AudioTestTypography` + `.dynamicFont()` を使用
/// - 色・spacing・layout は `DesignTokens` を使用
/// - 共通のテキスト色は `CommonTextColors` から参照
struct DesignTokens {

    // MARK: - Common Text Colors (基礎色)

    /// 共通のテキスト色定義（全画面で共通の基礎）
    ///
    /// **使用ガイドライン**:
    /// - primary: 最も重要なテキスト（タイトル、時刻など）
    /// - secondary: 重要なテキスト（見出し、ラベルなど）
    /// - tertiary: 補助的なテキスト（説明文、キャプションなど）
    /// - quaternary: 控えめなテキスト（ヒント、プレースホルダーなど）
    /// - quinary: さらに薄いテキスト（非アクティブなど）
    enum CommonTextColors {
        static let primary = Color.white.opacity(0.95)
        static let secondary = Color.white.opacity(0.8)
        static let tertiary = Color.white.opacity(0.7)
        static let quaternary = Color.white.opacity(0.6)
        static let quinary = Color.white.opacity(0.5)
    }

    // MARK: - Common Background Colors (背景色)

    /// 共通の背景色定義（全画面で共通の基礎）
    ///
    /// **使用ガイドライン**:
    /// - card: 標準カード背景
    /// - cardHighlight: ハイライトされたカード背景（通常より明るい）
    /// - cardInteractive: インタラクティブなカード背景（選択・強調用、最も明るい）
    /// - cardBorder: カードの枠線
    enum CommonBackgroundColors {
        /// カード背景色（全画面共通）
        static let card = Color.white.opacity(0.1)

        /// ハイライトされたカード背景色（通常より明るい）
        static let cardHighlight = Color.white.opacity(0.15)

        /// インタラクティブなカード背景色（選択・強調用、最も明るい）
        static let cardInteractive = Color.white.opacity(0.25)

        /// カードの枠線色
        static let cardBorder = Color.white.opacity(0.3)

        /// カードの枠線色（控えめ）
        static let cardBorderSubtle = Color.white.opacity(0.1)

        /// カード背景色（最小）
        static let cardSubtle = Color.white.opacity(0.08)

        /// カード背景色（極薄）
        static let cardMinimal = Color.white.opacity(0.03)

        /// プレビュー背景色
        static let previewBackground = Color.black

        /// シャドウ色
        static let shadow = Color.black.opacity(0.3)

        /// シャドウ色（強め）
        static let shadowStrong = Color.black.opacity(0.4)
    }

    // MARK: - Clock Colors
    enum ClockColors {
        /// メインのテキスト色（時刻表示など）
        static let textPrimary = CommonTextColors.primary

        /// グロー効果の色
        static let glow = Color.white.opacity(0.6)

        /// キャプション用の特殊色（濃い青色、背景色とは独立）
        static let captionBlue = Color(hex: "#3d5a80")

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

        /// アナログ時計の数字フォント
        static let analogClockNumberFont = Font.custom("AmericanTypewriter-CondensedBold", size: 22)
    }

    // MARK: - Analog Clock
    enum AnalogClock {
        /// 時針の長さ（半径に対する比率）
        static let hourHandLength: CGFloat = 0.55
        /// 分針の長さ（半径に対する比率）
        static let minuteHandLength: CGFloat = 0.78
        /// 秒針の長さ（半径に対する比率）
        static let secondHandLength: CGFloat = 0.55

        /// 時針の太さ
        static let hourHandWidth: CGFloat = 6
        /// 分針の太さ
        static let minuteHandWidth: CGFloat = 5
        /// 秒針の太さ
        static let secondHandWidth: CGFloat = 2

        /// 時針・分針の不透明度
        static let handOpacity: CGFloat = 0.95
        /// 秒針の不透明度
        static let secondHandOpacity: CGFloat = 0.7

        /// 中心円のサイズ
        static let centerCircleSize: CGFloat = 8
    }

    // MARK: - Clock Spacing
    enum ClockSpacing {
        /// 時刻とキャプションの間隔
        static let timeCaptionSpacing: CGFloat = 6

        /// 下部パディング（波との間隔を確保） ※デジタル時計の位置
        static let bottomPadding: CGFloat = 70
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
        static let cardBackgroundAlt = CommonBackgroundColors.card
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
        static let cardBackground = CommonBackgroundColors.card

        /// アクセントカラー（システムのアクセントカラー）
        static let accent = Color.accentColor

        /// プライマリテキスト色
        static let textPrimary = CommonTextColors.primary

        /// セカンダリテキスト色（説明文など）
        static let textSecondary = CommonTextColors.tertiary

        /// Tertiary テキスト色（キャプションなど）
        static let textTertiary = CommonTextColors.quaternary

        /// 薄いテキスト色（ヒントなど）
        static let textQuaternary = CommonTextColors.quinary

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
        static let iconColor = CommonTextColors.secondary

        /// シェブロン色・説明文色
        static let textMuted = CommonTextColors.quaternary
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
