//
//  ClockSideMenu.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-20.
//  役割: Clock用サイドメニュー本体（左スライドイン）
//

import SwiftUI

struct ClockSideMenu: View {
    @Binding var isPresented: Bool

    var onBackToFront: () -> Void
    var onOpenAudio: () -> Void
    var onOpenAudioSettings: () -> Void

    var body: some View {
        GeometryReader { geo in
            let safe = geo.safeAreaInsets
            let size = geo.size

            // レスポンシブ幅計算
            let baseMenuWidth: CGFloat = min(
                size.width * DesignTokens.SideMenuLayout.menuWidthRatio,
                DesignTokens.SideMenuLayout.menuMaxWidth
            )
            let leadingOffset: CGFloat = max(
                safe.leading,
                DesignTokens.SideMenuLayout.minLeadingOffset
            )
            let menuWidth: CGFloat = baseMenuWidth
            let effectiveMenuWidth: CGFloat = menuWidth + leadingOffset + DesignTokens.SideMenuLayout.menuHorizontalPadding

            ZStack {
                // メニュー本体
                HStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {

                            // Header
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🌙 TsukiUsagi")
                                    .font(DesignTokens.SideMenuTypography.headerTitle)
                                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                            }
                            .padding(.top, safe.top + DesignTokens.SideMenuLayout.headerTopPadding)
                            .padding(.bottom, 20)
                            .sideMenuPadding(leadingOffset: leadingOffset)

                            Divider()
                                .background(DesignTokens.SideMenuColors.divider)
                                .sideMenuPadding(leadingOffset: leadingOffset)

                            // Menu Items
                            VStack(alignment: .leading, spacing: DesignTokens.SideMenuLayout.itemSpacing) {

                                menuItem(
                                    icon: "clock",
                                    title: "Front",
                                    action: {
                                        onBackToFront()
                                        close()
                                    }
                                )

                                menuItem(
                                    icon: "music.quarternote.3",
                                    title: "Audio",
                                    action: {
                                        onOpenAudio()
                                        close()
                                    }
                                )

                                menuItem(
                                    icon: "slider.horizontal.3",
                                    title: "Audio Settings",
                                    action: {
                                        onOpenAudioSettings()
                                        close()
                                    }
                                )

                                // TODO: App Settings (未実装)

                                Spacer()
                            }
                            .padding(.top, 24)
                            .sideMenuPadding(leadingOffset: leadingOffset)

                            Spacer(minLength: safe.bottom + 30)
                        }
                    }
                    .frame(width: menuWidth)
                    .padding(.leading, leadingOffset + DesignTokens.SideMenuLayout.menuHorizontalPadding)
                    .frame(maxHeight: .infinity)

                    .background(DesignTokens.SideMenuColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.SideMenuLayout.cornerRadius))
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: -4, y: 0)
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 4, y: 0)

                    .offset(x: isPresented ? 0 : -effectiveMenuWidth - DesignTokens.SideMenuLayout.menuHideOffset)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    Spacer()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isPresented)
        }
    }

    private func menuItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(DesignTokens.SideMenuTypography.itemIcon)
                    .foregroundColor(DesignTokens.SideMenuColors.iconColor)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(DesignTokens.SideMenuTypography.itemTitle)
                    .foregroundColor(DesignTokens.SettingsColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DesignTokens.SideMenuTypography.chevron)
                    .foregroundColor(DesignTokens.SideMenuColors.chevronColor)
            }
            .padding(.vertical, DesignTokens.SideMenuLayout.itemVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

private extension View {
    func sideMenuPadding(leadingOffset: CGFloat) -> some View {
        self
            .padding(.leading, 16)
            .padding(.trailing, 16)
    }
}
