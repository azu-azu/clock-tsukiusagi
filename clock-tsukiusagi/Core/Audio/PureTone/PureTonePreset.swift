//
//  PureTonePreset.swift
//  clock-tsukiusagi
//
//  Pure tone preset definitions (separate from NaturalSound)
//

import Foundation

/// Pure tone presets (sine wave based, highly sensitive to parameter changes)
public enum PureTonePreset {
    case lunarPulse         // 528Hz pure tone only
    case lunarPulseChime    // 528Hz pure tone + TreeChime overlay
    case treeChimeOnly      // TreeChime only (for testing)

    /// Get parameters for this preset
    public var params: PureToneParams {
        switch self {
        case .lunarPulse, .lunarPulseChime:
            // Both use the same base LunarPulse parameters
            return PureToneParams(
                frequency: 528.0,      // Solfeggio frequency
                amplitude: 0.2,        // Base volume
                lfoFrequency: 0.06,    // Ultra-slow breathing (≈16.7s cycle)
                lfoMinimum: 0.02,      // Amplitude modulation minimum
                lfoMaximum: 0.12       // Amplitude modulation maximum
            )
        case .treeChimeOnly:
            // No LunarPulse for this preset (chime only)
            return PureToneParams(
                frequency: 0.0,        // Not used
                amplitude: 0.0,        // Not used
                lfoFrequency: 0.0,     // Not used
                lfoMinimum: 0.0,       // Not used
                lfoMaximum: 0.0        // Not used
            )
        }
    }

    /// Whether this preset includes TreeChime overlay
    public var includesChime: Bool {
        switch self {
        case .lunarPulseChime, .treeChimeOnly:
            return true
        case .lunarPulse:
            return false
        }
    }

    /// Whether this preset includes LunarPulse
    public var includesLunarPulse: Bool {
        switch self {
        case .lunarPulse, .lunarPulseChime:
            return true
        case .treeChimeOnly:
            return false
        }
    }
}
