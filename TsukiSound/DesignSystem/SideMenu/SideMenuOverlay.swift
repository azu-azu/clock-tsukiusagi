//
//  SideMenuOverlay.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-20.
//  役割: SideMenu表示時の背景オーバーレイ（タップで閉じる）
//

import SwiftUI

struct SideMenuOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            DesignTokens.SideMenuColors.overlay
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
                .transition(.opacity)
        }
    }
}
