//
//  SoftLimiter.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-19.
//  SignalEngine: Gentle soft limiter for peak control
//

import Foundation

/// SoftLimiter: Simple tanh-based limiter to tame peaks without harsh clipping
public final class SoftLimiter: AudioEffect {

    /// Drive amount applied before limiting (1.0 = unity)
    public var drive: Float {
        didSet {
            drive = max(0.5, min(drive, 4.0))
            driveNorm = SoftLimiter.normalization(for: drive)
        }
    }

    /// Output ceiling (safety clamp after limiting)
    public var ceiling: Float {
        didSet {
            ceiling = max(0.5, min(ceiling, 1.0))
        }
    }

    private var driveNorm: Float

    public init(drive: Float = 1.2, ceiling: Float = 0.98) {
        self.drive = max(0.5, min(drive, 4.0))
        self.ceiling = max(0.5, min(ceiling, 1.0))
        self.driveNorm = SoftLimiter.normalization(for: self.drive)
    }

    public func process(_ input: Float, time: Float) -> Float {
        // Apply soft saturation then normalize to preserve approximate unity gain
        let driven = input * drive
        let limited = tanh(driven)
        let normalized = driveNorm != 0 ? (limited / driveNorm) : limited
        // Final ceiling clamp for safety
        return max(-ceiling, min(ceiling, normalized))
    }

    public func reset() {
        // Stateless limiter
    }

    private static func normalization(for drive: Float) -> Float {
        return tanh(drive)
    }
}
