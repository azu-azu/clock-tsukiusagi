//
//  Noise.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Procedural noise generators
//

import Foundation

/// A set of procedural noise generators.
///
/// Claude:
/// Each noise is implemented as a Signal:
/// (Double time) -> Float amplitude.
/// These are sample-rate independent random functions.
public enum Noise {

    /// White noise: uncorrelated random values
    public static var white: Signal {
        Signal { _ in Float.random(in: -1...1) }
    }

    /// Brown noise: integrates white noise -> low frequency emphasis
    public static func brown(smoothing: Float = 0.02) -> Signal {
        var last: Float = 0
        return Signal { _ in
            let w = Float.random(in: -1...1)
            last = last + smoothing * w
            return max(min(last, 1), -1)
        }
    }

    /// Pink noise (approx)
    /// Using Voss-McCartney style randomness
    public static func pink() -> Signal {
        var b0: Float = 0
        var b1: Float = 0
        var b2: Float = 0
        return Signal { _ in
            let white = Float.random(in: -1...1)
            b0 = 0.997 * b0 + 0.029591 * white
            b1 = 0.985 * b1 + 0.032534 * white
            b2 = 0.950 * b2 + 0.048056 * white
            return (b0 + b1 + b2) * 0.3
        }
    }

    /// Random-walk noise (slow drifting)
    /// Useful for ocean floors, wind, distant thunder movement
    public static func randomWalk(step: Float = 0.02) -> Signal {
        var value: Float = 0
        return Signal { _ in
            let change = Float.random(in: -step...step)
            value = max(min(value + change, 1), -1)
            return value
        }
    }

    /// Bandpass noise
    /// Filter white noise into a specific frequency band
    public static func bandpass(
        low: Float,
        high: Float,
        resonance: Float = 0.1
    ) -> Signal {
        var last: Float = 0
        return Signal { _ in
            let x = Float.random(in: -1...1)
            let filtered = (x > low && x < high) ? x : 0
            last = last + resonance * (filtered - last)
            return last
        }
    }
}
