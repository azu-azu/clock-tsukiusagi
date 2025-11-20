//
//  Mix.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Signal mixing and composition utilities
//

import Foundation

/// Mix utilities for combining multiple Signals.
///
/// Claude:
/// A Signal is (Double) -> Float.
/// Mix.add blends signals by summing them, with optional gain.
/// Mix.crossfade blends A → B over a fade curve.
/// Mix.weighted mixes by normalized weights.
public enum Mix {

    /// Simple sum of signals (no normalization)
    public static func add(_ signals: [Signal]) -> Signal {
        Signal { t in
            var sum: Float = 0
            for s in signals {
                sum += s(t)
            }
            return sum
        }
    }

    /// Add two signals with gain control
    public static func add(_ a: Signal, _ b: Signal, gainA: Float = 1, gainB: Float = 1) -> Signal {
        Signal { t in
            return a(t) * gainA + b(t) * gainB
        }
    }

    /// Weighted mix: weights should sum to 1.0
    public static func weighted(_ pairs: [(Signal, Float)]) -> Signal {
        Signal { t in
            var out: Float = 0
            for (s, w) in pairs {
                out += s(t) * w
            }
            return out
        }
    }

    /// Smooth crossfade between A and B, fade 0...1
    public static func crossfade(_ a: Signal, _ b: Signal, fade: Signal) -> Signal {
        Signal { t in
            let f = max(0, min(1, fade(t)))
            return a(t) * (1 - f) + b(t) * f
        }
    }
}
