//
//  NoiseGenerator.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-09.
//  ノイズ生成器（Pink/White/Brown）
//

import Foundation

/// ノイズタイプ
public enum NoiseType {
    case pink       // ピンクノイズ（Focus向け）
    case white      // ホワイトノイズ（Relax向け）
    case brown      // ブラウンノイズ（Sleep向け）
}

/// ノイズ生成器
public class NoiseGenerator {
    private let type: NoiseType

    // ピンクノイズ用
    private var pinkGenerators: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    private var pinkCounter: UInt32 = 0

    // ブラウンノイズ用
    private var brownRunningSum: Double = 0.0

    public init(type: NoiseType) {
        self.type = type
    }

    public func generate() -> Double {
        switch type {
        case .pink:
            return generatePink()
        case .white:
            return generateWhite()
        case .brown:
            return generateBrown()
        }
    }

    private func generateWhite() -> Double {
        return Double.random(in: -1.0...1.0)
    }

    private func generatePink() -> Double {
        // Voss-McCartney アルゴリズム
        let lastCounter = pinkCounter
        pinkCounter = pinkCounter &+ 1
        let diff = lastCounter ^ pinkCounter

        for i in 0..<pinkGenerators.count {
            if (diff & (1 << i)) != 0 {
                pinkGenerators[i] = Double.random(in: -1.0...1.0)
            }
        }

        let sum = pinkGenerators.reduce(0.0, +)
        return sum / Double(pinkGenerators.count)
    }

    private func generateBrown() -> Double {
        // ランダムウォーク
        let whiteNoise = Double.random(in: -1.0...1.0)
        brownRunningSum += whiteNoise * 0.02

        // クリッピング防止
        if brownRunningSum > 1.0 {
            brownRunningSum = 1.0
        } else if brownRunningSum < -1.0 {
            brownRunningSum = -1.0
        }

        return brownRunningSum
    }
}
