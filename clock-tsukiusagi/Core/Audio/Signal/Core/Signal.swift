//
//  Signal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Core abstraction for time-based audio signals
//

import Foundation

/// A time-based signal: (time: Float) -> Float
///
/// This is the core of the new audio system.
/// Every sound (LFO, oscillator, noise, envelope) is expressed as a Signal.
/// It is completely independent from sample rate.
///
/// Claude: Signals can be composed using +, *, and clamp() operators.
public struct Signal {
    public let fn: (Float) -> Float

    public init(_ fn: @escaping (Float) -> Float) {
        self.fn = fn
    }

    /// Evaluate the signal at a given time (seconds).
    public func callAsFunction(_ time: Float) -> Float {
        fn(time)
    }
}

// MARK: - Composition operators

/// Add two signals
public func + (lhs: Signal, rhs: Signal) -> Signal {
    Signal { t in lhs(t) + rhs(t) }
}

/// Multiply two signals
public func * (lhs: Signal, rhs: Signal) -> Signal {
    Signal { t in lhs(t) * rhs(t) }
}

/// Multiply signal by constant
public func * (lhs: Signal, rhs: Float) -> Signal {
    Signal { t in lhs(t) * rhs }
}

/// Multiply constant by signal
public func * (lhs: Float, rhs: Signal) -> Signal {
    Signal { t in lhs * rhs(t) }
}

/// Clamp signal to a range
public func clamp(_ s: Signal, min: Float = 0, max: Float = 1) -> Signal {
    Signal { t in
        let x = s(t)
        return Swift.max(min, Swift.min(max, x))
    }
}
