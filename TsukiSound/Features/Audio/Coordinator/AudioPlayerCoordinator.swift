//
//  AudioPlayerCoordinator.swift
//  TsukiSound
//
//  Centralized coordinator for audio player sheet and navigation state.
//  Prevents nested sheets by managing presentation at a single level.
//

import SwiftUI

/// Navigation destination after dismissing FullPlayerView
enum AudioNavigation: Hashable {
    case category(AudioCategory?)  // nil = "All" category
}

/// Coordinator for audio player presentation and navigation
/// - Sheet presentation is managed here (single source of truth)
/// - FullPlayerView notifies this coordinator instead of navigating directly
@MainActor
final class AudioPlayerCoordinator: ObservableObject {
    /// Whether the full player sheet is presented
    @Published var isFullPlayerPresented = false

    /// Pending navigation to execute after sheet dismisses
    @Published var pendingNavigation: AudioNavigation?

    /// Currently displayed category in TrackListView (nil = not on TrackListView)
    /// Used to prevent duplicate navigation to the same category
    @Published var currentDisplayedCategory: AudioCategory?

    /// Whether currently on TrackListView
    @Published var isOnTrackListView = false

    /// Show the full player sheet
    func showFullPlayer() {
        isFullPlayerPresented = true
    }

    /// Dismiss the full player and optionally navigate
    /// If already viewing the same category, navigation is skipped
    func dismissFullPlayer(navigateTo destination: AudioNavigation? = nil) {
        // Check if navigation would be redundant (already on the same category)
        if let dest = destination,
           case .category(let targetCategory) = dest,
           isOnTrackListView,
           targetCategory == currentDisplayedCategory {
            // Already viewing this category - just dismiss, no navigation needed
            pendingNavigation = nil
        } else {
            pendingNavigation = destination
        }
        isFullPlayerPresented = false
    }

    /// Clear pending navigation (call after navigation is executed)
    func clearPendingNavigation() {
        pendingNavigation = nil
    }

    /// Called when entering TrackListView
    func enterTrackListView(category: AudioCategory?) {
        isOnTrackListView = true
        currentDisplayedCategory = category
    }

    /// Called when leaving TrackListView
    func leaveTrackListView() {
        isOnTrackListView = false
        currentDisplayedCategory = nil
    }
}
