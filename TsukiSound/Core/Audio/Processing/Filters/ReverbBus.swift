//
//  ReverbBus.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-09.
//  リバーブエフェクト
//

import AVFoundation

/// リバーブバス
/// AVAudioUnitReverbを使って残響効果を提供します
public final class ReverbBus {
    // MARK: - Properties

    private let reverbUnit: AVAudioUnitReverb

    /// Wet/Dry ミックス（0〜100）
    /// 0 = ドライ（エフェクトなし）、100 = ウェット（エフェクトのみ）
    public var wetDryMix: Float {
        get { reverbUnit.wetDryMix }
        set { reverbUnit.wetDryMix = max(0, min(100, newValue)) }
    }

    /// リバーブをバイパスするか
    public var isBypassed: Bool {
        get { reverbUnit.bypass }
        set { reverbUnit.bypass = newValue }
    }

    // MARK: - Initialization

    /// リバーブバスを初期化
    /// - Parameters:
    ///   - preset: リバーブプリセット デフォルト: Medium Hall
    ///   - wetDryMix: Wet/Dry ミックス デフォルト: 30
    public init(
        preset: AVAudioUnitReverbPreset = .mediumHall,
        wetDryMix: Float = 30.0
    ) {
        self.reverbUnit = AVAudioUnitReverb()
        self.reverbUnit.loadFactoryPreset(preset)
        self.reverbUnit.wetDryMix = wetDryMix
    }

    // MARK: - Public Methods

    /// オーディオノードを取得
    public var audioNode: AVAudioNode {
        reverbUnit
    }

    /// プリセットを読み込む
    /// - Parameter preset: リバーブプリセット
    public func loadPreset(_ preset: AVAudioUnitReverbPreset) {
        reverbUnit.loadFactoryPreset(preset)
    }

    /// リバーブをエンジンにアタッチして接続
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
        engine.attach(reverbUnit)
        engine.connect(sourceNode, to: reverbUnit, format: format)
        engine.connect(reverbUnit, to: destinationNode, format: format)
    }
}

// MARK: - Convenience Presets

public extension ReverbBus {
    /// 小部屋用リバーブ
    static func smallRoom() -> ReverbBus {
        ReverbBus(preset: .smallRoom, wetDryMix: 15)
    }

    /// 中部屋用リバーブ
    static func mediumRoom() -> ReverbBus {
        ReverbBus(preset: .mediumRoom, wetDryMix: 30)
    }

    /// 大ホール用リバーブ
    static func largeHall() -> ReverbBus {
        ReverbBus(preset: .largeHall, wetDryMix: 50)
    }

    /// 大聖堂用リバーブ
    static func cathedral() -> ReverbBus {
        ReverbBus(preset: .cathedral, wetDryMix: 60)
    }
}
