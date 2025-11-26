//
//  LFO.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  低周波変調（波の音、ビブラート用）
//

import Foundation

/// LFO波形タイプ
public enum LFOWaveform {
    case sine       // サイン波（滑らか）
    case triangle   // 三角波（線形）
    case square     // 矩形波（ON/OFF）
    case sawtooth   // のこぎり波
}

/// 低周波オシレータ（Low Frequency Oscillator）
/// パラメータを周期的に変調するために使用
public final class LFO {
    // MARK: - Properties

    /// 周波数（Hz）0.1〜20Hz
    public var frequency: Double {
        didSet { frequency = max(0.1, min(20.0, frequency)) }
    }

    /// 変調の深さ（0.0〜1.0）
    public var depth: Double {
        didSet { depth = max(0.0, min(1.0, depth)) }
    }

    /// 波形タイプ
    public var waveform: LFOWaveform

    /// 最小値
    public var minimum: Double

    /// 最大値
    public var maximum: Double

    private var phase: Double = 0.0
    private let twoPi = 2.0 * Double.pi

    // MARK: - Initialization

    /// LFOを初期化
    /// - Parameters:
    ///   - frequency: 周波数（Hz）デフォルト: 1.0Hz
    ///   - depth: 変調の深さ デフォルト: 0.5
    ///   - waveform: 波形タイプ デフォルト: サイン波
    ///   - minimum: 最小値 デフォルト: 0.0
    ///   - maximum: 最大値 デフォルト: 1.0
    public init(
        frequency: Double = 1.0,
        depth: Double = 0.5,
        waveform: LFOWaveform = .sine,
        minimum: Double = 0.0,
        maximum: Double = 1.0
    ) {
        self.frequency = frequency
        self.depth = depth
        self.waveform = waveform
        self.minimum = minimum
        self.maximum = maximum
    }

    // MARK: - Public Methods

    /// 現在の変調値を取得
    /// - Parameter deltaTime: 前回の呼び出しからの経過時間（秒）
    /// - Returns: 変調された値（minimum〜maximumの範囲）
    public func getValue(deltaTime: Double) -> Double {
        // 位相を進める
        phase += twoPi * frequency * deltaTime

        // 位相を2πの範囲内に保つ
        if phase > twoPi {
            phase -= twoPi
        }

        // 波形に応じた生値を計算（-1.0〜1.0）
        let rawValue: Double
        switch waveform {
        case .sine:
            rawValue = sin(phase)

        case .triangle:
            // 三角波: -1 → 1 → -1
            let normalizedPhase = phase / twoPi
            if normalizedPhase < 0.5 {
                rawValue = -1.0 + (normalizedPhase * 4.0)
            } else {
                rawValue = 3.0 - (normalizedPhase * 4.0)
            }

        case .square:
            // 矩形波: -1 or 1
            rawValue = phase < Double.pi ? 1.0 : -1.0

        case .sawtooth:
            // のこぎり波: -1 → 1（線形）
            rawValue = -1.0 + (phase / Double.pi)
        }

        // 深さを適用（-depth〜+depth）
        let modulatedValue = rawValue * depth

        // minimum〜maximumの範囲にマッピング
        let range = maximum - minimum
        let center = minimum + (range / 2.0)
        return center + (modulatedValue * range / 2.0)
    }

    /// 位相をリセット
    public func reset() {
        phase = 0.0
    }
}
