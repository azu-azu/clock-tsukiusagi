//
//  CascadeFilter.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-19.
//  SignalEngine: 24dB/Oct filter using cascaded SVF stages
//

import Foundation

/// CascadeFilter: Two-stage SVF for steeper roll-off (approx. 24dB/Oct)
public final class CascadeFilter: AudioEffect {

    public enum FilterType {
        case lowpass
        case highpass
        case bandpass
    }

    private var stage1: StateVariableFilter
    private var stage2: StateVariableFilter

    // MARK: - Initialization

    /// Create a cascaded SVF filter
    /// - Parameters:
    ///   - type: Filter type
    ///   - cutoff: Cutoff frequency in Hz
    ///   - resonance: Q-factor
    ///   - sampleRate: Sample rate in Hz
    public init(
        type: FilterType = .lowpass,
        cutoff: Float = 1000,
        resonance: Float = 0.707,
        sampleRate: Float = 48000
    ) {
        stage1 = StateVariableFilter(
            type: Self.mapType(type),
            cutoff: cutoff,
            resonance: resonance,
            sampleRate: sampleRate
        )
        stage2 = StateVariableFilter(
            type: Self.mapType(type),
            cutoff: cutoff,
            resonance: resonance,
            sampleRate: sampleRate
        )
    }

    // MARK: - AudioEffect

    public func process(_ input: Float, time: Float) -> Float {
        let first = stage1.process(input, time: time)
        return stage2.process(first, time: time)
    }

    public func reset() {
        stage1.reset()
        stage2.reset()
    }

    // MARK: - Helpers

    /// Update cutoff frequency for both stages
    public func setCutoff(_ cutoff: Float) {
        stage1.cutoffFrequency = cutoff
        stage2.cutoffFrequency = cutoff
    }

    /// Update resonance for both stages
    public func setResonance(_ resonance: Float) {
        stage1.resonance = resonance
        stage2.resonance = resonance
    }

    /// Update sample rate for both stages
    public func setSampleRate(_ sampleRate: Float) {
        stage1.setSampleRate(sampleRate)
        stage2.setSampleRate(sampleRate)
    }

    private static func mapType(_ type: FilterType) -> StateVariableFilter.FilterType {
        switch type {
        case .lowpass:
            return .lowpass
        case .highpass:
            return .highpass
        case .bandpass:
            return .bandpass
        }
    }
}
