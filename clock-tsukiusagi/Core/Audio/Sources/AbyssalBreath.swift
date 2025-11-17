//
//  AbyssalBreath.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-17.
//  深海の呼吸音源（ブラウンノイズ + 超低域サイン + LFO）
//

import AVFoundation
import Foundation

private final class AudioState {
    var isSuspended = false
}

/// 深海の呼吸音源
public final class AbyssalBreath: AudioSource {
    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }
    private let audioState = AudioState()

    public init(
        noiseAmplitude: Double = 0.10,
        subSineFrequency: Double = 48.0,
        subSineAmplitude: Double = 0.03,
        lfoFrequency: Double = 0.05,
        lfoDepth: Double = 0.25
    ) {
        let localNoiseAmp = noiseAmplitude
        let localSubFreq = subSineFrequency
        let localSubAmp = subSineAmplitude
        let localLFOFreq = lfoFrequency
        let localLFODepth = lfoDepth
        let twoPi = 2.0 * Double.pi
        let sampleRate: Double = 48000.0

        let noiseGen = NoiseGenerator(type: .brown)
        var subPhase: Double = 0.0
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
                let subSine = sin(subPhase)
                let lfoValue = sin(lfoPhase)
                let lfoMod = 1.0 - (localLFODepth * (1.0 - lfoValue) / 2.0)

                let noisePart = noiseSample * Float(localNoiseAmp)
                let subPart = Float(subSine * localSubAmp)
                samples?[frame] = (noisePart + subPart) * Float(lfoMod)

                subPhase += twoPi * localSubFreq / sampleRate
                if subPhase >= twoPi { subPhase -= twoPi }
                lfoPhase += twoPi * localLFOFreq / sampleRate
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
