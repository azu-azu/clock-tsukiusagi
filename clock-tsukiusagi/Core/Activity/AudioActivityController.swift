import ActivityKit
import Foundation

/// Controls Live Activity for audio playback on Lock Screen and Dynamic Island
@available(iOS 16.1, *)
@MainActor
final class AudioActivityController: ObservableObject {
    private var currentActivity: Activity<AudioActivityAttributes>?

    /// Whether Live Activity is currently active
    @Published private(set) var isActivityActive: Bool = false

    // MARK: - Lifecycle

    /// Start a new Live Activity
    func startActivity(
        isPlaying: Bool,
        nextBreakAt: Date?,
        outputRoute: String,
        pauseReason: String?,
        presetName: String?
    ) {
        // End existing activity if any
        endActivity()

        let attributes = AudioActivityAttributes()
        let contentState = AudioActivityAttributes.ContentState(
            isPlaying: isPlaying,
            nextBreakAt: nextBreakAt,
            outputRoute: outputRoute,
            pauseReason: pauseReason,
            presetName: presetName
        )

        do {
            if #available(iOS 16.2, *) {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: nil),
                    pushType: nil
                )
            } else {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
            }
            isActivityActive = true
            print("[AudioActivityController] Live Activity started: \(currentActivity?.id ?? "unknown")")
        } catch {
            print("[AudioActivityController] Failed to start Live Activity: \(error)")
            isActivityActive = false
        }
    }

    /// Update existing Live Activity with new state
    func updateActivity(
        isPlaying: Bool,
        nextBreakAt: Date?,
        outputRoute: String,
        pauseReason: String?,
        presetName: String?
    ) {
        guard let activity = currentActivity else {
            print("[AudioActivityController] No active activity to update")
            return
        }

        let contentState = AudioActivityAttributes.ContentState(
            isPlaying: isPlaying,
            nextBreakAt: nextBreakAt,
            outputRoute: outputRoute,
            pauseReason: pauseReason,
            presetName: presetName
        )

        Task {
            if #available(iOS 16.2, *) {
                await activity.update(.init(state: contentState, staleDate: nil))
            } else {
                await activity.update(using: contentState)
            }
            print("[AudioActivityController] Live Activity updated")
        }
    }

    /// End the current Live Activity
    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
            currentActivity = nil
            isActivityActive = false
            print("[AudioActivityController] Live Activity ended")
        }
    }

    /// End activity with dismissal policy
    func endActivity(after delay: TimeInterval) {
        guard let activity = currentActivity else { return }

        Task {
            // Use .after policy to keep visible for specified duration
            if #available(iOS 16.2, *) {
                await activity.end(
                    .init(state: activity.content.state, staleDate: nil),
                    dismissalPolicy: .after(Date.now.addingTimeInterval(delay))
                )
            } else {
                await activity.end(
                    using: activity.contentState,
                    dismissalPolicy: .after(Date.now.addingTimeInterval(delay))
                )
            }
            currentActivity = nil
            isActivityActive = false
            print("[AudioActivityController] Live Activity scheduled to end after \(delay)s")
        }
    }

    // MARK: - Convenience Methods

    /// Update only playback state (playing/paused)
    func updatePlaybackState(isPlaying: Bool, pauseReason: String? = nil) {
        guard let activity = currentActivity else { return }

        var state: AudioActivityAttributes.ContentState
        if #available(iOS 16.2, *) {
            state = activity.content.state
        } else {
            state = activity.contentState
        }
        state.isPlaying = isPlaying
        state.pauseReason = pauseReason

        Task {
            if #available(iOS 16.2, *) {
                await activity.update(.init(state: state, staleDate: nil))
            } else {
                await activity.update(using: state)
            }
        }
    }

    /// Update only next break time
    func updateNextBreak(at date: Date?) {
        guard let activity = currentActivity else { return }

        var state: AudioActivityAttributes.ContentState
        if #available(iOS 16.2, *) {
            state = activity.content.state
        } else {
            state = activity.contentState
        }
        state.nextBreakAt = date

        Task {
            if #available(iOS 16.2, *) {
                await activity.update(.init(state: state, staleDate: nil))
            } else {
                await activity.update(using: state)
            }
        }
    }

    /// Update only output route
    func updateOutputRoute(_ route: String) {
        guard let activity = currentActivity else { return }

        var state: AudioActivityAttributes.ContentState
        if #available(iOS 16.2, *) {
            state = activity.content.state
        } else {
            state = activity.contentState
        }
        state.outputRoute = route

        Task {
            if #available(iOS 16.2, *) {
                await activity.update(.init(state: state, staleDate: nil))
            } else {
                await activity.update(using: state)
            }
        }
    }
}
