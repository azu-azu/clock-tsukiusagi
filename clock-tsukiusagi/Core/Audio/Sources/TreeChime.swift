//
//  TreeChime.swift
//  clock-tsukiusagi
//
//  高周波メタリック粒で「シャラララ」生成
//

import AVFoundation
import Foundation

private final class ChimeState {
    var isSuspended = false
    var time: Double = 0.0
}

public final class TreeChime: AudioSource {

    private let state = ChimeState()
    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    public init(
        grainRate: Double = 45.0,     // 1秒にどれだけ「粒」を鳴らすか
        grainDuration: Double = 0.08, // 粒の余韻
        brightness: Double = 8000.0   // High-pass の中心
    ) {
        let sampleRate: Double = 48_000.0
        let twoPi = 2.0 * Double.pi

        var phases: [Double] = Array(repeating: 0, count: 16)
        let freqs: [Double] = (0..<16).map { i in
            brightness * (1.0 + Double(i) * 0.12) // 高周波を複数散らす
        }

        let state = self.state

        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            if state.isSuspended {
                for b in abl { memset(b.mData, 0, Int(b.mDataByteSize)) }
                return noErr
            }

            guard let buffer = abl.first else { return noErr }
            let samples = buffer.mData?.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                state.time += 1.0 / sampleRate

                // ランダムで「粒」をトリガー
                let trigger = drand48() < grainRate / sampleRate

                var value: Double = 0.0

                for i in 0..<phases.count {
                    // 粒がトリガーされたとき → 余韻をスタート
                    if trigger {
                        phases[i] = 0.0
                    }

                    // 粒の減衰 (exponential decay)
                    let envelope = exp(-phases[i] / grainDuration)

                    // metallic noise (high harmonics)
                    value += sin(phases[i]) * envelope

                    phases[i] += twoPi * freqs[i] / sampleRate
                }

                samples?[frame] = Float(value * 0.05) // 音量は控えめ
            }

            return noErr
        }
    }

    public func suspend() { state.isSuspended = true }
    public func resume()  { state.isSuspended = false }

    public func start() throws {}
    public func stop() {}
    public func setVolume(_ volume: Float) {}
}
