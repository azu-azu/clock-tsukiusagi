//
//  TreeChimeSignal.swift
//  TsukiSound
//
//  木漏れ日のツリーチャイム - 高周波メタリック粒の「シャラララ」
//  Signal-based implementation with cascading grain triggers
//
//  ## 自然さの改善
//  - ランダム位相オフセット: 粒ごとに位相がずれ、人工的な統一感を解消
//  - 微小デチューン: ±1.5Hz のランダムで、サイン波の人工さを軽減
//    （±20Hzだとモノラルでビート干渉が強すぎてシャリシャリ雑音になる）
//
//  ## セクション対応
//  JupiterTimingを参照し、楽曲の進行に合わせて登場
//  - Section 0-1 (Bar 1-8): 遠くで微かにチリン（20-40秒間隔、-20dB相当）
//  - Section 2 (Bar 9-12): 初登場（控えめ）
//  - Section 3-4 (Bar 13-20): 通常
//  - Section 5 (Bar 21-25): クライマックス → 終盤でSection 0レベルへフェードダウン
//

import Foundation

/// Tree Chime: Metallic shimmer with cascading grains
///
/// 特徴：
/// - 高周波メタリック粒が連鎖的に鳴る「シャラララ」効果
/// - 低→高のグリッサンド配置で自然な響き
/// - ランダム位相オフセット + 微小デチューンで自然なキラキラ感
/// - セクションに応じて出現頻度と音量が変化
/// - 各粒は1.2秒の exponential decay
/// - ループ時: クライマックス→導入が薄いチャイムで自然に繋がる
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

        // Section 0-1 の遠いチャイム: -20dB ≈ 0.1 (10^(-20/20))
        let section0Gain: Float = 0.1

        // 微小デチューンの振れ幅（±1.5Hz - モノラルでのビート干渉を防ぐため極小）
        let detuneRange: Float = 3.0

        // 各粒のベース周波数（低→高のグリッサンド）
        let baseFreqs: [Float] = (0..<numGrains).map { i in
            let ratio = Float(i) / Float(numGrains - 1)  // 0.0 → 1.0
            return brightness * (0.8 + ratio * 0.5)      // 0.8x → 1.3x
        }

        return Signal { t in
            // セクションベースのゲインと間隔計算
            let section = JupiterTiming.currentSection(at: t)

            // Section 0-1: 遠くで微かにチリン（20-40秒間隔）
            // Section 2: 初登場（控えめ、間隔長め）
            // Section 3-4: 通常
            // Section 5: クライマックス → Section 0レベルへフェードダウン
            let sectionGain: Float
            let minInterval: Float
            let maxInterval: Float

            switch section {
            case 0, 1:
                // 遠くで微かにチリン（ほぼ聞こえないレベル）
                sectionGain = section0Gain
                minInterval = 20.0
                maxInterval = 40.0
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
                // クライマックス → Section 0レベルへフェードダウン
                let sectionProgress = JupiterTiming.sectionProgress(at: t)
                minInterval = 6.0
                maxInterval = 12.0
                if sectionProgress < 0.8 {
                    // 前半80%はクライマックス
                    sectionGain = 1.0
                } else {
                    // 後半20%で Section 0 レベルへフェードダウン
                    let fadeProgress = (sectionProgress - 0.8) / 0.2
                    let c = cos(fadeProgress * Float.pi * 0.5)
                    // 1.0 → section0Gain へ cos² でスムーズに遷移
                    sectionGain = section0Gain + (1.0 - section0Gain) * c * c
                }
            }

            // 絶対時間ベースで計算（全セクションで動作するように）
            let timeInActiveSection = t

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

            // 粒ごとのランダム値を生成するためのシード（チャイムごとに固定）
            var grainRng = UInt64(chimeIndex * 13331)

            func nextGrainRandom() -> Float {
                grainRng = grainRng &* 6364136223846793005 &+ 1442695040888963407
                return Float(grainRng % 10000) / 10000.0
            }

            // 各粒を生成
            for i in 0..<numGrains {
                let grainStartTime = Float(i) * cascadeInterval
                let timeSinceGrain = timeSinceChime - grainStartTime

                // この粒がまだ始まっていない、または減衰し終わった場合はスキップ
                guard timeSinceGrain >= 0.0 else {
                    // スキップしてもRNGは進める（一貫性のため）
                    _ = nextGrainRandom()  // detune用
                    _ = nextGrainRandom()  // phase用
                    continue
                }

                // エンベロープ（exponential decay）
                let envelope = exp(-timeSinceGrain / grainDuration)

                // 十分減衰したらスキップ（-60dB = 0.001）
                guard envelope > 0.001 else {
                    _ = nextGrainRandom()
                    _ = nextGrainRandom()
                    continue
                }

                // ① 微小デチューン: ±1.5Hz のランダム（モノラルでの干渉防止）
                let detune = (nextGrainRandom() - 0.5) * detuneRange
                let freq = baseFreqs[i] + detune

                // ② ランダム位相オフセット: 粒ごとに位相がずれる
                let phaseOffset = nextGrainRandom() * Float.pi * 2.0

                // メタリックな高周波サイン波（位相オフセット付き）
                let phase = 2.0 * Float.pi * freq * t + phaseOffset
                value += sin(phase) * envelope
            }

            // 粒数で正規化して音量調整 + セクションゲイン
            return value / Float(numGrains) * masterGain * sectionGain
        }
    }
}
