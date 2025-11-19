//
//  SettingsComponents.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-14.
//  設定画面用の共通コンポーネント
//

import SwiftUI

// MARK: - Settings Section

/// 設定セクション（タイトル + カードスタイルのコンテンツ）
public struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SettingsSpacing.sectionInnerSpacing) {
            Text(title)
                .font(DesignTokens.SettingsTypography.sectionTitle)
                .foregroundColor(DesignTokens.SettingsColors.textHighlight)

            VStack(spacing: DesignTokens.SettingsSpacing.itemSpacing) {
                content
            }
            .padding(DesignTokens.SettingsSpacing.cardPadding)
            .background(DesignTokens.SettingsColors.cardBackground)
            .cornerRadius(DesignTokens.SettingsLayout.cardCornerRadius)
        }
    }
}

// MARK: - Settings Toggle

/// 設定トグル（タイトル + サブタイトル + トグルスイッチ）
public struct SettingsToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    public init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignTokens.SettingsTypography.itemTitle)
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.SettingsTypography.caption)
                        .foregroundColor(DesignTokens.SettingsColors.textTertiary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.SettingsColors.accent)
        }
    }
}

// MARK: - Settings Stepper

/// 設定ステッパー（タイトル + 値表示 + ステッパー）
public struct SettingsStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    public init(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(DesignTokens.SettingsTypography.itemTitle)
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)
            Spacer()
            Text("\(value) \(unit)")
                .font(DesignTokens.SettingsTypography.itemTitle)
                .foregroundColor(DesignTokens.SettingsColors.accent)
                .monospacedDigit()
                .frame(width: DesignTokens.SettingsLayout.stepperValueWidth, alignment: .trailing)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

// MARK: - Settings Card Style (View Modifier)

/// 設定カードスタイルを適用する ViewModifier
public struct SettingsCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(DesignTokens.SettingsSpacing.cardPadding)
            .background(DesignTokens.SettingsColors.cardBackground)
            .cornerRadius(DesignTokens.SettingsLayout.cardCornerRadius)
    }
}

/// 音源選択カード専用のスタイル（強調表示）
public struct InteractiveCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(DesignTokens.SettingsSpacing.cardPadding)
            .padding(.vertical, 4) // 行間を少し広げる
            .background(Color.white.opacity(0.25)) // 通常のカードより明るい
            .cornerRadius(DesignTokens.SettingsLayout.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.SettingsLayout.cardCornerRadius)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1) // 枠線
            )
            .shadow(color: Color.black.opacity(0.3), radius: 4, y: 1) // 微妙な影で浮き上がる
    }
}

extension View {
    /// 設定カードスタイルを適用
    public func settingsCardStyle() -> some View {
        modifier(SettingsCardStyle())
    }

    /// インタラクティブカードスタイルを適用（操作可能なカード用）
    public func interactiveCardStyle() -> some View {
        modifier(InteractiveCardStyle())
    }
}

// MARK: - Preview

#Preview("Settings Section") {
    ZStack {
        DesignTokens.SettingsColors.backgroundGradient
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: DesignTokens.SettingsSpacing.sectionSpacing) {
                SettingsSection(title: "Example Section") {
                    SettingsToggle(
                        title: "Toggle Item",
                        subtitle: "This is a subtitle",
                        isOn: .constant(true)
                    )

                    SettingsStepper(
                        title: "Stepper Item",
                        value: .constant(10),
                        range: 5...30,
                        step: 5,
                        unit: "min"
                    )
                }
            }
            .padding(DesignTokens.SettingsSpacing.screenHorizontal)
        }
    }
}
