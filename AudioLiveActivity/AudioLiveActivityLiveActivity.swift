//
//  AudioLiveActivityLiveActivity.swift
//  AudioLiveActivity
//
//  Created by Claude Code on 2025/11/11.
//  Live Activity UI for Lock Screen and Dynamic Island
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AudioLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AudioActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: context.state.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                            .foregroundColor(context.state.isPlaying ? .green : .orange)
                        Text(context.state.presetName ?? "音声")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.outputRoute)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let nextBreak = context.state.nextBreakAt {
                            Text("次の休憩: \(nextBreak, style: .time)")
                                .font(.caption2)
                        } else if let reason = context.state.pauseReason {
                            Text("停止: \(reason)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                        .foregroundColor(context.state.isPlaying ? .green : .orange)
                    if let name = context.state.presetName {
                        Text(name)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            } compactTrailing: {
                Image(systemName: audioOutputIcon(for: context.state.outputRoute))
                    .font(.caption2)
            } minimal: {
                // Show emoji icon from preset name (e.g., "🪐 Jupiter" → "🪐")
                if let name = context.state.presetName, let firstChar = name.first, firstChar.isEmoji {
                    Text(String(firstChar))
                        .font(.system(size: 24))
                } else {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                }
            }
            .keylineTint(Color.green)
        }
    }
}

// MARK: - Helper Functions

/// Check if a character is an emoji
extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && scalar.value > 0x238C
    }
}

/// Get SF Symbol icon for audio output route
private func audioOutputIcon(for route: String) -> String {
    let lowercased = route.lowercased()
    if lowercased.contains("headphone") || lowercased.contains("ヘッドホン") {
        return "headphones"
    } else if lowercased.contains("bluetooth") || lowercased.contains("ブルートゥース") {
        return "antenna.radiowaves.left.and.right"
    } else if lowercased.contains("speaker") || lowercased.contains("スピーカー") {
        return "speaker.wave.2"
    } else {
        return "speaker.wave.1"
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let state: AudioActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: state.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(state.isPlaying ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                // Preset name
                Text(state.presetName ?? "クリック音防止")
                    .font(.headline)
                    .foregroundColor(.white)

                // Output route
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                    Text(state.outputRoute)
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                // Next break or pause reason
                if let nextBreak = state.nextBreakAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("休憩: \(nextBreak, style: .time)")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                } else if let reason = state.pauseReason {
                    Text("停止理由: \(reason)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Preview

#Preview("Playing", as: .content, using: AudioActivityAttributes()) {
    AudioLiveActivityLiveActivity()
} contentStates: {
    AudioActivityAttributes.ContentState(
        isPlaying: true,
        nextBreakAt: Date().addingTimeInterval(1800),
        outputRoute: "ヘッドホン",
        pauseReason: nil,
        presetName: "クリック音防止"
    )
    AudioActivityAttributes.ContentState(
        isPlaying: false,
        nextBreakAt: nil,
        outputRoute: "スピーカー",
        pauseReason: "routeSafetySpeaker",
        presetName: "クリック音防止"
    )
}
