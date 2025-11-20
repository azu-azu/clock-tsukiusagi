//
//  SignalLFO.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Low Frequency Oscillators for ambient modulation
//

import Foundation

/// SignalLFO (Low Frequency Oscillators for SignalEngine)
/// These are slow modulators used to add motion to ambient textures.
///
/// Claude:
/// All LFOs output a Signal: (Double time) -> Float
/// They are sample-rate independent and designed for slow natural movement.
public enum SignalLFO {

    // Shared phase accumulator
    private class PhaseBox {
        var phase: Double = 0
        var lastTime: Double? = nil
    }

    /// Smooth sine LFO (most important for ambient)
    public static func sine(frequency: Double) -> Signal {
        let box = PhaseBox()
        return Signal { t in
            let time = Double(t)
            let dt: Double
            if let last = box.lastTime {
                dt = time - last
            } else {
                dt = 0  // First call: no time delta
            }
            box.lastTime = time

            box.phase += frequency * dt
            let p = box.phase.truncatingRemainder(dividingBy: 1)
            return sin(Float(2 * .pi * p))
        }
    }

    /// Triangle LFO (useful for waves and swells)
    public static func triangle(frequency: Double) -> Signal {
        let box = PhaseBox()
        return Signal { t in
            let time = Double(t)
            let dt: Double
            if let last = box.lastTime {
                dt = time - last
            } else {
                dt = 0
            }
            box.lastTime = time

            box.phase += frequency * dt
            let p = box.phase.truncatingRemainder(dividingBy: 1)
            return Float(2 * abs(2 * p - 1) - 1)
        }
    }

    /// Random LFO (smooth random wandering)
    public static func random(smoothing: Float = 0.02) -> Signal {
        var last: Float = 0
        return Signal { _ in
            let r = Float.random(in: -1...1)
            last = last + smoothing * (r - last)
            return last
        }
    }

    /// Drift (very slow evolving offset)
    /// Ideal for deep-sea pressure or moon-based ambient motion.
    public static func drift(rate: Float = 0.001) -> Signal {
        var drift: Float = 0
        return Signal { _ in
            let change = Float.random(in: -rate...rate)
            drift = max(min(drift + change, 1), -1)
            return drift
        }
    }

    /// Combine multiple LFOs by summing
    public static func combine(_ list: [Signal]) -> Signal {
        Signal { t in
            var sum: Float = 0
            for sig in list {
                sum += sig(t)
            }
            return sum / Float(list.count)  // Normalize
        }
    }
}
