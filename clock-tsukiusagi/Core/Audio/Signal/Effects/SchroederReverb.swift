//
//  SchroederReverb.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Professional Schroeder/Moorer reverb implementation
//

import Foundation

/// Schroeder/Moorer Reverb - Professional quality reverb for ambient sounds
///
/// Architecture:
/// ```
/// Input → [Parallel Comb Filters] → Sum → [Series All-pass Filters] → Output
/// ```
///
/// Features:
/// - 4 parallel comb filters (different delay times for density)
/// - 2 series all-pass filters (smooth frequency response)
/// - Predelay support (initial reflection delay)
/// - Damping control (high-frequency attenuation)
/// - Room size parameter (scales all delay times)
///
/// Mathematical Reference:
/// - Comb filter: y(n) = x(n) + g * y(n - M)
/// - All-pass filter: y(n) = -g * x(n) + x(n - M) + g * y(n - M)
///
/// Claude:
/// This is the reverb architecture recommended in the user's review.
/// It creates natural-sounding reverb suitable for ambient/meditation presets.
public final class SchroederReverb: AudioEffect, BlockAudioEffect {
    public init(
        roomSize: Float = 1.0,
        damping: Float = 0.5,
        decay: Float = 0.7,
        mix: Float = 0.3,
        predelay: Float = 0.02,
        sampleRate: Float = 48000
    ) {
        self.roomSize = roomSize
        self.damping = damping
        self.decay = decay
        self.mix = mix
        self.predelay = predelay
        self.sampleRate = sampleRate

        // Initialize comb filters
        combDelayTimes = Array(repeating: 0, count: combCount)
        combBuffers = []
        combReadPos = Array(repeating: 0, count: combCount)
        combWritePos = Array(repeating: 0, count: combCount)
        combGains = Array(repeating: decay, count: combCount)
        combDampStates = Array(repeating: 0, count: combCount)

        // Initialize all-pass filters
        allpassDelayTimes = Array(repeating: 0, count: allpassCount)
        allpassBuffers = []
        allpassReadPos = Array(repeating: 0, count: allpassCount)
        allpassWritePos = Array(repeating: 0, count: allpassCount)

        // Setup delay times and buffers
        updateDelayTimes()
        updatePredelaySize()
    }

    // MARK: - Parameters

    /// Room size (0.1 - 2.0), scales all delay times
    public var roomSize: Float {
        didSet {
            updateDelayTimes()
        }
    }

    /// Damping (0.0 - 1.0), high-frequency attenuation
    /// 0 = no damping, 1 = maximum damping
    public var damping: Float

    /// Reverb decay time (0.1 - 0.95)
    /// Lower = shorter reverb tail, Higher = longer reverb tail
    public var decay: Float

    /// Dry/Wet mix (0.0 - 1.0)
    /// 0 = fully dry, 1 = fully wet
    public var mix: Float

    /// Predelay in seconds (0 - 0.1)
    /// Simulates initial reflection delay
    public var predelay: Float {
        didSet {
            updatePredelaySize()
        }
    }

    // MARK: - Sample Rate

    private let sampleRate: Float

    // MARK: - Comb Filters (Parallel)

    /// Number of parallel comb filters
    private let combCount = 4

    /// Comb filter delay times in samples (different for each to avoid resonance)
    private var combDelayTimes: [Int] = []

    /// Comb filter delay buffers
    private var combBuffers: [[Float]] = []

    /// Comb filter read positions
    private var combReadPos: [Int] = []

    /// Comb filter write positions
    private var combWritePos: [Int] = []

    /// Comb filter feedback gain values
    private var combGains: [Float] = []

    /// Comb filter damping states (one-pole lowpass)
    private var combDampStates: [Float] = []

    // MARK: - All-pass Filters (Series)

    /// Number of series all-pass filters
    private let allpassCount = 2

    /// All-pass filter delay times in samples
    private var allpassDelayTimes: [Int] = []

    /// All-pass filter delay buffers
    private var allpassBuffers: [[Float]] = []

    /// All-pass filter read positions
    private var allpassReadPos: [Int] = []

    /// All-pass filter write positions
    private var allpassWritePos: [Int] = []

    /// All-pass filter gain (typically 0.5 for smooth response)
    private let allpassGain: Float = 0.5

    // MARK: - Predelay Buffer

    /// Predelay buffer
    private var predelayBuffer: [Float] = []

    /// Predelay write position
    private var predelayWritePos: Int = 0

    /// Predelay read position
    private var predelayReadPos: Int = 0

    /// Predelay size in samples
    private var predelaySize: Int = 0

    // MARK: - Initialization

    /// Create a Schroeder reverb
    /// - Parameters:
    ///   - roomSize: Room size multiplier (default: 1.0)
    ///   - damping: High-frequency damping (default: 0.5)
    ///   - decay: Reverb decay time (default: 0.7)
    ///   - mix: Dry/wet mix (default: 0.3)
    ///   - predelay: Predelay in seconds (default: 0.02 = 20ms)
    ///   - sampleRate: Sample rate in Hz (default: 48000)
    public init(
        roomSize: Float = 1.0,
        damping: Float = 0.5,
        decay: Float = 0.7,
        mix: Float = 0.3,
        predelay: Float = 0.02,
        sampleRate: Float = 48000
    ) {
        self.roomSize = roomSize
        self.damping = damping
        self.decay = decay
        self.mix = mix
        self.predelay = predelay
        self.sampleRate = sampleRate

        // Initialize comb filters
        combDelayTimes = Array(repeating: 0, count: combCount)
        combBuffers = []
        combReadPos = Array(repeating: 0, count: combCount)
        combWritePos = Array(repeating: 0, count: combCount)
        combGains = Array(repeating: decay, count: combCount)
        combDampStates = Array(repeating: 0, count: combCount)

        // Initialize all-pass filters
        allpassDelayTimes = Array(repeating: 0, count: allpassCount)
        allpassBuffers = []
        allpassReadPos = Array(repeating: 0, count: allpassCount)
        allpassWritePos = Array(repeating: 0, count: allpassCount)

        // Setup delay times and buffers
        updateDelayTimes()
        updatePredelaySize()
    }

    // MARK: - Delay Time Setup

    /// Update comb and all-pass delay times based on room size
    private func updateDelayTimes() {
        // Base delay times in milliseconds (tuned for natural reverb)
        // Prime numbers to avoid resonance
        let baseCombDelays: [Float] = [29.7, 37.1, 41.1, 43.7]
        let baseAllpassDelays: [Float] = [5.0, 1.7]

        // Update comb filters
        for i in 0..<combCount {
            let delayMs = baseCombDelays[i] * roomSize
            let delaySamples = Int(delayMs * sampleRate / 1000.0)
            combDelayTimes[i] = max(1, delaySamples)

            // Resize buffer if needed
            if i >= combBuffers.count {
                combBuffers.append(Array(repeating: 0, count: combDelayTimes[i]))
            } else if combBuffers[i].count != combDelayTimes[i] {
                combBuffers[i] = Array(repeating: 0, count: combDelayTimes[i])
            }

            // Reset positions
            combReadPos[i] = 0
            combWritePos[i] = 0
        }

        // Update all-pass filters
        for i in 0..<allpassCount {
            let delayMs = baseAllpassDelays[i] * roomSize
            let delaySamples = Int(delayMs * sampleRate / 1000.0)
            allpassDelayTimes[i] = max(1, delaySamples)

            // Resize buffer if needed
            if i >= allpassBuffers.count {
                allpassBuffers.append(Array(repeating: 0, count: allpassDelayTimes[i]))
            } else if allpassBuffers[i].count != allpassDelayTimes[i] {
                allpassBuffers[i] = Array(repeating: 0, count: allpassDelayTimes[i])
            }

            // Reset positions
            allpassReadPos[i] = 0
            allpassWritePos[i] = 0
        }
    }

    /// Update predelay buffer size
    private func updatePredelaySize() {
        let delaySamples = Int(predelay * sampleRate)
        predelaySize = max(1, delaySamples)
        predelayBuffer = Array(repeating: 0, count: predelaySize)
        predelayWritePos = 0
        predelayReadPos = 0
    }

    // MARK: - AudioEffect Protocol

    /// Process a single audio sample through the reverb
    /// - Parameters:
    ///   - input: Input sample
    ///   - time: Current time (unused)
    /// - Returns: Reverb output sample
    public func process(_ input: Float, time: Float) -> Float {
        // Step 1: Predelay
        let predelayed = processPredelay(input)

        // Step 2: Parallel comb filters
        var combSum: Float = 0
        for i in 0..<combCount {
            combSum += processComb(predelayed, filterIndex: i)
        }
        combSum /= Float(combCount)  // Average the comb outputs

        // Step 3: Series all-pass filters
        var allpassed = combSum
        for i in 0..<allpassCount {
            allpassed = processAllpass(allpassed, filterIndex: i)
        }

        // Step 4: Dry/wet mix
        let output = input * (1 - mix) + allpassed * mix

        return output
    }

    public func processBlock(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int,
        time: Float,
        sampleRate: Float
    ) {
        var t = time
        let dt = 1.0 / sampleRate
        for i in 0..<count {
            output[i] = process(input[i], time: t)
            t += dt
        }
    }

    /// Reset all reverb state
    public func reset() {
        // Clear all buffers
        for i in 0..<combCount {
            combBuffers[i] = Array(repeating: 0, count: combDelayTimes[i])
            combReadPos[i] = 0
            combWritePos[i] = 0
            combDampStates[i] = 0
        }

        for i in 0..<allpassCount {
            allpassBuffers[i] = Array(repeating: 0, count: allpassDelayTimes[i])
            allpassReadPos[i] = 0
            allpassWritePos[i] = 0
        }

        predelayBuffer = Array(repeating: 0, count: predelaySize)
        predelayWritePos = 0
        predelayReadPos = 0
    }

    // MARK: - Filter Processing

    /// Process predelay
    private func processPredelay(_ input: Float) -> Float {
        // Write input
        predelayBuffer[predelayWritePos] = input

        // Read delayed output
        let output = predelayBuffer[predelayReadPos]

        // Advance positions
        predelayWritePos = (predelayWritePos + 1) % predelaySize
        predelayReadPos = (predelayReadPos + 1) % predelaySize

        return output
    }

    /// Process a single comb filter with damping
    private func processComb(_ input: Float, filterIndex: Int) -> Float {
        let i = filterIndex

        // Read delayed sample
        let delayed = combBuffers[i][combReadPos[i]]

        // Apply damping (one-pole lowpass on feedback)
        let damped = delayed * (1 - damping) + combDampStates[i] * damping
        combDampStates[i] = damped

        // Comb filter equation: y(n) = x(n) + g * y(n - M)
        let output = input + combGains[i] * damped

        // Write output to buffer
        combBuffers[i][combWritePos[i]] = output

        // Advance positions
        combReadPos[i] = (combReadPos[i] + 1) % combDelayTimes[i]
        combWritePos[i] = (combWritePos[i] + 1) % combDelayTimes[i]

        return output
    }

    /// Process a single all-pass filter
    private func processAllpass(_ input: Float, filterIndex: Int) -> Float {
        let i = filterIndex

        // Read delayed sample
        let delayed = allpassBuffers[i][allpassReadPos[i]]

        // All-pass equation: y(n) = -g * x(n) + x(n - M) + g * y(n - M)
        let output = -allpassGain * input + delayed

        // Write to buffer: buffer stores x(n) + g * y(n)
        allpassBuffers[i][allpassWritePos[i]] = input + allpassGain * output

        // Advance positions
        allpassReadPos[i] = (allpassReadPos[i] + 1) % allpassDelayTimes[i]
        allpassWritePos[i] = (allpassWritePos[i] + 1) % allpassDelayTimes[i]

        return output
    }
}
