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

    /// Whether mini player should be visible (has a selected track)
    private var showMiniPlayer: Bool {
        playlistState.presetForCurrentIndex() != nil
    }

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
                                trackCount: UISoundPreset.allCases.count,
                                onPlayTapped: {
                                    playCategory(nil)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(action: {
                                playCategory(nil)
                            }) {
                                Label("audio.play".localized, systemImage: "play.fill")
                            }
                        }

                        // Category cards
                        ForEach(AudioCategory.allCases) { category in
                            NavigationLink {
                                TrackListView(category: category)
                            } label: {
                                CategoryCard(
                                    title: category.displayName,
                                    icon: category.icon,
                                    trackCount: category.presets.count,
                                    onPlayTapped: {
                                        playCategory(category)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(action: {
                                    playCategory(category)
                                }) {
                                    Label("audio.play".localized, systemImage: "play.fill")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.SettingsSpacing.screenHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, showMiniPlayer ? 100 : 32)
                }

                // Floating mini player (Spotify-style, visible when track selected)
                MiniPlayerView()
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showMiniPlayer)
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
                // Output route fallback (only when MiniPlayer hidden)
                if !showMiniPlayer {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: 4) {
                            Text(audioService.outputRoute.icon)
                                .font(.system(size: 16))
                            Text(audioService.outputRoute.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                }

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

    // MARK: - Actions

    /// Play the selected category starting from its first track
    private func playCategory(_ category: AudioCategory?) {
        playlistState.setCategory(category)
        try? audioService.playPlaylist()
    }
}

#Preview {
    CategorySelectionView(selectedTab: .constant(.audioPlayback))
        .environmentObject(AudioService.shared)
        .environmentObject(AudioService.shared.playlistState)
}
