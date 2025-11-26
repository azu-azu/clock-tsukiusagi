//
//  RandomTrigger.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  ランダムイベントトリガー
//

import Foundation

/// ランダムトリガー
/// 指定範囲でランダムにイベントを発生させます
public final class RandomTrigger {
    // MARK: - Properties

    /// 最小間隔（秒）
    public var minimumInterval: Double {
        didSet { minimumInterval = max(0.1, minimumInterval) }
    }

    /// 最大間隔（秒）
    public var maximumInterval: Double {
        didSet { maximumInterval = max(minimumInterval, maximumInterval) }
    }

    /// トリガーされた時に呼ばれるコールバック
    public var onTrigger: (() -> Void)?

    private var elapsedTime: Double = 0.0
    private var nextTriggerTime: Double

    // MARK: - Initialization

    /// ランダムトリガーを初期化
    /// - Parameters:
    ///   - minimumInterval: 最小間隔（秒）デフォルト: 1.0秒
    ///   - maximumInterval: 最大間隔（秒）デフォルト: 5.0秒
    public init(minimumInterval: Double = 1.0, maximumInterval: Double = 5.0) {
        self.minimumInterval = minimumInterval
        self.maximumInterval = maximumInterval
        self.nextTriggerTime = Double.random(in: minimumInterval...maximumInterval)
    }

    // MARK: - Public Methods

    /// 時間を進めて、必要に応じてトリガーを発火
    /// - Parameter deltaTime: 前回の呼び出しからの経過時間（秒）
    public func update(deltaTime: Double) {
        elapsedTime += deltaTime

        if elapsedTime >= nextTriggerTime {
            // トリガーを発火
            onTrigger?()

            // 次のトリガー時間を設定
            elapsedTime = 0.0
            nextTriggerTime = Double.random(in: minimumInterval...maximumInterval)
        }
    }

    /// トリガーをリセット
    public func reset() {
        elapsedTime = 0.0
        nextTriggerTime = Double.random(in: minimumInterval...maximumInterval)
    }

    /// 即座にトリガーを発火
    public func triggerNow() {
        onTrigger?()
        reset()
    }
}
