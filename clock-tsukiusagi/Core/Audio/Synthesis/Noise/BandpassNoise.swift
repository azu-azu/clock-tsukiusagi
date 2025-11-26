//
//  BandpassNoise.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  バンドパスノイズ
//

import AVFoundation

/// バンドパスノイズ生成器
/// 特定周波数帯域のノイズを生成します
/// ※実装は簡易版です。より正確なバンドパスフィルタはFilterBusで実装されます
public final class BandpassNoise: AudioSource {
    // MARK: - Properties

    private var _sourceNode: AVAudioSourceNode!
    public var sourceNode: AVAudioNode { _sourceNode }

    private let noiseSource: NoiseSource
    private let filterUnit: AVAudioUnitEQ

    /// 中心周波数（Hz）
    public var centerFrequency: Float {
        didSet {
            updateFilter()
        }
    }

    /// 帯域幅（オクターブ）
    public var bandwidth: Float {
        didSet {
            updateFilter()
        }
    }

    /// 音量（0.0〜1.0）
    public var amplitude: Float {
        get { noiseSource.amplitude }
        set { noiseSource.amplitude = newValue }
    }

    // MARK: - Initialization

    /// バンドパスノイズを初期化
    /// - Parameters:
    ///   - centerFrequency: 中心周波数（Hz）デフォルト: 500Hz
    ///   - bandwidth: 帯域幅（オクターブ）デフォルト: 1.0
    ///   - amplitude: 音量 デフォルト: 0.25
    public init(centerFrequency: Float = 500.0, bandwidth: Float = 1.0, amplitude: Float = 0.25) {
        self.noiseSource = NoiseSource(amplitude: amplitude)
        self.filterUnit = AVAudioUnitEQ(numberOfBands: 1)
        self.centerFrequency = centerFrequency
        self.bandwidth = bandwidth

        setupFilter()
    }

    // MARK: - AudioSource Protocol

    public func start() throws {
        try noiseSource.start()
    }

    public func stop() {
        noiseSource.stop()
    }

    public func setVolume(_ volume: Float) {
        noiseSource.setVolume(volume)
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        // ノイズソースを接続
        try noiseSource.attachAndConnect(to: engine, format: format)

        // フィルタをアタッチして接続
        engine.attach(filterUnit)
        engine.connect(noiseSource.sourceNode, to: filterUnit, format: format)
        engine.connect(filterUnit, to: engine.mainMixerNode, format: format)
    }

    // MARK: - Private Methods

    private func setupFilter() {
        let band = filterUnit.bands[0]
        band.filterType = .bandPass
        band.frequency = centerFrequency
        band.bandwidth = bandwidth
        band.gain = 0.0
        band.bypass = false
    }

    private func updateFilter() {
        let band = filterUnit.bands[0]
        band.frequency = centerFrequency
        band.bandwidth = bandwidth
    }
}
