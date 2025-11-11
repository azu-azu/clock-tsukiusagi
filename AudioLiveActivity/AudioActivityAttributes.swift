import ActivityKit
import Foundation

/// Activity Attributes for Live Activity on Lock Screen and Dynamic Island
@available(iOS 16.1, *)
public struct AudioActivityAttributes: ActivityAttributes {
    /// Dynamic state that changes during activity lifetime
    public struct ContentState: Codable, Hashable {
        /// Current playback state
        public var isPlaying: Bool

        /// Scheduled break time (if quiet breaks enabled)
        public var nextBreakAt: Date?

        /// Current audio output route
        public var outputRoute: String  // "Headphones", "Bluetooth", "Speaker"

        /// Reason for pause (if not playing)
        public var pauseReason: String?  // PauseReason.rawValue from AudioService

        /// Current preset name
        public var presetName: String?

        public init(
            isPlaying: Bool,
            nextBreakAt: Date? = nil,
            outputRoute: String,
            pauseReason: String? = nil,
            presetName: String? = nil
        ) {
            self.isPlaying = isPlaying
            self.nextBreakAt = nextBreakAt
            self.outputRoute = outputRoute
            self.pauseReason = pauseReason
            self.presetName = presetName
        }
    }

    public init() {}
}
