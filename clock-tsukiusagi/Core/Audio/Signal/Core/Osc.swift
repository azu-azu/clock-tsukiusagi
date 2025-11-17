//
//  Osc.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Core oscillator functions for ambient synthesis
//

import Foundation

/// Core oscillator functions for ambient synthesis.
/// Each oscillator returns a Signal: (Double time) -> Float.
///
/// Claude:
/// These oscillators are phase-accumulating and sample-rate independent.
/// You can layer them with Mix and modulate with LFO to build evolving textures.
public enum Osc {

    /// --- Phase accumulator shared by oscillators ---
    private class PhaseBox {
        var phase: Double = 0
    }

    /// Sine oscillator
    public static func sine(frequency: Double) -> Signal {
        let box = PhaseBox()
        return Signal { t in
            let dt = Double(t) - (box.phase.truncatingRemainder(dividingBy: 1) / frequency)
            box.phase += frequency * dt
            box.phase = box.phase.truncatingRemainder(dividingBy: 1)
            return sin(Float(box.phase * 2 * .pi))
        }
    }

    /// Triangle wave
    public static func triangle(frequency: Double) -> Signal {
        let box = PhaseBox()
        return Signal { t in
            let dt = Double(t) - (box.phase.truncatingRemainder(dividingBy: 1) / frequency)
            box.phase += frequency * dt
            let p = box.phase.truncatingRemainder(dividingBy: 1)
            return Float(2 * abs(2 * p - 1) - 1)
        }
    }

    /// Saw wave (ramp up)
    public static func sawUp(frequency: Double) -> Signal {
        let box = PhaseBox()
        return Signal { t in
            let dt = Double(t) - (box.phase.truncatingRemainder(dividingBy: 1) / frequency)
            box.phase += frequency * dt
            return Float((box.phase - floor(box.phase)) * 2 - 1)
        }
    }

    /// Saw wave (ramp down)
    public static func sawDown(frequency: Double) -> Signal {
        let box = PhaseBox()
        return Signal { t in
            let dt = Double(t) - (box.phase.truncatingRemainder(dividingBy: 1) / frequency)
            box.phase += frequency * dt
            let ph = box.phase - floor(box.phase)
            return Float((1 - ph) * 2 - 1)
        }
    }

    /// Square wave (with optional smoothing)
    public static func square(
        frequency: Double,
        smooth: Bool = true,
        smoothAmount: Float = 0.05
    ) -> Signal {
        let box = PhaseBox()
        return Signal { t in
            let dt = Double(t) - (box.phase.truncatingRemainder(dividingBy: 1) / frequency)
            box.phase += frequency * dt
            let raw = (box.phase.truncatingRemainder(dividingBy: 1) < 0.5) ? 1.0 : -1.0

            if !smooth { return Float(raw) }

            // Smooth edges
            return Float(raw) * (1 - smoothAmount) + Float.random(in: -smoothAmount...smoothAmount)
        }
    }

    /// Multi-oscillator (detuned ensemble)
    public static func detuned(
        baseFrequency: Double,
        count: Int,
        detuneCents: Double
    ) -> Signal {
        let oscillators = (0..<count).map { i -> Signal in
            let detune = pow(2, ((Double(i) - Double(count)/2) * detuneCents) / 1200)
            return sine(frequency: baseFrequency * detune)
        }

        // Sum all oscillators
        return Signal { t in
            var sum: Float = 0
            for osc in oscillators {
                sum += osc(t)
            }
            return sum / Float(count)  // Normalize
        }
    }
}
