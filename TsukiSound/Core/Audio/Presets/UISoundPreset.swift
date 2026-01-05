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
    case jupiter                // ジュピター（Pedalboard処理版）
    case moonlitGymnopedie      // Moonlit Gymnopédie（Music Box音色）
    case acousticGymnopedie     // アコースティックギター版ジムノペディ
    case gnossienne1            // グノシエンヌ第1番
    case gnossienne3            // グノシエンヌ第3番
    case gnossienne4Jazz        // グノシエンヌ第4番（ジャズアレンジ）
    case clairDeLune            // 月の光（ドビュッシー）
    case moonlightSonataHipHop  // 月光ソナタ（ベートーヴェン Hip-Hop）
    case bachAirOnGString       // G線上のアリア（バッハ）
    case bachMinuet             // メヌエット（バッハ）
    case chopinNocturneRain     // ノクターン Op.9-2 雨（ショパン）
    // Canon variations
    case canonOriginal          // カノン オリジナル
    case canonAmbient           // カノン アンビエント
    case canonSaxophone         // カノン サックス
    case canonClassic           // カノン クラシック
    case canonPiano             // カノン ピアノ
    case canonPiano2            // カノン ピアノ2
    case canonPianoStrings      // カノン ピアノ＆ストリングス
    case canon2                 // カノン2
    case canon3                 // カノン3

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
        case .gnossienne1:
            return "🎹"
        case .gnossienne3:
            return "🎹"
        case .gnossienne4Jazz:
            return "🎷"
        case .clairDeLune:
            return "🌙"
        case .moonlightSonataHipHop:
            return "🎤"
        case .bachAirOnGString:
            return "🎻"
        case .bachMinuet:
            return "🎼"
        case .chopinNocturneRain:
            return "🌧️"
        case .canonOriginal:
            return "🎻"
        case .canonAmbient:
            return "🌌"
        case .canonSaxophone:
            return "🎷"
        case .canonClassic:
            return "🎼"
        case .canonPiano:
            return "🎹"
        case .canonPiano2:
            return "🎹"
        case .canonPianoStrings:
            return "🎻"
        case .canon2:
            return "🎼"
        case .canon3:
            return "🎼"
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
        case .gnossienne1:
            return "preset.gnossienne1"
        case .gnossienne3:
            return "preset.gnossienne3"
        case .gnossienne4Jazz:
            return "preset.gnossienne4Jazz"
        case .clairDeLune:
            return "preset.clairDeLune"
        case .moonlightSonataHipHop:
            return "preset.moonlightSonataHipHop"
        case .bachAirOnGString:
            return "preset.bachAirOnGString"
        case .bachMinuet:
            return "preset.bachMinuet"
        case .chopinNocturneRain:
            return "preset.chopinNocturneRain"
        case .canonOriginal:
            return "preset.canonOriginal"
        case .canonAmbient:
            return "preset.canonAmbient"
        case .canonSaxophone:
            return "preset.canonSaxophone"
        case .canonClassic:
            return "preset.canonClassic"
        case .canonPiano:
            return "preset.canonPiano"
        case .canonPiano2:
            return "preset.canonPiano2"
        case .canonPianoStrings:
            return "preset.canonPianoStrings"
        case .canon2:
            return "preset.canon2"
        case .canon3:
            return "preset.canon3"
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
            return "Gymnopédie No.1 (Satie)"
        case .acousticGymnopedie:
            return "Gymnopédie Acoustic (Satie)"
        case .gnossienne1:
            return "Gnossienne No.1 (Satie)"
        case .gnossienne3:
            return "Gnossienne No.3 (Satie)"
        case .gnossienne4Jazz:
            return "Gnossienne No.4 Jazz (Satie)"
        case .clairDeLune:
            return "Clair de Lune (Debussy)"
        case .moonlightSonataHipHop:
            return "Moonlight Sonata Hip-Hop (Beethoven)"
        case .bachAirOnGString:
            return "Air on the G String (Bach)"
        case .bachMinuet:
            return "Minuet (Bach)"
        case .chopinNocturneRain:
            return "Nocturne Op.9-2 Rain (Chopin)"
        case .canonOriginal:
            return "Canon Original (Pachelbel)"
        case .canonAmbient:
            return "Canon Ambient (Pachelbel)"
        case .canonSaxophone:
            return "Canon Saxophone (Pachelbel)"
        case .canonClassic:
            return "Canon Classic (Pachelbel)"
        case .canonPiano:
            return "Canon Piano (Pachelbel)"
        case .canonPiano2:
            return "Canon Piano 2 (Pachelbel)"
        case .canonPianoStrings:
            return "Canon Piano & Strings (Pachelbel)"
        case .canon2:
            return "Canon 2 (Pachelbel)"
        case .canon3:
            return "Canon 3 (Pachelbel)"
        }
    }
}
