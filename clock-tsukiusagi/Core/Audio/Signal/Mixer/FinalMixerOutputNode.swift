//
//  FinalMixerOutputNode.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-18.
//  SignalEngine: Bridge FinalMixer to AVAudioEngine via AudioSource protocol
//

import AVFoundation

/// Wraps FinalMixer into an AudioSource-compatible node for LocalAudioEngine.
///
/// Architecture:
/// ```
/// FinalMixer → FinalMixerOutputNode → AVAudioSourceNode → LocalAudioEngine
/// ```
///
/// Claude:
/// This is similar to SignalAudioSource but wraps a FinalMixer instead of a single Signal.
/// It handles:
/// - Sample-rate conversion (time-based → sample-based)
/// - Volume control
/// - Fade envelope support
/// - AVAudioEngine integration
public final class FinalMixerOutputNode: AudioSource {

    // MARK: - State

    /// Internal state holder for render callback
    private class State {
        var time: Float = 0
        var sampleRate: Float = 48000
        var volume: Float = 1.0
        let mixer: FinalMixer
        var fadeEnvelope: Signal?  // Optional fade envelope (0..1)

        init(mixer: FinalMixer) {
            self.mixer = mixer
            self.fadeEnvelope = nil
        }
    }

    private let state: State
    private let _sourceNode: AVAudioSourceNode

    // MARK: - AudioSource Protocol

    public var sourceNode: AVAudioNode {
        return _sourceNode
    }

    // MARK: - Initialization

    /// Create a new FinalMixerOutputNode wrapping a FinalMixer
    /// - Parameter mixer: The FinalMixer to wrap
    public init(mixer: FinalMixer) {
        self.state = State(mixer: mixer)

        // Create AVAudioSourceNode with render callback
        self._sourceNode = AVAudioSourceNode { [state] _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                // Get mixed + processed output from FinalMixer
                var value = state.mixer.output(time: state.time) * state.volume

                // Apply fade envelope if active
                if let fadeEnvelope = state.fadeEnvelope {
                    value *= fadeEnvelope(state.time)
                }

                // Advance time
                state.time += 1.0 / state.sampleRate

                // Write to all channels (mono signal to stereo output)
                for buffer in ablPointer {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = value
                }
            }
            return noErr
        }
    }

    // MARK: - AudioSource Protocol Implementation

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        state.sampleRate = Float(format.sampleRate)
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }

    public func start() throws {
        // Reset time on start to ensure clean playback
        state.time = 0
    }

    public func stop() {
        // Signal-based sources have no explicit stop action
    }

    public func suspend() {
        // No timers to suspend in Signal-based sources
    }

    public func resume() {
        // No timers to resume in Signal-based sources
    }

    public func setVolume(_ volume: Float) {
        state.volume = max(0, min(1, volume))
    }

    // MARK: - Fade Control

    /// Apply fade in envelope starting from current time
    /// - Parameter durationMs: Fade duration in milliseconds (default: 300ms)
    public func applyFadeIn(durationMs: Int = 300) {
        let duration = Double(durationMs) / 1000.0
        let startTime = Double(state.time)
        state.fadeEnvelope = Envelope.fadeIn(duration: duration, startTime: startTime)
    }

    /// Apply fade out envelope starting from current time
    /// - Parameter durationMs: Fade duration in milliseconds (default: 300ms)
    public func applyFadeOut(durationMs: Int = 300) {
        let duration = Double(durationMs) / 1000.0
        let startTime = Double(state.time)
        state.fadeEnvelope = Envelope.fadeOut(duration: duration, startTime: startTime)
    }

    /// Clear any active fade envelope (return to full volume)
    public func clearFade() {
        state.fadeEnvelope = nil
    }

    // MARK: - Mixer Access

    /// Access the underlying FinalMixer for adding signals/effects
    /// - Returns: The FinalMixer instance
    public func getMixer() -> FinalMixer {
        return state.mixer
    }
}
