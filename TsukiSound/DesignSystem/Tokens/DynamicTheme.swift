//
//  DynamicTheme.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-21.
//  動的デザイントークン - フォントなど環境・設定に依存する値
//

import SwiftUI

/// 動的デザイントークン - 環境や設定に依存する値（フォント、将来のテーマなど）
struct DynamicTheme {

    // MARK: - Clock Typography
    enum ClockTypography {
        /// メインの時刻フォントサイズ
        static let clockFontSize: CGFloat = 56

        /// キャプションフォントサイズ
        static let captionFontSize: CGFloat = 16
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

    // MARK: - AudioTest Typography
    enum AudioTestTypography {
        /// Bluetooth/Status インジケーター
        static let statusIndicatorSize: CGFloat = 15
        static let statusIndicatorWeight: Font.Weight = .regular

        /// サウンド選択メニュー
        static let soundMenuSize: CGFloat = 17
        static let soundMenuWeight: Font.Weight = .regular

        /// 英語タイトル
        static let englishTitleSize: CGFloat = 13
        static let englishTitleWeight: Font.Weight = .regular

        /// 音量ラベル・パーセンテージ
        static let volumeLabelSize: CGFloat = 15
        static let volumeLabelWeight: Font.Weight = .regular

        /// ステータスセクションタイトル
        static let statusTitleSize: CGFloat = 17
        static let statusTitleWeight: Font.Weight = .semibold

        /// ステータステキスト
        static let statusTextSize: CGFloat = 15
        static let statusTextWeight: Font.Weight = .regular

        /// ステータスキャプション
        static let statusCaptionSize: CGFloat = 13
        static let statusCaptionWeight: Font.Weight = .regular

        /// 見出し
        static let headlineSize: CGFloat = 17
        static let headlineWeight: Font.Weight = .semibold
    }
}

// MARK: - Font Style Extension

extension FontStyle {
    /// フォントスタイルに基づいて動的にフォントを生成
    /// - Parameters:
    ///   - size: フォントサイズ
    ///   - weight: フォントウェイト
    /// - Returns: 適用されたフォント
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: self.design)
    }

    /// フォントデザインを取得
    var design: Font.Design {
        switch self {
        case .monospaced: return .monospaced
        case .rounded: return .rounded
        }
    }
}
