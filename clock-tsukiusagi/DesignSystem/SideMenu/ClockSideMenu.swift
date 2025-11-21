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

            ZStack(alignment: .topLeading) {
                // メニュー本体
                HStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {

                                // Header
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("🌙")
                                        .font(.title)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TsukiUsagi")
                                            .font(DesignTokens.SideMenuTypography.headerTitle)
                                            .foregroundColor(DesignTokens.SettingsColors.textPrimary)
                                    }

                                    Spacer()
                                }
                            }
                            .sideMenuPadding(leadingOffset: leadingOffset)
                            .padding(.top, 60)
                            .padding(.bottom, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        DesignTokens.CosmosColors.background,
                                        DesignTokens.CosmosColors.background.opacity(0.95)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

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

                                Divider()
                                    .background(DesignTokens.SideMenuColors.divider)
                                    .padding(.top, DesignTokens.SideMenuLayout.itemSpacing)

                                // フッター（アプリ情報）
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TsukiUsagi Clock")
                                        .font(DesignTokens.SideMenuTypography.itemTitle)
                                        .foregroundColor(DesignTokens.SettingsColors.textSecondary.opacity(0.6))

                                    Text("Version 1.0.0")
                                        .font(DesignTokens.SideMenuTypography.itemTitle)
                                        .foregroundColor(DesignTokens.SettingsColors.textSecondary.opacity(0.6))
                                }
                                .padding(.top, DesignTokens.SideMenuLayout.itemSpacing)

                                Spacer()
                            }
                            .padding(.top, 24)
                            .sideMenuPadding(leadingOffset: leadingOffset)

                            Spacer(minLength: safe.bottom + 30)
                        }
                    }
                    .frame(width: menuWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.leading, leadingOffset + DesignTokens.SideMenuLayout.menuHorizontalPadding)
                    .background(DesignTokens.SideMenuColors.background)
                    .cornerRadius(DesignTokens.SideMenuLayout.cornerRadius)
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: -4, y: 0)
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 4, y: 0)
                    .offset(x: isPresented ? 0 : -effectiveMenuWidth - DesignTokens.SideMenuLayout.menuHideOffset)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .edgesIgnoringSafeArea(.all)
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
