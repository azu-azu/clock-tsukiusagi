//
//  PlaylistRowView.swift
//  TsukiSound
//
//  プレイリスト行ビュー（ドラッグ可能なリスト用）
//

import SwiftUI

/// プレイリスト行ビュー
struct PlaylistRowView: View {
    let preset: UISoundPreset

    var body: some View {
        HStack {
            Text(preset.displayName)
                .dynamicFont(size: 16, weight: .medium)
                .foregroundColor(DesignTokens.SettingsColors.textPrimary)

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        PlaylistRowView(preset: .jupiterRemastered)
        Divider()
        PlaylistRowView(preset: .moonlitGymnopedie)
    }
    .background(Color.black)
}
