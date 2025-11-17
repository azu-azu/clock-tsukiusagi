//
//  SilentLibrary.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  夜の図書館音源（ブラウンノイズ + 静止LFO）
//

import AVFoundation
import Foundation

private final class AudioState {
    var isSuspended = false
}

/// 夜の図書館音源（簡略版：帯域強調フィルタは未実装）
public final class SilentLibrary: AudioSource {
    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }
    private let audioState = AudioState()

    public init(
        noiseAmplitude: Double = 0.10,
        lfoFrequency: Double = 0.01,
        lfoDepth: Double = 0.03
    ) {
        let localNoiseAmp = noiseAmplitude
        let localLFOFreq = lfoFrequency
        let localLFODepth = lfoDepth
        let twoPi = 2.0 * Double.pi

        let noiseGen = NoiseGenerator(type: .brown)
        var lfoPhase: Double = 0.0
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
                let lfoValue = sin(lfoPhase)
                let lfoMod = 1.0 - (localLFODepth * (1.0 - lfoValue) / 2.0)

                samples?[frame] = noiseSample * Float(localNoiseAmp * lfoMod)

                lfoPhase += twoPi * localLFOFreq / 48000.0
                if lfoPhase >= twoPi { lfoPhase -= twoPi }
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
