//
//  Wave.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Basic waveforms
//

import Foundation

/// Basic waveforms expressed as Signals.
/// These functions do NOT handle frequency.
/// Frequency is handled by Oscillator, which converts (phase -> value)
/// into a time-driven signal.
///
/// Claude: These waveforms expect phase in 0...1.
public enum Wave {

    /// Pure sine wave
    public static let sine = Signal { phase in
        sin(2 * .pi * phase)
    }

    /// Triangle wave with smooth transitions
    public static let triangle = Signal { phase in
        let p = phase.truncatingRemainder(dividingBy: 1)
        if p < 0.25 {
            return p * 4
        } else if p < 0.75 {
            return 2 - p * 4
        } else {
            return p * 4 - 4
        }
    }

    /// Square wave (useful for clocks or rough textures)
    public static let square = Signal { phase in
        phase < 0.5 ? 1 : -1
    }

    /// Raw white noise
    public static let noise = Signal { _ in
        Float.random(in: -1...1)
    }
}
