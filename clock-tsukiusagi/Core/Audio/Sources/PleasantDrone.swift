//
//  PleasantDrone.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  コード進行とLFO変調による心地よいドローン音源
//

import AVFoundation
import Foundation

/// 和音ベースのドローン音源（LFO変調付き）
/// Fujiko設計原則: 持続音にゆっくりとした変化（呼吸感）を与える
public final class PleasantDrone: AudioSource {
    // MARK: - Properties

    private let _sourceNode: AVAudioSourceNode
    public var sourceNode: AVAudioNode { _sourceNode }

    private let chordFrequencies: [Double]  // 和音を構成する周波数
    private let baseAmplitude: Double

    // MARK: - Initialization

    /// PleasantDrone を初期化
    /// - Parameters:
    ///   - rootFrequency: 根音の周波数（Hz）
    ///   - chordType: コードタイプ（major, minor, sus4, etc）
    ///   - amplitude: 基本振幅（0.0〜1.0）
    ///   - amplitudeLFOFrequency: 音量変調の周波数（Hz、デフォルト: 0.15Hz）
    ///   - pitchLFOFrequency: ピッチ変調の周波数（Hz、デフォルト: 0.5Hz）
    ///   - pitchLFODepth: ピッチ変調の深さ（Hz、デフォルト: 2.0Hz）
    ///   - noiseLevel: ノイズ混入量（0.0〜1.0、デフォルト: 0.015）
    public init(
        rootFrequency: Double,
        chordType: ChordType = .major,
        amplitude: Double = 0.25,
        amplitudeLFOFrequency: Double = 0.15,
        pitchLFOFrequency: Double = 0.5,
        pitchLFODepth: Double = 2.0,
        noiseLevel: Double = 0.015
    ) {
        self.baseAmplitude = amplitude
        self.chordFrequencies = chordType.getFrequencies(root: rootFrequency)

        // ローカル変数として状態を保持
        var localPhases: [Double] = []
        let twoPi = 2.0 * Double.pi

        // 各オシレータの位相を初期化
        for _ in chordFrequencies {
            localPhases.append(Double.random(in: 0..<twoPi))  // ランダムな初期位相で豊かさを増す
        }

        var amplitudeLFOPhase: Double = 0.0
        var pitchLFOPhase: Double = 0.0
        var elapsedTime: Double = 0.0

        let localChordFrequencies = chordFrequencies
        let localAmplitude = amplitude
        let localAmplitudeLFOFrequency = amplitudeLFOFrequency
        let localPitchLFOFrequency = pitchLFOFrequency
        let localPitchLFODepth = pitchLFODepth
        let localNoiseLevel = noiseLevel

        // AVAudioSourceNode を作成
        _sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let sampleRate = 44100.0
            let deltaTime = 1.0 / sampleRate

            for frame in 0..<Int(frameCount) {
                // LFO値を計算
                let ampLFO = sin(amplitudeLFOPhase)
                let pitchLFO = sin(pitchLFOPhase)

                // 音量変調（0.7〜1.0の範囲で「呼吸」）
                let volumeModulation = 0.85 + (ampLFO * 0.15)

                // ピッチ変調
                let pitchModulation = pitchLFO * localPitchLFODepth

                // 和音の各音を合成
                var mixedSample: Double = 0.0

                for (i, baseFreq) in localChordFrequencies.enumerated() {
                    let modulatedFreq = baseFreq + pitchModulation

                    // 各音にわずかなデチューンを追加
                    let detune = sin(elapsedTime * (0.1 + Double(i) * 0.05)) * 0.5
                    let detuned = sin(localPhases[i] + detune * 0.01)

                    // tanh で波形を整形
                    let shapedSample = tanh(detuned * 1.15)
                    mixedSample += shapedSample

                    // 位相を進める
                    let phaseIncrement = twoPi * modulatedFreq / sampleRate
                    localPhases[i] += phaseIncrement

                    // 位相を正規化
                    if localPhases[i] >= twoPi {
                        localPhases[i] -= twoPi
                    }
                }

                // 平均化
                mixedSample /= Double(localChordFrequencies.count)

                // ノイズを追加（空気感）
                let noise = Double.random(in: -1.0...1.0) * localNoiseLevel
                mixedSample += noise

                // 音量変調と基本振幅を適用
                let finalSample = Float(mixedSample * localAmplitude * volumeModulation)

                // 全チャンネルに書き込み
                for buffer in abl {
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    samples[frame] = finalSample
                }

                // LFO位相を進める
                amplitudeLFOPhase += twoPi * localAmplitudeLFOFrequency * deltaTime
                pitchLFOPhase += twoPi * localPitchLFOFrequency * deltaTime

                // 経過時間を更新
                elapsedTime += deltaTime

                // 位相を正規化
                if amplitudeLFOPhase >= twoPi {
                    amplitudeLFOPhase -= twoPi
                }
                if pitchLFOPhase >= twoPi {
                    pitchLFOPhase -= twoPi
                }
            }

            return noErr
        }
    }

    // MARK: - AudioSource Protocol

    public func start() throws {
        // ソースノードは自動的に動作
    }

    public func stop() {
        // ソースノードは自動的に停止
    }

    public func setVolume(_ volume: Float) {
        // ボリュームは LocalAudioEngine のマスターボリュームで制御
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}

// MARK: - ChordType

/// コードタイプの定義
public enum ChordType {
    case major          // メジャー（明るい）
    case minor          // マイナー（暗い）
    case sus4           // サスフォー（浮遊感）
    case major7         // メジャーセブンス（洗練された）
    case minor7         // マイナーセブンス（ジャジー）
    case powerChord     // パワーコード（シンプル）

    /// 根音から各音の周波数を計算
    /// - Parameter root: 根音の周波数（Hz）
    /// - Returns: コードを構成する周波数の配列
    public func getFrequencies(root: Double) -> [Double] {
        switch self {
        case .major:
            // Root, Major 3rd, Perfect 5th
            return [
                root,                        // 根音
                root * pow(2.0, 4.0/12.0),  // 長3度
                root * pow(2.0, 7.0/12.0)   // 完全5度
            ]

        case .minor:
            // Root, Minor 3rd, Perfect 5th
            return [
                root,                        // 根音
                root * pow(2.0, 3.0/12.0),  // 短3度
                root * pow(2.0, 7.0/12.0)   // 完全5度
            ]

        case .sus4:
            // Root, Perfect 4th, Perfect 5th
            return [
                root,                        // 根音
                root * pow(2.0, 5.0/12.0),  // 完全4度
                root * pow(2.0, 7.0/12.0)   // 完全5度
            ]

        case .major7:
            // Root, Major 3rd, Perfect 5th, Major 7th
            return [
                root,                         // 根音
                root * pow(2.0, 4.0/12.0),   // 長3度
                root * pow(2.0, 7.0/12.0),   // 完全5度
                root * pow(2.0, 11.0/12.0)   // 長7度
            ]

        case .minor7:
            // Root, Minor 3rd, Perfect 5th, Minor 7th
            return [
                root,                         // 根音
                root * pow(2.0, 3.0/12.0),   // 短3度
                root * pow(2.0, 7.0/12.0),   // 完全5度
                root * pow(2.0, 10.0/12.0)   // 短7度
            ]

        case .powerChord:
            // Root, Perfect 5th, Octave
            return [
                root,                        // 根音
                root * pow(2.0, 7.0/12.0),  // 完全5度
                root * 2.0                   // オクターブ
            ]
        }
    }
}
