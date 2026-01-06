//
//  CategorySelectionView.swift
//  TsukiSound
//
//  Category selection grid view with Spotify-style mini player
//

import SwiftUI

/// Category selection view with 2-column grid
struct CategorySelectionView: View {
    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var playlistState: PlaylistState
    @Binding var selectedTab: Tab

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DesignTokens.SettingsColors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        // "All" category card
                        NavigationLink {
                            TrackListView(category: nil)
                        } label: {
                            CategoryCard(
                                title: "category.all".localized,
                                icon: "🎵",
                                trackCount: UISoundPreset.allCases.count
                            )
                        }
                        .buttonStyle(.plain)

                        // Category cards
                        ForEach(AudioCategory.allCases) { category in
                            NavigationLink {
                                TrackListView(category: category)
                            } label: {
                                CategoryCard(
                                    title: category.displayName,
                                    icon: category.icon,
                                    trackCount: category.presets.count
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, audioService.isPlaying ? 100 : 32)
                }

                // Floating mini player (Spotify-style)
                MiniPlayerView()
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioService.isPlaying)
            }
            .navigationTitle("audio.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .dynamicNavigationFont()
            .toolbarBackground(NavigationBarTokens.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBackButton {
                selectedTab = .clock
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedTab = .settings
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
    }
}

#Preview {
    CategorySelectionView(selectedTab: .constant(.audioPlayback))
        .environmentObject(AudioService.shared)
        .environmentObject(AudioService.shared.playlistState)
}
