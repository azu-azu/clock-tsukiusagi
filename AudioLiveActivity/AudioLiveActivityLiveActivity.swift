//
//  AudioLiveActivityLiveActivity.swift
//  AudioLiveActivity
//
//  Created by 松本和実 on 2025/11/11.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AudioLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AudioLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AudioLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension AudioLiveActivityAttributes {
    fileprivate static var preview: AudioLiveActivityAttributes {
        AudioLiveActivityAttributes(name: "World")
    }
}

extension AudioLiveActivityAttributes.ContentState {
    fileprivate static var smiley: AudioLiveActivityAttributes.ContentState {
        AudioLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AudioLiveActivityAttributes.ContentState {
         AudioLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AudioLiveActivityAttributes.preview) {
   AudioLiveActivityLiveActivity()
} contentStates: {
    AudioLiveActivityAttributes.ContentState.smiley
    AudioLiveActivityAttributes.ContentState.starEyes
}
