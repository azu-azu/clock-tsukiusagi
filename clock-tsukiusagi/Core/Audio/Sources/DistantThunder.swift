//
//  DistantThunder.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  遠雷音源（ブラウンノイズ + ランダムパルス）
//

import AVFoundation
import Foundation

private final class AudioState {
    var isSuspended = false
}

/// 遠雷音源（簡略版：低域パルスは未実装、ランダム振幅変動で表現）
public final class DistantThunder: AudioSource {
    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }
    private let audioState = AudioState()

    public init(
        noiseAmplitude: Double = 0.15,
        pulseAmplitude: Double = 0.08,
        pulseMinInterval: Double = 2.0,
        pulseMaxInterval: Double = 7.0
    ) {
        let localNoiseAmp = noiseAmplitude
        let localPulseAmp = pulseAmplitude
        let localMinInterval = pulseMinInterval
        let localMaxInterval = pulseMaxInterval

        let noiseGen = NoiseGenerator(type: .brown)
        var pulseTimer: Double = 0.0
        var nextPulseTime: Double = Double.random(in: localMinInterval...localMaxInterval)
        var pulseActive = false
        var pulseDecay: Float = 0.0
        let state = audioState

        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            if state.isSuspended {
                for buffer in abl {
                    memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }

            guard let buffer = abl.first else { return noErr }
            let samples = buffer.mData?.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                let noiseSample = Float(noiseGen.generate())
                let timeStep = 1.0 / 48000.0
                pulseTimer += timeStep

                if pulseTimer >= nextPulseTime {
                    pulseActive = true
                    pulseDecay = 1.0
                    pulseTimer = 0.0
                    nextPulseTime = Double.random(in: localMinInterval...localMaxInterval)
                }

                if pulseActive {
                    pulseDecay *= 0.9999  // Slow decay
                    if pulseDecay < 0.01 {
                        pulseActive = false
                    }
                }

                let amplitude = Float(localNoiseAmp) + (pulseActive ? Float(localPulseAmp) * pulseDecay : 0.0)
                samples?[frame] = noiseSample * amplitude
            }
            return noErr
        }
    }

    public func start() throws {}
    public func stop() {}
    public func suspend() { audioState.isSuspended = true }
    public func resume() { audioState.isSuspended = false }
    public func setVolume(_ volume: Float) {}
}
