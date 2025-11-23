//
//  PureToneParams.swift
//  clock-tsukiusagi
//
//  Pure tone parameter structure for LunarPulse and similar sources
//

import Foundation

/// Parameters for pure tone generation (sine wave + LFO modulation)
public struct PureToneParams {
    public let frequency: Double
    public let amplitude: Float
    public let lfoFrequency: Double
    public let lfoMinimum: Double
    public let lfoMaximum: Double

    public init(
        frequency: Double,
        amplitude: Float,
        lfoFrequency: Double,
        lfoMinimum: Double,
        lfoMaximum: Double
    ) {
        self.frequency = frequency
        self.amplitude = amplitude
        self.lfoFrequency = lfoFrequency
        self.lfoMinimum = lfoMinimum
        self.lfoMaximum = lfoMaximum
    }
}
