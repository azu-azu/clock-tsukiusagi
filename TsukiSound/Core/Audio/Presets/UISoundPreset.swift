//
//  UISoundPreset.swift
//  TsukiSound
//
//  UI display layer for sound presets (separate from technical parameters)
//

import Foundation
import UIKit

/// Sound preset for UI display (decoupled from technical implementation)
/// This enum represents what users see in the app, not how sounds are generated.
public enum UISoundPreset: String, CaseIterable, Identifiable {
    case jupiter                // ジュピター（PureTone module）
    case moonlitGymnopedie      // Moonlit Gymnopédie（Music Box音色）
    case acousticGymnopedie     // アコースティックギター版ジムノペディ

    public var id: String { rawValue }

    /// Emoji icon for this preset
    public var icon: String {
        switch self {
        case .jupiter:
            return "🪐"
        case .moonlitGymnopedie:
            return "🌖"
        case .acousticGymnopedie:
            return "🎸"
        }
    }

    /// Localization key for display name
    private var localizationKey: String {
        switch self {
        case .jupiter:
            return "preset.jupiter"
        case .moonlitGymnopedie:
            return "preset.gymnopedie"
        case .acousticGymnopedie:
            return "preset.acousticGymnopedie"
        }
    }

    /// Display name for UI (localized with emoji)
    public var displayName: String {
        return icon + " " + localizationKey.localized
    }

    /// Artwork image generated from emoji icon (for Now Playing)
    public var artworkImage: UIImage? {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Dark background
            UIColor(white: 0.1, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw emoji
            let emoji = icon as NSString
            let font = UIFont.systemFont(ofSize: 180)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let textSize = emoji.size(withAttributes: attributes)
            let origin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            emoji.draw(at: origin, withAttributes: attributes)
        }
    }

    /// English title for selected display
    public var englishTitle: String {
        switch self {
        case .jupiter:
            return "Jupiter (Holst)"
        case .moonlitGymnopedie:
            return "Moonlit Gymnopédie"
        case .acousticGymnopedie:
            return "Acoustic Gymnopédie"
        }
    }
}
