//
//  JupiterTiming.swift
//  TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter
//
//  Jupiter楽曲のタイミングとセクション管理
//  他のSignal（OrganDrone, TreeChime）がJupiterの進行度を参照するために使用
//
//  ## ループ境界を自然に繋ぐ仕組み
//  - 1回目だけイントロスキップ（即メロディ開始）
//  - 2回目以降は休符2拍もそのまま（ドローンの「ボワーン」だけが聞こえる）
//  - クライマックス → 休符（くるくる）→ メロディ開始
//
//  ## テンポ伸縮（段階的に加速）
//  - Zone 0: Bar 1 ~ Bar 2 beat 1.0: 0.7倍（ゆったり）
//  - Zone 1: Bar 2 beat 1.0 ~ Bar 3 beat 2.0: 0.8倍
//  - Zone 2: Bar 3 beat 2.0 ~ Bar 5: 0.9倍
//  - Zone 3: Bar 5 ~ Bar 9: 1.0倍（通常）
//  - Zone 4: Bar 9 ~ Bar 13 beat 2.0: 1.05倍
//  - Zone 5: Bar 13 beat 2.0 ~ Bar 17: 1.1倍
//  - Zone 6: Bar 17 ~ Bar 21: 1.15倍（トランペット）
//  - Zone 7: Bar 21 ~ Bar 25: 1.2倍（クラリネット）
//

import Foundation

// MARK: - Jupiter Timing Constants

/// Jupiter楽曲のタイミング定数
/// 各Signalがこの定数を参照して同期する
public enum JupiterTiming {

    /// 1拍の長さ（秒）- 60 BPM = 1.0s per beat
    public static let beatDuration: Float = 1.0

    /// 1小節の長さ（秒）- 3/4拍子 = 3拍
    public static let barDuration: Float = beatDuration * 3.0

    /// 総小節数
    public static let totalBars: Int = 25

    // MARK: - Tempo Zones (細かいテンポ変化)

    /// テンポゾーン定義: (楽譜時間での開始位置, テンポ倍率)
    /// 楽譜時間 = (bar - 1) * 3 + beat
    private static let tempoZones: [(musicalStart: Float, tempoRatio: Float)] = [
        // Zone 0: Bar 1 beat 0.0 (= 0.0) ~ 0.7倍
        (0.0, 0.7),
        // Zone 1: Bar 2 beat 1.0 (= 4.0) ~ 0.8倍
        (4.0, 0.8),
        // Zone 2: Bar 3 beat 2.0 (= 8.0) ~ 0.9倍
        (8.0, 0.9),
        // Zone 3: Bar 5 beat 0.0 (= 12.0) ~ 1.0倍
        (12.0, 1.0),
        // Zone 4: Bar 9 beat 0.0 (= 24.0) ~ 1.05倍
        (24.0, 1.05),
        // Zone 5: Bar 13 beat 2.0 (= 38.0) ~ 1.1倍
        (38.0, 1.1),
        // Zone 6: Bar 17 beat 0.0 (= 48.0) ~ 1.15倍
        (48.0, 1.15),
        // Zone 7: Bar 21 beat 0.0 (= 60.0) ~ 1.2倍
        (60.0, 1.2),
    ]

    /// 楽譜の終了位置
    public static var fullMusicalCycleDuration: Float {
        Float(totalBars) * barDuration  // 25 * 3 = 75秒
    }

    // MARK: - Intro Skip (1回目だけ適用)

    /// Bar 1 の休符分（楽譜時間で2拍 = 2.0秒）
    /// 1回目: スキップして即メロディ開始
    /// 2回目以降: スキップせず、ドローンの「くるくる」が聞こえる
    public static let introRestBeats: Float = 2.0

    /// イントロ休符の長さ（楽譜時間）
    private static var introRestMusical: Float { introRestBeats * beatDuration }

    // MARK: - Precomputed Tempo Zone Data

    /// 各ゾーンの楽譜時間での長さと実時間での長さを事前計算
    private static var zoneData: [(musicalStart: Float, musicalEnd: Float, musicalDuration: Float, realDuration: Float, tempoRatio: Float)] {
        var result: [(Float, Float, Float, Float, Float)] = []
        for i in 0..<tempoZones.count {
            let start = tempoZones[i].musicalStart
            let end = (i < tempoZones.count - 1) ? tempoZones[i + 1].musicalStart : fullMusicalCycleDuration
            let musicalDuration = end - start
            let tempoRatio = tempoZones[i].tempoRatio
            let realDuration = musicalDuration / tempoRatio
            result.append((start, end, musicalDuration, realDuration, tempoRatio))
        }
        return result
    }

    /// テンポ伸縮による時間変化の合計
    private static var tempoStretchExtra: Float {
        zoneData.reduce(0) { sum, zone in
            sum + (zone.realDuration - zone.musicalDuration)
        }
    }

    /// 1回目のサイクル長（イントロ休符をスキップ + テンポ伸縮）
    public static var firstCycleDuration: Float {
        // イントロ休符分のテンポ補正を計算
        let introRealDuration = calculateRealDuration(from: 0, to: introRestMusical)
        let totalRealDuration = calculateRealDuration(from: 0, to: fullMusicalCycleDuration)
        return totalRealDuration - introRealDuration
    }

    /// 2回目以降のサイクル長（休符含む + テンポ伸縮）
    public static var normalCycleDuration: Float {
        calculateRealDuration(from: 0, to: fullMusicalCycleDuration)
    }

    // MARK: - Section Boundaries (🌠 markers)

    /// セクション境界（小節番号）
    /// 🌠マーカーの位置に基づく
    /// - Section 0: Bar 1-4  (導入 - アカペラ風、テンポ遅め)
    /// - Section 1: Bar 5-8  (🌠1 - Organ drone フェードイン)
    /// - Section 2: Bar 9-12 (🌠2 - TreeChime 初登場)
    /// - Section 3: Bar 13-16 (🌠3 - メロディに厚み)
    /// - Section 4: Bar 17-20 (🌠4 - さらに活発)
    /// - Section 5: Bar 21-25 (🌠5 - クライマックス)
    public static let sectionBars: [Int] = [1, 5, 9, 13, 17, 21]

    // MARK: - Time Mapping (Real Time ↔ Musical Time)

    /// 楽譜時間の範囲から実時間の長さを計算
    private static func calculateRealDuration(from musicalStart: Float, to musicalEnd: Float) -> Float {
        var realDuration: Float = 0
        let zones = zoneData

        for zone in zones {
            // このゾーンと指定範囲の重なりを計算
            let overlapStart = max(musicalStart, zone.musicalStart)
            let overlapEnd = min(musicalEnd, zone.musicalEnd)

            if overlapStart < overlapEnd {
                let overlapMusical = overlapEnd - overlapStart
                realDuration += overlapMusical / zone.tempoRatio
            }
        }

        return realDuration
    }

    /// 実時間から楽譜時間へ変換
    public static func realToMusicalTime(_ realTime: Float) -> Float {
        // 1回目かどうかで処理を分岐
        if realTime < firstCycleDuration {
            // 1回目: イントロ休符をスキップ
            return convertRealToMusical(realTime, introSkipped: true)
        } else {
            // 2回目以降: 休符含む
            let timeAfterFirst = realTime - firstCycleDuration
            let cycleTime = timeAfterFirst.truncatingRemainder(dividingBy: normalCycleDuration)
            return convertRealToMusical(cycleTime, introSkipped: false)
        }
    }

    /// 実時間を楽譜時間に変換（テンポゾーンを考慮）
    private static func convertRealToMusical(_ realTimeInCycle: Float, introSkipped: Bool) -> Float {
        let zones = zoneData
        let musicalOffset: Float = introSkipped ? introRestMusical : 0.0

        // イントロスキップ時は、イントロ部分の実時間を差し引いた累積を使う
        var accumulatedReal: Float = 0

        for zone in zones {
            // このゾーンの有効範囲（イントロスキップを考慮）
            let zoneMusicalStart = max(zone.musicalStart, musicalOffset)
            let zoneMusicalEnd = zone.musicalEnd

            if zoneMusicalStart >= zoneMusicalEnd {
                continue  // このゾーンはスキップ対象
            }

            let zoneMusicalDuration = zoneMusicalEnd - zoneMusicalStart
            let zoneRealDuration = zoneMusicalDuration / zone.tempoRatio

            if realTimeInCycle < accumulatedReal + zoneRealDuration {
                // このゾーン内にいる
                let timeInZone = realTimeInCycle - accumulatedReal
                let musicalProgress = timeInZone * zone.tempoRatio
                return zoneMusicalStart + musicalProgress
            }

            accumulatedReal += zoneRealDuration
        }

        // サイクル終了後
        return fullMusicalCycleDuration
    }

    /// 現在の周回番号を取得
    /// - Parameter time: 実時間（秒）
    /// - Returns: 周回番号（0, 1, 2, ...）
    public static func currentCycleIndex(at time: Float) -> Int {
        if time < firstCycleDuration {
            return 0
        } else {
            let timeAfterFirst = time - firstCycleDuration
            return 1 + Int(timeAfterFirst / normalCycleDuration)
        }
    }

    /// 楽譜時間から実時間へ変換（逆変換、1回目用）
    public static func musicalToRealTime(_ musicalTime: Float) -> Float {
        // 1回目の変換のみサポート（TreeChimeのSection 2開始時刻計算用）
        if musicalTime >= introRestMusical {
            return calculateRealDuration(from: introRestMusical, to: musicalTime)
        } else {
            // 休符部分は1回目には存在しない
            return 0
        }
    }

    // MARK: - Helper Methods

    /// 時間から現在の小節番号を取得（1-indexed）
    /// - Parameter time: 実時間（秒）
    /// - Returns: 現在の小節番号（1〜totalBars）
    public static func currentBar(at time: Float) -> Int {
        // 実時間を楽譜時間に変換してから小節を計算
        let musicalTime = realToMusicalTime(time)
        let bar = Int(musicalTime / barDuration) + 1
        return max(1, min(bar, totalBars))
    }

    /// 時間から現在のセクション番号を取得（0-indexed）
    /// - Parameter time: 絶対時間（秒）
    /// - Returns: 現在のセクション番号（0〜5）
    public static func currentSection(at time: Float) -> Int {
        let bar = currentBar(at: time)

        // 逆順で検索して該当セクションを見つける
        for i in stride(from: sectionBars.count - 1, through: 0, by: -1) {
            if bar >= sectionBars[i] {
                return i
            }
        }
        return 0
    }

    /// セクション内の進行度を取得（0.0〜1.0）
    /// - Parameter time: 実時間（秒）
    /// - Returns: セクション内の進行度（スムーズなフェード用）
    public static func sectionProgress(at time: Float) -> Float {
        // 楽譜時間で計算
        let musicalTime = realToMusicalTime(time)
        let section = currentSection(at: time)

        let sectionStartBar = sectionBars[section]
        let sectionStartTime = Float(sectionStartBar - 1) * barDuration

        // 次のセクションの開始時間を計算（楽譜時間）
        let nextSectionStartTime: Float
        if section < sectionBars.count - 1 {
            nextSectionStartTime = Float(sectionBars[section + 1] - 1) * barDuration
        } else {
            nextSectionStartTime = fullMusicalCycleDuration
        }

        let sectionDuration = nextSectionStartTime - sectionStartTime
        let timeInSection = musicalTime - sectionStartTime

        return min(1.0, max(0.0, timeInSection / sectionDuration))
    }

    /// 全体の進行度を取得（0.0〜1.0）
    /// - Parameter time: 絶対時間（秒）
    /// - Returns: サイクル全体の進行度
    public static func overallProgress(at time: Float) -> Float {
        let musicalTime = realToMusicalTime(time)
        return musicalTime / fullMusicalCycleDuration
    }
}
