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
    let isCurrentTrack: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 再生中インジケータ
            Image(systemName: isCurrentTrack && isPlaying ? "speaker.wave.2.fill" : "music.note")
                .font(.system(size: 16))
                .foregroundColor(
                    isCurrentTrack && isPlaying
                        ? DesignTokens.SettingsColors.accent
                        : DesignTokens.SettingsColors.textSecondary
                )
                .frame(width: 24)

            // 曲名
            Text(preset.displayName)
                .dynamicFont(size: 16, weight: .medium)
                .foregroundColor(
                    isCurrentTrack
                        ? DesignTokens.SettingsColors.accent
                        : DesignTokens.SettingsColors.textPrimary
                )

            Spacer()

            // 現在再生中マーカー
            if isCurrentTrack && isPlaying {
                Text("playing".localized)
                    .dynamicFont(size: 10, weight: .medium)
                    .foregroundColor(DesignTokens.SettingsColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignTokens.SettingsColors.accent.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        PlaylistRowView(preset: .jupiter, isCurrentTrack: true, isPlaying: true)
        Divider()
        PlaylistRowView(preset: .moonlitGymnopedie, isCurrentTrack: false, isPlaying: true)
    }
    .background(Color.black)
}
