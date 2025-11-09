//
//  FilterBus.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  EQ/ローパスフィルタ
//

import AVFoundation

/// フィルタタイプ
public enum FilterType {
    case lowPass    // ローパス（高音カット）
    case highPass   // ハイパス（低音カット）
    case bandPass   // バンドパス（特定周波数帯のみ通す）
}

/// フィルタバス
/// AVAudioUnitEQを使ってフィルタリングを行います
public final class FilterBus {
    // MARK: - Properties

    private let eqUnit: AVAudioUnitEQ

    /// フィルタタイプ
    public var filterType: FilterType {
        didSet { updateFilter() }
    }

    /// カットオフ周波数（Hz）
    public var cutoffFrequency: Float {
        didSet {
            cutoffFrequency = max(20, min(20000, cutoffFrequency))
            updateFilter()
        }
    }

    /// Q値（バンドパスの場合の帯域幅）
    public var qValue: Float {
        didSet {
            qValue = max(0.1, min(10.0, qValue))
            updateFilter()
        }
    }

    /// フィルタをバイパスするか
    public var isBypassed: Bool {
        get { band.bypass }
        set { band.bypass = newValue }
    }

    private var band: AVAudioUnitEQFilterParameters {
        eqUnit.bands[0]
    }

    // MARK: - Initialization

    /// フィルタバスを初期化
    /// - Parameters:
    ///   - filterType: フィルタタイプ デフォルト: ローパス
    ///   - cutoffFrequency: カットオフ周波数 デフォルト: 1500Hz
    ///   - qValue: Q値 デフォルト: 0.7
    public init(
        filterType: FilterType = .lowPass,
        cutoffFrequency: Float = 1500.0,
        qValue: Float = 0.7
    ) {
        self.eqUnit = AVAudioUnitEQ(numberOfBands: 1)
        self.filterType = filterType
        self.cutoffFrequency = cutoffFrequency
        self.qValue = qValue

        setupFilter()
    }

    // MARK: - Public Methods

    /// オーディオノードを取得
    public var audioNode: AVAudioNode {
        eqUnit
    }

    /// フィルタをエンジンにアタッチして接続
    /// - Parameters:
    ///   - engine: AVAudioEngine
    ///   - sourceNode: 入力ノード
    ///   - destinationNode: 出力ノード
    ///   - format: オーディオフォーマット
    public func connect(
        in engine: AVAudioEngine,
        from sourceNode: AVAudioNode,
        to destinationNode: AVAudioNode,
        format: AVAudioFormat
    ) {
        engine.attach(eqUnit)
        engine.connect(sourceNode, to: eqUnit, format: format)
        engine.connect(eqUnit, to: destinationNode, format: format)
    }

    // MARK: - Private Methods

    private func setupFilter() {
        updateFilter()
        band.gain = 0.0
        band.bypass = false
    }

    private func updateFilter() {
        switch filterType {
        case .lowPass:
            band.filterType = .lowPass
            band.frequency = cutoffFrequency
            band.bandwidth = qValue

        case .highPass:
            band.filterType = .highPass
            band.frequency = cutoffFrequency
            band.bandwidth = qValue

        case .bandPass:
            band.filterType = .bandPass
            band.frequency = cutoffFrequency
            band.bandwidth = qValue
        }
    }
}
