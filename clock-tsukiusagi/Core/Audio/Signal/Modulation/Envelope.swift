//
//  Envelope.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Envelope generators for ambient synthesis
//

import Foundation

/// Envelope generators for ambient synthesis.
///
/// Claude:
/// All envelope types output a Signal: (time) -> Float.
/// They are sample-rate independent and based purely on time math.
public enum Envelope {

    // MARK: - ADSR (classic)

    public static func adsr(
        attack: Double,
        decay: Double,
        sustain: Float,
        release: Double,
        triggerTime: Double
    ) -> Signal {

        return Signal { t in
            let dt = Double(t) - triggerTime
            if dt < 0 { return 0 }

            // Attack
            if dt < attack {
                return Float(dt / attack)
            }

            // Decay
            if dt < attack + decay {
                let d = (dt - attack) / decay
                return Float(1 - (1 - Double(sustain)) * d)
            }

            // Sustain
            return sustain
        }
    }

    public static func release(
        from startValue: Float,
        releaseTime: Double,
        triggerTime: Double
    ) -> Signal {

        return Signal { t in
            let dt = Double(t) - triggerTime
            if dt < 0 { return startValue }
            let v = startValue * Float(max(0, 1 - dt / releaseTime))
            return v
        }
    }

    // MARK: - Slow envelope (Ambient fade, tides, breathing)

    /// Smooth long fade between 0 and 1 using an exponential curve.
    /// Perfect for waves, moon tides, deep pressure.
    public static func slow(
        rise: Double,
        fall: Double,
        cycle: Double
    ) -> Signal {

        return Signal { t in
            let p = fmod(Double(t), cycle) / cycle  // 0..1

            if p < rise / cycle {
                return Float(p / (rise / cycle))
            } else {
                let d = (p - rise / cycle) / (fall / cycle)
                return Float(max(0, 1 - d))
            }
        }
    }

    // MARK: - Pulse smoothing (for heartbeat / train rhythm)

    public static func pulseSmoothing(
        sharpPulse: Signal,
        amount: Float = 0.1
    ) -> Signal {
        var last: Float = 0
        return Signal { t in
            let x = sharpPulse(t)
            last += amount * (x - last)
            return last
        }
    }
}
