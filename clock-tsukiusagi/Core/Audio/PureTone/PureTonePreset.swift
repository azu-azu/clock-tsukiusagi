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
        }
    }

    /// Whether this preset includes TreeChime overlay
    public var includesChime: Bool {
        switch self {
        case .lunarPulseChime:
            return true
        case .lunarPulse:
            return false
        }
    }
}
