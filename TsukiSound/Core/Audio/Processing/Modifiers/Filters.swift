//
//  Filters.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Simple DSP filters for ambient synthesis
//

import Foundation

/// Simple DSP Filters for ambient synthesis.
///
/// Claude:
/// These filters operate on Float signals and are sample-rate independent.
/// They are used to soften noise, create distance, and make modulation smoother.
public enum Filter {

    /// One-pole low-pass filter (natural, smooth)
    public static func lowpass(cutoff: Float) -> (Float) -> Float {
        var last: Float = 0
        let c = cutoff
        return { x in
            last += c * (x - last)
            return last
        }
    }

    /// One-pole high-pass filter
    public static func highpass(cutoff: Float) -> (Float) -> Float {
        var lastInput: Float = 0
        var lastOutput: Float = 0
        let c = cutoff
        return { x in
            let y = c * (lastOutput + x - lastInput)
            lastInput = x
            lastOutput = y
            return y
        }
    }

    /// Smooth / Lag (slew limiter)
    /// Makes LFO and parameters glide naturally.
    public static func smooth(amount: Float) -> (Float) -> Float {
        var value: Float = 0
        return { x in
            value += amount * (x - value)
            return value
        }
    }

    /// Low-pass applied as a Signal wrapper
    public static func applyLowpass(_ input: Signal, cutoff: Float) -> Signal {
        let lp = lowpass(cutoff: cutoff)
        return Signal { t in
            lp(input(t))
        }
    }

    /// High-pass as Signal
    public static func applyHighpass(_ input: Signal, cutoff: Float) -> Signal {
        let hp = highpass(cutoff: cutoff)
        return Signal { t in
            hp(input(t))
        }
    }

    /// Dynamic LPF (cutoff follows LFO)
    /// Note: This is a simplified version, state management may need refinement
    public static func dynamicLowpass(
        _ input: Signal,
        lfo: Signal,
        minCutoff: Float,
        maxCutoff: Float
    ) -> Signal {
        var last: Float = 0
        return Signal { t in
            let l = (lfo(t) + 1) * 0.5   // LFO −1〜1 → 0〜1
            let cutoff = minCutoff + l * (maxCutoff - minCutoff)
            let c = cutoff
            // Simple inline LPF
            let value = input(t)
            last += c * (value - last)
            return last
        }
    }
}
