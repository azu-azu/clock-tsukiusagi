//
//  StardustNoise.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  星屑ノイズ音源（ホワイトノイズ + 微細パルス）
//

import AVFoundation
import Foundation

private final class AudioState {
    var isSuspended = false
}

/// 星屑ノイズ音源（簡略版：バンドパスフィルタは未実装）
public final class StardustNoise: AudioSource {
    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }
    private let audioState = AudioState()

    public init(
        microBurstAmplitude: Double = 0.12,
        microBurstMinInterval: Double = 0.4,
        microBurstMaxInterval: Double = 1.2
    ) {
        let localAmp = microBurstAmplitude
        let localMinInterval = microBurstMinInterval
        let localMaxInterval = microBurstMaxInterval

        let noiseGen = NoiseGenerator(type: .white)
        var burstTimer: Double = 0.0
        var nextBurstTime: Double = Double.random(in: localMinInterval...localMaxInterval)
        var burstActive = false
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

                // Micro burst logic
                let timeStep = 1.0 / 48000.0
                burstTimer += timeStep

                if burstTimer >= nextBurstTime {
                    burstActive = !burstActive
                    burstTimer = 0.0
                    nextBurstTime = Double.random(in: localMinInterval...localMaxInterval)
                }

                let amplitude = burstActive ? Float(localAmp) : Float(localAmp * 0.3)
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
