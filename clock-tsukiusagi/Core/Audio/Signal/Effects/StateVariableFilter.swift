//
//  StateVariableFilter.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: TPT (Topology-Preserving Transform) State Variable Filter
//

import Foundation

/// State Variable Filter (SVF) - TPT implementation for numerical stability
///
/// Features:
/// - Lowpass, Highpass, Bandpass modes
/// - Resonance (Q-factor) control for frequency response shaping
/// - Unconditionally stable at all frequencies (TPT topology)
/// - Proper frequency response without limiting artifacts
///
/// Mathematical Reference:
/// TPT-SVF uses trapezoidal integration with topology-preserving transform.
/// The key difference from Chamberlin SVF is the g1 coefficient that ensures
/// numerical stability at all frequencies, even when g >> 1.
///
/// Reference: Vadim Zavalishin, "The Art of VA Filter Design"
public final class StateVariableFilter: AudioEffect {

    // MARK: - Filter Type

    public enum FilterType {
        case lowpass
        case highpass
        case bandpass
    }

    // MARK: - Parameters

    /// Filter type (lowpass, highpass, bandpass)
    public var filterType: FilterType

    /// Cutoff frequency in Hz (20 - 20000)
    public var cutoffFrequency: Float {
        didSet { updateCoefficients() }
    }

    /// Resonance / Q-factor (0.5 - 10.0)
    /// Higher Q = sharper peak at cutoff
    public var resonance: Float {
        didSet { updateCoefficients() }
    }

    /// Sample rate in Hz
    private var sampleRate: Float

    // MARK: - Internal State

    /// TPT filter states
    private var z1: Float = 0  // Integrator 1 state
    private var z2: Float = 0  // Integrator 2 state

    // MARK: - Coefficients

    /// TPT frequency coefficient
    private var g: Float = 0

    /// Damping coefficient (related to Q)
    private var k: Float = 0

    /// TPT stability coefficient (this is the key to numerical stability)
    private var g1: Float = 0

    // MARK: - Initialization

    /// Create a TPT State Variable Filter
    /// - Parameters:
    ///   - type: Filter type (lowpass, highpass, bandpass)
    ///   - cutoff: Cutoff frequency in Hz (default: 1000 Hz)
    ///   - resonance: Q-factor (default: 0.707 = Butterworth response)
    ///   - sampleRate: Sample rate in Hz (default: 48000)
    public init(
        type: FilterType = .lowpass,
        cutoff: Float = 1000,
        resonance: Float = 0.707,
        sampleRate: Float = 48000
    ) {
        self.filterType = type
        self.cutoffFrequency = cutoff
        self.resonance = resonance
        self.sampleRate = sampleRate
        updateCoefficients()
    }

    // MARK: - Coefficient Calculation

    /// Update TPT filter coefficients
    private func updateCoefficients() {
        // Clamp parameters to safe ranges
        let fc = max(20, min(cutoffFrequency, sampleRate * 0.49))
        let Q = max(0.5, min(resonance, 10.0))

        // TPT coefficient calculation (simplified bilinear transform)
        g = tan(Float.pi * fc / sampleRate)

        // Damping from Q factor
        k = 1.0 / Q

        // TPT stability coefficient - this is what makes it unconditionally stable
        // Without this, the filter will diverge at high frequencies
        g1 = 1.0 / (1.0 + g * (g + k))
    }

    // MARK: - AudioEffect Protocol

    /// Process a single audio sample through the TPT-SVF
    /// - Parameters:
    ///   - input: Input sample
    ///   - time: Current time (unused for SVF)
    /// - Returns: Filtered output sample
    public func process(_ input: Float, time: Float) -> Float {
        // TPT-SVF equations (trapezoidal integration)
        // v3: highpass output
        // v1: bandpass output
        // v2: lowpass output

        let v3 = (input - z1 - k * z2) * g1
        let v1 = g * v3 + z2
        let v2 = g * v1 + z1

        // Update states
        z1 = v2
        z2 = v1

        // Return appropriate output based on filter type
        switch filterType {
        case .lowpass:
            return v2
        case .highpass:
            return v3
        case .bandpass:
            return v1
        }
    }

    /// Reset filter state
    public func reset() {
        z1 = 0
        z2 = 0
    }

    // MARK: - Convenience Methods

    /// Update sample rate (call when audio format changes)
    /// - Parameter sampleRate: New sample rate in Hz
    public func setSampleRate(_ sampleRate: Float) {
        self.sampleRate = sampleRate
        updateCoefficients()
    }
}
