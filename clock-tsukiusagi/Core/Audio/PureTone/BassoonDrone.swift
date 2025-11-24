//
//  BassoonDrone.swift
//  clock-tsukiusagi
//
//  Deep bassoon-like drone with rich harmonics
//  Creates random "bwooom" resonances in low frequency range
//

import AVFoundation
import Foundation

private final class BassoonState {
    var isSuspended = false
    var time: Double = 0.0
    var lastTriggerTime: Double = -10.0  // 最後にバスーンを鳴らした時刻
    var currentDroneTime: Double = -1.0  // 現在のドローンの経過時間（-1 = 発音中でない）
}

/// BassoonDrone - Low frequency drone with bassoon-like timbre
///
/// Generates random "bwooom" bass resonances with rich harmonic content.
/// Characteristics:
/// - Low fundamental frequency (50-200Hz range)
/// - Slow attack, long decay
/// - Rich odd harmonics for woody, reedy timbre
/// - Random triggering with configurable rate
public final class BassoonDrone: AudioSource {

    private let state = BassoonState()
    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    /// Initialize BassoonDrone
    /// - Parameters:
    ///   - droneRate: Frequency of drone triggers (per second)
    ///   - droneDuration: Duration of each drone resonance (seconds)
    ///   - fundamental: Base frequency (Hz) - typical bassoon range 50-200Hz
    public init(
        droneRate: Double = 0.08,      // ~1回/12秒（控えめ）
        droneDuration: Double = 4.0,   // 4秒の長い余韻
        fundamental: Double = 80.0     // 基音80Hz（低いE）
    ) {
        print("🎺 BassoonDrone initialized: rate=\(droneRate), duration=\(droneDuration), fundamental=\(fundamental)")  // ✂️ デバッグ用
        let sampleRate: Double = 48_000.0
        let twoPi = 2.0 * Double.pi

        // バスーンの倍音構造（奇数倍音が強い）
        let harmonics: [Double] = [1.0, 3.0, 5.0, 7.0, 9.0]
        let harmonicAmps: [Double] = [1.0, 0.5, 0.3, 0.15, 0.08]

        var phases: [Double] = Array(repeating: 0, count: harmonics.count)

        let attack: Double = 0.3      // 300ms ゆっくりしたアタック
        let decay: Double = droneDuration - attack  // 残りは減衰

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

                // ドローン開始のトリガー判定
                let shouldTriggerDrone = drand48() < droneRate / sampleRate

                if shouldTriggerDrone && (currentTime - state.lastTriggerTime) > droneDuration {
                    // 新しいドローンを開始
                    print("🎺 Bassoon triggered at t=\(currentTime)")  // ✂️ デバッグ用
                    state.lastTriggerTime = currentTime
                    state.currentDroneTime = 0.0
                }

                // ドローンが発音中の場合のみ処理
                var value: Double = 0.0

                if state.currentDroneTime >= 0.0 && state.currentDroneTime < droneDuration {
                    // エンベロープ計算
                    let envelope: Double
                    if state.currentDroneTime < attack {
                        // アタックフェーズ（緩やかな立ち上がり）
                        let attackProgress = state.currentDroneTime / attack
                        envelope = attackProgress * attackProgress  // 二次曲線でゆっくり
                    } else {
                        // ディケイフェーズ（指数減衰）
                        let decayTime = state.currentDroneTime - attack
                        envelope = exp(-decayTime / decay)
                    }

                    // 倍音を重ねてバスーンの音色を生成
                    for i in 0..<harmonics.count {
                        let freq = fundamental * harmonics[i]
                        value += sin(phases[i]) * harmonicAmps[i] * envelope

                        phases[i] += twoPi * freq / sampleRate
                        if phases[i] > twoPi {
                            phases[i] -= twoPi  // 位相の正規化
                        }
                    }

                    state.currentDroneTime += 1.0 / sampleRate

                    // 減衰が十分小さくなったら停止
                    if state.currentDroneTime >= droneDuration {
                        state.currentDroneTime = -1.0
                    }
                }

                // 倍音数で正規化し、適度な音量に調整
                samples?[frame] = Float(value / Double(harmonics.count) * 0.35)  // ✂️ テスト用: 0.35（元: 0.15）
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
