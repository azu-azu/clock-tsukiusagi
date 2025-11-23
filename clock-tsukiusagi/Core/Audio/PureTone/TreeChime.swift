//
//  TreeChime.swift
//  clock-tsukiusagi
//
//  高周波メタリック粒で「シャラララ」生成（カスケードトリガー版）
//

import AVFoundation
import Foundation

private final class ChimeState {
    var isSuspended = false
    var time: Double = 0.0
    var lastTriggerTime: Double = -10.0  // 最後にシャラララを開始した時刻
}

public final class TreeChime: AudioSource {

    private let state = ChimeState()
    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    public init(
        grainRate: Double = 1.5,      // シャラララの発生頻度（1秒に何回）
        grainDuration: Double = 1.2,  // 各粒の余韻（長めに響く）
        brightness: Double = 8000.0   // 基音周波数
    ) {
        let sampleRate: Double = 48_000.0
        let twoPi = 2.0 * Double.pi

        let numGrains = 32  // 粒の数を増やして豊かな響き
        let cascadeInterval = 0.018  // 各粒の間隔を遅く（18ms）= 約55粒/秒

        var phases: [Double] = Array(repeating: 0, count: numGrains)
        var grainTimes: [Double] = Array(repeating: -1.0, count: numGrains)

        // 周波数を低→高に配置（グリッサンド効果）
        let freqs: [Double] = (0..<numGrains).map { i in
            let ratio = Double(i) / Double(numGrains - 1)  // 0.0 → 1.0
            return brightness * (0.8 + ratio * 0.6)  // 0.8x → 1.4x の範囲
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
                let currentTime = state.time
                state.time += 1.0 / sampleRate

                // シャラララ開始のトリガー判定
                let shouldTriggerCascade = drand48() < grainRate / sampleRate

                if shouldTriggerCascade && (currentTime - state.lastTriggerTime) > 1.0 {
                    // 新しいシャラララを開始
                    state.lastTriggerTime = currentTime
                }

                var value: Double = 0.0

                for i in 0..<numGrains {
                    // このグレインのトリガー時刻を計算
                    let grainTriggerTime = state.lastTriggerTime + Double(i) * cascadeInterval

                    // このフレームでこのグレインが開始すべきか？
                    if grainTimes[i] < 0.0 && currentTime >= grainTriggerTime && currentTime < grainTriggerTime + (1.0 / sampleRate) {
                        phases[i] = 0.0
                        grainTimes[i] = 0.0
                    }

                    // 粒が発音中の場合のみ処理
                    if grainTimes[i] >= 0.0 {
                        // 粒の減衰 (exponential decay)
                        let envelope = exp(-grainTimes[i] / grainDuration)

                        // メタリックな倍音（高周波サイン波）
                        value += sin(phases[i]) * envelope

                        phases[i] += twoPi * freqs[i] / sampleRate
                        grainTimes[i] += 1.0 / sampleRate

                        // 十分減衰したら停止（-60dB = 0.001）
                        if envelope < 0.001 {
                            grainTimes[i] = -1.0
                        }
                    }
                }

                samples?[frame] = Float(value * 0.06) // 粒が32個に増えたので音量控えめ
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
