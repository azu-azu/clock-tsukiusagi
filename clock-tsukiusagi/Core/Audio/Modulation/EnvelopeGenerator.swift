//
//  EnvelopeGenerator.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  ADSR エンベロープ
//

import Foundation

/// エンベロープの状態
public enum EnvelopeStage {
    case idle       // 待機中
    case attack     // アタック（立ち上がり）
    case decay      // ディケイ（減衰）
    case sustain    // サステイン（持続）
    case release    // リリース（解放）
}

/// ADSRエンベロープジェネレータ
/// 音量の時間変化を制御します
public final class EnvelopeGenerator {
    // MARK: - Properties

    /// アタック時間（秒）
    public var attackTime: Double {
        didSet { attackTime = max(0.001, attackTime) }
    }

    /// ディケイ時間（秒）
    public var decayTime: Double {
        didSet { decayTime = max(0.001, decayTime) }
    }

    /// サステインレベル（0.0〜1.0）
    public var sustainLevel: Double {
        didSet { sustainLevel = max(0.0, min(1.0, sustainLevel)) }
    }

    /// リリース時間（秒）
    public var releaseTime: Double {
        didSet { releaseTime = max(0.001, releaseTime) }
    }

    /// 現在の状態
    public private(set) var stage: EnvelopeStage = .idle

    /// 現在の値（0.0〜1.0）
    public private(set) var currentValue: Double = 0.0

    private var elapsedTime: Double = 0.0
    private var releaseStartValue: Double = 0.0

    // MARK: - Initialization

    /// エンベロープジェネレータを初期化
    /// - Parameters:
    ///   - attackTime: アタック時間（秒）デフォルト: 0.01秒
    ///   - decayTime: ディケイ時間（秒）デフォルト: 0.1秒
    ///   - sustainLevel: サステインレベル デフォルト: 0.7
    ///   - releaseTime: リリース時間（秒）デフォルト: 0.3秒
    public init(
        attackTime: Double = 0.01,
        decayTime: Double = 0.1,
        sustainLevel: Double = 0.7,
        releaseTime: Double = 0.3
    ) {
        self.attackTime = attackTime
        self.decayTime = decayTime
        self.sustainLevel = sustainLevel
        self.releaseTime = releaseTime
    }

    // MARK: - Public Methods

    /// ノートオン（音を鳴らし始める）
    public func noteOn() {
        stage = .attack
        elapsedTime = 0.0
    }

    /// ノートオフ（音を止める）
    public func noteOff() {
        stage = .release
        elapsedTime = 0.0
        releaseStartValue = currentValue
    }

    /// 値を更新
    /// - Parameter deltaTime: 前回の呼び出しからの経過時間（秒）
    /// - Returns: 現在のエンベロープ値（0.0〜1.0）
    public func getValue(deltaTime: Double) -> Double {
        elapsedTime += deltaTime

        switch stage {
        case .idle:
            currentValue = 0.0

        case .attack:
            // 0.0 → 1.0 に線形に増加
            let progress = min(elapsedTime / attackTime, 1.0)
            currentValue = progress

            if progress >= 1.0 {
                stage = .decay
                elapsedTime = 0.0
            }

        case .decay:
            // 1.0 → sustainLevel に線形に減少
            let progress = min(elapsedTime / decayTime, 1.0)
            currentValue = 1.0 - ((1.0 - sustainLevel) * progress)

            if progress >= 1.0 {
                stage = .sustain
                elapsedTime = 0.0
            }

        case .sustain:
            // sustainLevel を維持
            currentValue = sustainLevel

        case .release:
            // releaseStartValue → 0.0 に線形に減少
            let progress = min(elapsedTime / releaseTime, 1.0)
            currentValue = releaseStartValue * (1.0 - progress)

            if progress >= 1.0 {
                stage = .idle
                elapsedTime = 0.0
            }
        }

        return currentValue
    }

    /// エンベロープをリセット
    public func reset() {
        stage = .idle
        currentValue = 0.0
        elapsedTime = 0.0
    }
}
