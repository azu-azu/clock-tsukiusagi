//
//  PulseGenerator.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-09.
//  ランダムパルス生成器
//

import AVFoundation

/// パルス生成器
/// 短いノイズバーストをランダムに生成します（焚き火のパチパチ音など）
public final class PulseGenerator: AudioSource {
    // MARK: - Properties

    private var _sourceNode: AVAudioSourceNode!
    public var sourceNode: AVAudioNode { _sourceNode }

    /// 全体の音量（0.0〜1.0）
    public var amplitude: Float {
        didSet { amplitude = max(0.0, min(1.0, amplitude)) }
    }

    /// パルスの最小持続時間（秒）
    public var minimumDuration: Double = 0.01

    /// パルスの最大持続時間（秒）
    public var maximumDuration: Double = 0.05

    /// パルス間の最小間隔（秒）
    public var minimumInterval: Double = 0.5

    /// パルス間の最大間隔（秒）
    public var maximumInterval: Double = 3.0

    /// パルスの最小音量倍率
    public var minimumAmplitudeMultiplier: Float = 0.4

    /// パルスの最大音量倍率
    public var maximumAmplitudeMultiplier: Float = 1.0

    private var isPulseActive = false
    private var pulseElapsedTime: Double = 0.0
    private var pulseDuration: Double = 0.0
    private var currentPulseAmplitude: Float = 0.0

    private var intervalElapsedTime: Double = 0.0
    private var nextInterval: Double = 0.0

    // MARK: - Initialization

    /// パルス生成器を初期化
    /// - Parameter amplitude: 全体の音量 デフォルト: 0.5
    public init(amplitude: Float = 0.5) {
        self.amplitude = amplitude
        self.nextInterval = Double.random(in: minimumInterval...maximumInterval)
    }

    // MARK: - AudioSource Protocol

    public func start() throws {
        // AVAudioSourceNodeは自動的に開始されるため、特別な処理は不要
    }

    public func stop() {
        amplitude = 0.0
    }

    public func setVolume(_ volume: Float) {
        amplitude = volume
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        let sampleRate = format.sampleRate
        let deltaTime = 1.0 / sampleRate

        // レンダーブロック内でランダムパルスを生成
        _sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                var sample: Float = 0.0

                // パルスがアクティブでない場合、次のパルスまでの時間をカウント
                if !self.isPulseActive {
                    self.intervalElapsedTime += deltaTime

                    if self.intervalElapsedTime >= self.nextInterval {
                        // 新しいパルスを開始
                        self.isPulseActive = true
                        self.pulseElapsedTime = 0.0
                        self.pulseDuration = Double.random(in: self.minimumDuration...self.maximumDuration)
                        self.currentPulseAmplitude = Float.random(in: self.minimumAmplitudeMultiplier...self.maximumAmplitudeMultiplier)
                        self.intervalElapsedTime = 0.0
                        self.nextInterval = Double.random(in: self.minimumInterval...self.maximumInterval)
                    }
                }

                // パルスがアクティブの場合、ノイズを生成
                if self.isPulseActive {
                    let random = Float.random(in: -1.0...1.0)
                    sample = random * self.amplitude * self.currentPulseAmplitude

                    self.pulseElapsedTime += deltaTime

                    // パルス終了
                    if self.pulseElapsedTime >= self.pulseDuration {
                        self.isPulseActive = false
                    }
                }

                // 全チャンネルに同じサンプルを書き込み
                for buffer in abl {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = sample
                }
            }

            return noErr
        }

        // エンジンにアタッチして接続
        engine.attach(_sourceNode)
        engine.connect(_sourceNode, to: engine.mainMixerNode, format: format)
    }
}
