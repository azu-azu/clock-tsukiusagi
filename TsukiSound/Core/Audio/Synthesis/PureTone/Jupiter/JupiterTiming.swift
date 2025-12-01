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
//  - Section 0 (Bar 1-4): テンポ0.7倍（ゆったりアカペラ風）
//  - Section 1 (Bar 5-8): テンポ0.9倍（やや遅め）
//  - Section 2 (Bar 9-12): テンポ1.0倍（通常）
//  - Section 3 (Bar 13-16): テンポ1.1倍（やや速め）
//  - Section 4 (Bar 17-20): テンポ1.2倍（トランペット）
//  - Section 5 (Bar 21-25): テンポ1.3倍（クラリネット、盛り上がり）
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

    // MARK: - Tempo Stretch (Section-based)

    /// Section 0のテンポ倍率（0.7 = 30%遅い、ゆったりアカペラ風）
    public static let section0TempoRatio: Float = 0.7

    /// Section 1のテンポ倍率（0.9 = 10%遅い）
    public static let section1TempoRatio: Float = 0.9

    /// Section 3のテンポ倍率（1.1 = 10%速い）
    public static let section3TempoRatio: Float = 1.1

    /// Section 4のテンポ倍率（1.2 = 20%速い、トランペット）
    public static let section4TempoRatio: Float = 1.2

    /// Section 5のテンポ倍率（1.3 = 30%速い、クライマックス）
    public static let section5TempoRatio: Float = 1.3

    /// Section 0の楽譜上の長さ（Bar 1-4 = 4小節 × 3拍）
    private static var section0MusicalDuration: Float {
        Float(sectionBars[1] - sectionBars[0]) * barDuration  // 12拍
    }

    /// Section 1の楽譜上の長さ（Bar 5-8 = 4小節 × 3拍）
    private static var section1MusicalDuration: Float {
        Float(sectionBars[2] - sectionBars[1]) * barDuration  // 12拍
    }

    /// Section 2の楽譜上の長さ（Bar 9-12 = 4小節 × 3拍）
    private static var section2MusicalDuration: Float {
        Float(sectionBars[3] - sectionBars[2]) * barDuration  // 12拍
    }

    /// Section 3の楽譜上の長さ（Bar 13-16 = 4小節 × 3拍）
    private static var section3MusicalDuration: Float {
        Float(sectionBars[4] - sectionBars[3]) * barDuration  // 12拍
    }

    /// Section 4の楽譜上の長さ（Bar 17-20 = 4小節 × 3拍）
    private static var section4MusicalDuration: Float {
        Float(sectionBars[5] - sectionBars[4]) * barDuration  // 12拍
    }

    /// Section 5の楽譜上の長さ（Bar 21-25 = 5小節 × 3拍）
    private static var section5MusicalDuration: Float {
        Float(totalBars - sectionBars[5] + 1) * barDuration  // 15拍
    }

    /// Section 0の実時間での長さ（テンポ伸縮後）
    private static var section0RealDuration: Float {
        section0MusicalDuration / section0TempoRatio
    }

    /// Section 1の実時間での長さ（テンポ伸縮後）
    private static var section1RealDuration: Float {
        section1MusicalDuration / section1TempoRatio
    }

    /// Section 3の実時間での長さ（テンポ伸縮後）
    private static var section3RealDuration: Float {
        section3MusicalDuration / section3TempoRatio
    }

    /// Section 4の実時間での長さ（テンポ伸縮後）
    private static var section4RealDuration: Float {
        section4MusicalDuration / section4TempoRatio
    }

    /// Section 5の実時間での長さ（テンポ伸縮後）
    private static var section5RealDuration: Float {
        section5MusicalDuration / section5TempoRatio
    }

    // MARK: - Intro Skip (1回目だけ適用)

    /// Bar 1 の休符分（楽譜時間で2拍 = 2.0秒）
    /// 1回目: スキップして即メロディ開始
    /// 2回目以降: スキップせず、ドローンの「くるくる」が聞こえる
    public static let introRestBeats: Float = 2.0

    /// イントロ休符の長さ（楽譜時間）
    private static var introRestMusical: Float { introRestBeats * beatDuration }

    // MARK: - Cycle Duration

    /// 楽譜上の1サイクルの長さ（休符含む全25小節）
    public static var fullMusicalCycleDuration: Float {
        Float(totalBars) * barDuration  // 25 * 3 = 75秒
    }

    /// テンポ伸縮による時間変化（遅いセクションで増加、速いセクションで減少）
    private static var tempoStretchExtra: Float {
        let section0Extra = section0RealDuration - section0MusicalDuration
        let section1Extra = section1RealDuration - section1MusicalDuration
        // Section 2は通常テンポ（1.0倍）なのでExtra = 0
        let section3Extra = section3RealDuration - section3MusicalDuration
        let section4Extra = section4RealDuration - section4MusicalDuration
        let section5Extra = section5RealDuration - section5MusicalDuration
        return section0Extra + section1Extra + section3Extra + section4Extra + section5Extra
    }

    /// 1回目のサイクル長（イントロ休符をスキップ + テンポ伸縮）
    public static var firstCycleDuration: Float {
        fullMusicalCycleDuration - introRestMusical + tempoStretchExtra
    }

    /// 2回目以降のサイクル長（休符含む + テンポ伸縮）
    public static var normalCycleDuration: Float {
        fullMusicalCycleDuration + tempoStretchExtra
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

    /// 実時間から楽譜時間へ変換
    /// - 1回目: イントロ休符をスキップ（即メロディ開始）+ Section 0テンポ伸縮
    /// - 2回目以降: 休符含む + Section 0テンポ伸縮
    public static func realToMusicalTime(_ realTime: Float) -> Float {
        // 1回目かどうかで処理を分岐
        if realTime < firstCycleDuration {
            // 1回目: イントロ休符をスキップ
            // 実時間0 → 楽譜時間2.0（休符の後）からスタート
            return convertWithTempoStretch(realTime, introSkipped: true)
        } else {
            // 2回目以降: 休符含む
            let timeAfterFirst = realTime - firstCycleDuration
            let cycleTime = timeAfterFirst.truncatingRemainder(dividingBy: normalCycleDuration)
            return convertWithTempoStretch(cycleTime, introSkipped: false)
        }
    }

    /// テンポ伸縮を考慮して実時間→楽譜時間に変換
    /// - Parameters:
    ///   - realTimeInCycle: サイクル内の実時間
    ///   - introSkipped: イントロ休符がスキップされているか（1回目のみtrue）
    private static func convertWithTempoStretch(_ realTimeInCycle: Float, introSkipped: Bool) -> Float {
        // 各セクションの楽譜上の境界位置
        let section0MusicalStart: Float = introSkipped ? introRestMusical : 0.0
        let section0MusicalEnd: Float = Float(sectionBars[1] - 1) * barDuration   // Bar 5 = 12.0
        let section1MusicalEnd: Float = Float(sectionBars[2] - 1) * barDuration   // Bar 9 = 24.0
        let section2MusicalEnd: Float = Float(sectionBars[3] - 1) * barDuration   // Bar 13 = 36.0
        let section3MusicalEnd: Float = Float(sectionBars[4] - 1) * barDuration   // Bar 17 = 48.0
        let section4MusicalEnd: Float = Float(sectionBars[5] - 1) * barDuration   // Bar 21 = 60.0
        let section5MusicalEnd: Float = fullMusicalCycleDuration                   // 75.0

        // 1回目はイントロ休符分だけSection 0が短い
        let section0RealEndForCycle: Float = introSkipped
            ? (section0MusicalEnd - section0MusicalStart) / section0TempoRatio
            : section0RealDuration

        // 各セクションの実時間での累積終了位置
        let section1RealEnd: Float = section0RealEndForCycle + section1RealDuration
        let section2RealEnd: Float = section1RealEnd + section2MusicalDuration  // Section 2は通常テンポ
        let section3RealEnd: Float = section2RealEnd + section3RealDuration
        let section4RealEnd: Float = section3RealEnd + section4RealDuration
        let section5RealEnd: Float = section4RealEnd + section5RealDuration

        if realTimeInCycle < section0RealEndForCycle {
            // Section 0内: テンポ0.7倍（遅い）
            let realProgress = realTimeInCycle / section0RealEndForCycle
            let musicalDuration = section0MusicalEnd - section0MusicalStart
            return section0MusicalStart + realProgress * musicalDuration
        } else if realTimeInCycle < section1RealEnd {
            // Section 1内: テンポ0.9倍
            let timeInSection = realTimeInCycle - section0RealEndForCycle
            let realProgress = timeInSection / section1RealDuration
            return section0MusicalEnd + realProgress * section1MusicalDuration
        } else if realTimeInCycle < section2RealEnd {
            // Section 2内: 通常テンポ（1.0倍）
            let timeInSection = realTimeInCycle - section1RealEnd
            return section1MusicalEnd + timeInSection
        } else if realTimeInCycle < section3RealEnd {
            // Section 3内: テンポ1.1倍
            let timeInSection = realTimeInCycle - section2RealEnd
            let realProgress = timeInSection / section3RealDuration
            return section2MusicalEnd + realProgress * section3MusicalDuration
        } else if realTimeInCycle < section4RealEnd {
            // Section 4内: テンポ1.2倍
            let timeInSection = realTimeInCycle - section3RealEnd
            let realProgress = timeInSection / section4RealDuration
            return section3MusicalEnd + realProgress * section4MusicalDuration
        } else if realTimeInCycle < section5RealEnd {
            // Section 5内: テンポ1.3倍
            let timeInSection = realTimeInCycle - section4RealEnd
            let realProgress = timeInSection / section5RealDuration
            return section4MusicalEnd + realProgress * section5MusicalDuration
        } else {
            // サイクル終了後（念のため）
            return section5MusicalEnd
        }
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
            return musicalTime - introRestMusical
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
