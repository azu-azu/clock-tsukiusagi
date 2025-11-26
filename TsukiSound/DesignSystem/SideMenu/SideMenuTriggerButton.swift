//
//  SideMenuTriggerButton.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-20.
//  役割: SideMenuを開くトリガーボタン（歯車アイコン）
//

import SwiftUI

struct SideMenuTriggerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Open Menu")
    }
}
