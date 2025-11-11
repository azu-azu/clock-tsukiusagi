import ActivityKit
import Foundation

/// Activity Attributes for Live Activity on Lock Screen and Dynamic Island
@available(iOS 16.1, *)
struct AudioActivityAttributes: ActivityAttributes {
    /// Static attributes (set once when activity starts)
    public struct ContentState: Codable, Hashable {
        /// Current playback state
        var isPlaying: Bool

        /// Scheduled break time (if quiet breaks enabled)
        var nextBreakAt: Date?

        /// Current audio output route
        var outputRoute: String  // "Headphones", "Bluetooth", "Speaker"

        /// Reason for pause (if not playing)
        var pauseReason: String?  // PauseReason.rawValue from AudioService

        /// Current preset name
        var presetName: String?
    }

    /// Fixed attributes (never change during activity lifetime)
    var appName: String = "Clock Tsukiusagi"
}
