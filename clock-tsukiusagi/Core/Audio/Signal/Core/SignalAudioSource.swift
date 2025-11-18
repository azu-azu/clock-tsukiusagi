//
//  SignalAudioSource.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  SignalEngine: Wrapper to convert Signal into AudioSource
//

import AVFoundation

/// Wrap a Signal into an AudioSource-compatible node.
/// This does not modify LocalAudioEngine.
///
/// Claude: This bridges the time-based Signal world
/// with the sample-based AVAudioEngine world.
public final class SignalAudioSource: AudioSource {

    // State holder for callback
    private class State {
        var time: Float = 0
        var sampleRate: Float = 48000
        var volume: Float = 1.0
        let signal: Signal
        var fadeEnvelope: Signal?  // Optional fade envelope (0..1)

        init(signal: Signal) {
            self.signal = signal
            self.fadeEnvelope = nil
        }
    }

    private let state: State
    private let _sourceNode: AVAudioSourceNode

    public var sourceNode: AVAudioNode {
        return _sourceNode
    }

    public init(signal: Signal) {
        self.state = State(signal: signal)

        self._sourceNode = AVAudioSourceNode { [state] _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                var value = state.signal(state.time) * state.volume

                // Apply fade envelope if active
                if let fadeEnvelope = state.fadeEnvelope {
                    value *= fadeEnvelope(state.time)
                }

                state.time += 1.0 / state.sampleRate

                for buffer in ablPointer {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = value
                }
            }
            return noErr
        }
    }

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
}
