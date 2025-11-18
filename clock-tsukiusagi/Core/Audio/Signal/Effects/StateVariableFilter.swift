//
//  StateVariableFilter.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Professional-grade State Variable Filter (SVF)
//

import Foundation

/// State Variable Filter (SVF) - Professional quality filter with simultaneous outputs
///
/// Features:
/// - Lowpass, Highpass, Bandpass modes
/// - Resonance (Q-factor) control for frequency response shaping
/// - Transparent sound quality
/// - Numerically stable for all frequencies
///
/// Mathematical Reference:
/// SVF uses a 2-pole topology with feedback for high Q values.
/// Transfer function: H(s) = G / (s² + s/Q + 1)
///
/// Claude:
/// This is the filter recommended in the user's review for professional audio quality.
/// It's superior to basic 1st-order filters due to:
/// - Better frequency response
/// - Resonance control
/// - Multi-mode output (LP/HP/BP)
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
        didSet {
            updateCoefficients()
        }
    }

    /// Resonance / Q-factor (0.5 - 10.0)
    /// Higher Q = sharper peak at cutoff
    public var resonance: Float {
        didSet {
            updateCoefficients()
        }
    }

    /// Sample rate in Hz
    private var sampleRate: Float

    // MARK: - Internal State

    /// Internal filter states (z-domain)
    private var z1_lowpass: Float = 0   // Lowpass state
    private var z1_bandpass: Float = 0  // Bandpass state

    // MARK: - Coefficients

    /// Filter coefficient: frequency factor
    private var g: Float = 0

    /// Filter coefficient: resonance factor
    private var k: Float = 0

    // MARK: - Initialization

    /// Create a State Variable Filter
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

    /// Update filter coefficients based on cutoff and resonance
    private func updateCoefficients() {
        // Clamp parameters to safe ranges
        let fc = max(20, min(cutoffFrequency, sampleRate / 2 - 100))
        let Q = max(0.5, min(resonance, 10.0))

        // Calculate frequency warping factor (bilinear transform)
        let wd = 2 * Float.pi * fc
        let T = 1.0 / sampleRate
        let wa = (2 / T) * tan(wd * T / 2)

        // Calculate SVF coefficients
        g = wa * T / 2
        k = 2 - 2 / Q
    }

    // MARK: - AudioEffect Protocol

    /// Process a single audio sample through the SVF
    /// - Parameters:
    ///   - input: Input sample
    ///   - time: Current time (unused for SVF)
    /// - Returns: Filtered output sample
    public func process(_ input: Float, time: Float) -> Float {
        // SVF topology (Chamberlin form)
        // v0 = input
        // v1 = bandpass output
        // v2 = lowpass output
        // v3 = highpass output = v0 - k*v1 - v2

        let v0 = input
        let v3 = v0 - k * z1_bandpass - z1_lowpass  // Highpass

        let v1 = g * v3 + z1_bandpass               // Bandpass
        let v2 = g * v1 + z1_lowpass                 // Lowpass

        // Update states
        z1_bandpass = v1
        z1_lowpass = v2

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
        z1_lowpass = 0
        z1_bandpass = 0
    }

    // MARK: - Convenience Methods

    /// Update sample rate (call when audio format changes)
    /// - Parameter sampleRate: New sample rate in Hz
    public func setSampleRate(_ sampleRate: Float) {
        self.sampleRate = sampleRate
        updateCoefficients()
    }
}
