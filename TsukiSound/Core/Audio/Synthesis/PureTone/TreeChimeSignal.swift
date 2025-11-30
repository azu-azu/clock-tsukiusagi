//
//  TreeChimeSignal.swift
//  TsukiSound
//
//  木漏れ日のツリーチャイム - 高周波メタリック粒の「シャラララ」
//  Signal-based implementation with cascading grain triggers
//
//  ## セクション対応
//  JupiterTimingを参照し、楽曲の進行に合わせて登場
//  - Section 0-1 (Bar 1-8): 無音
//  - Section 2 (Bar 9-12): 初登場（控えめ）
//  - Section 3-4 (Bar 13-20): 通常
//  - Section 5 (Bar 21-25): より活発
//

import Foundation

/// Tree Chime: Metallic shimmer with cascading grains
///
/// 特徴：
/// - 高周波メタリック粒が連鎖的に鳴る「シャラララ」効果
/// - 低→高のグリッサンド配置で自然な響き
/// - セクションに応じて出現頻度と音量が変化
/// - 各粒は1.2秒の exponential decay
public struct TreeChimeSignal {

    /// Create Tree Chime signal
    /// - Returns: Signal generating metallic shimmer
    public static func makeSignal() -> Signal {
        // チャイム設定
        let numGrains = 24          // 粒の数
        let cascadeInterval: Float = 0.020  // 各粒の間隔（20ms）
        let grainDuration: Float = 1.2      // 各粒の余韻
        let brightness: Float = 6000.0      // 基音周波数（Hz）

        // 全体音量（かすかに鳴る程度）
        let masterGain: Float = 0.03

        // 各粒の周波数（低→高のグリッサンド）
        let freqs: [Float] = (0..<numGrains).map { i in
            let ratio = Float(i) / Float(numGrains - 1)  // 0.0 → 1.0
            return brightness * (0.8 + ratio * 0.5)      // 0.8x → 1.3x
        }

        // Section 2の開始時刻を事前計算（Bar 9 = Section 2）
        let section2StartMusical = Float(JupiterTiming.sectionBars[2] - 1) * JupiterTiming.barDuration
        let section2StartReal = JupiterTiming.musicalToRealTime(section2StartMusical)

        return Signal { t in
            // セクションベースのゲインと間隔計算
            let section = JupiterTiming.currentSection(at: t)

            // Section 0-1: 無音
            // Section 2: 初登場（控えめ、間隔長め）
            // Section 3-4: 通常
            // Section 5: より活発（間隔短め、音量大きめ）
            let sectionGain: Float
            let minInterval: Float
            let maxInterval: Float

            switch section {
            case 0, 1:
                // 無音
                return 0.0
            case 2:
                // 初登場（控えめだが複数回鳴る）
                sectionGain = 0.6
                minInterval = 4.0
                maxInterval = 7.0
            case 3, 4:
                // 通常
                sectionGain = 0.8
                minInterval = 10.0
                maxInterval = 18.0
            default:
                // クライマックス（活発）
                sectionGain = 1.0
                minInterval = 6.0
                maxInterval = 12.0
            }

            // Section 2開始からの相対時間を使用（セクション開始時にすぐ鳴るように）
            let timeInActiveSection = t - section2StartReal

            // シード値を相対時間ベースで生成（安定したランダム性）
            let chimeIndex = Int(timeInActiveSection / minInterval)

            // この時点でのランダムシード
            var randomState = UInt64(chimeIndex * 7919)

            func nextRandom() -> Float {
                randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
                return Float(randomState % 10000) / 10000.0
            }

            let randomOffset = nextRandom() * (maxInterval - minInterval)
            let chimeStartTime = Float(chimeIndex) * minInterval + randomOffset

            // このチャイムがまだ始まっていない場合は無音
            guard timeInActiveSection >= chimeStartTime else {
                return 0.0
            }

            // チャイムからの経過時間
            let timeSinceChime = timeInActiveSection - chimeStartTime

            // チャイム全体の長さを超えたら無音
            let maxChimeLength = Float(numGrains) * cascadeInterval + grainDuration * 3.0
            guard timeSinceChime < maxChimeLength else {
                return 0.0
            }

            var value: Float = 0.0

            // 各粒を生成
            for i in 0..<numGrains {
                let grainStartTime = Float(i) * cascadeInterval
                let timeSinceGrain = timeSinceChime - grainStartTime

                // この粒がまだ始まっていない、または減衰し終わった場合はスキップ
                guard timeSinceGrain >= 0.0 else { continue }

                // エンベロープ（exponential decay）
                let envelope = exp(-timeSinceGrain / grainDuration)

                // 十分減衰したらスキップ（-60dB = 0.001）
                guard envelope > 0.001 else { continue }

                // メタリックな高周波サイン波
                let freq = freqs[i]
                let phase = 2.0 * Float.pi * freq * t
                value += sin(phase) * envelope
            }

            // 粒数で正規化して音量調整 + セクションゲイン
            return value / Float(numGrains) * masterGain * sectionGain
        }
    }
}
