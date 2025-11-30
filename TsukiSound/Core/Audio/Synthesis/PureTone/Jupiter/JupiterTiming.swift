//
//  JupiterTiming.swift
//  TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter
//
//  Jupiter楽曲のタイミングとセクション管理
//  他のSignal（OrganDrone, TreeChime）がJupiterの進行度を参照するために使用
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

    // MARK: - Intro Skip (Bar 1 の休符をスキップ)

    /// Bar 1 の休符分をスキップ（楽譜時間で2拍 = 2.0秒）
    /// 楽譜では Bar 1 beat 2.0 から始まるが、再生時は即座に音が出るようにする
    public static let introSkipBeats: Float = 2.0

    /// イントロスキップ量（楽譜時間）
    private static var introSkipMusical: Float { introSkipBeats * beatDuration }

    // MARK: - Tempo Stretch

    /// イントロ部分（ミソラ = Bar 1 beat 2.0 〜 Bar 2 beat 1.0）のテンポ倍率
    /// 2.0 = 2.0倍遅い = 約40BPM相当
    public static let introStretch: Float = 2.0

    /// イントロ部分の楽譜上の長さ（ミソラ = 1.5拍）
    /// Bar 1 beat 2.0, 2.5 (ミソ) + Bar 2 beat 0.0 (ラ) = 1.5拍分
    private static let introMusicalBeats: Float = 1.5
    private static var introMusicalDuration: Float { introMusicalBeats * beatDuration }

    /// Section 0 の残り部分のテンポ倍率（1.25 = 約48BPM相当）
    public static let section0Stretch: Float = 1.25

    /// Section 0 の小節数（Bar 1-4 = 4小節）
    private static let section0Bars: Int = 4

    /// Section 0 の楽譜上の長さ（イントロスキップ後）
    private static var section0MusicalDuration: Float {
        Float(section0Bars) * barDuration - introSkipMusical
    }

    /// イントロ部分の実際の長さ
    private static var introRealDuration: Float {
        introMusicalDuration * introStretch
    }

    /// Section 0 の残り部分（イントロ後〜Bar 4末）の楽譜上の長さ
    private static var section0RestMusicalDuration: Float {
        section0MusicalDuration - introMusicalDuration
    }

    /// Section 0 の残り部分の実際の長さ
    private static var section0RestRealDuration: Float {
        section0RestMusicalDuration * section0Stretch
    }

    /// Section 0 全体の実際の長さ
    private static var section0RealDuration: Float {
        introRealDuration + section0RestRealDuration
    }

    /// Section 1以降の長さ（通常テンポ）
    private static var section1PlusDuration: Float {
        Float(totalBars - section0Bars) * barDuration
    }

    /// 1サイクルの実際の長さ（テンポ伸縮を考慮）
    public static var cycleDuration: Float {
        section0RealDuration + section1PlusDuration
    }

    /// 楽譜上の1サイクルの長さ（イントロスキップ後）
    public static var musicalCycleDuration: Float {
        Float(totalBars) * barDuration - introSkipMusical
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
    /// - イントロ（ミソラ）: 1.5倍遅い
    /// - Section 0 残り: 1.25倍遅い
    /// - Section 1以降: 通常テンポ
    public static func realToMusicalTime(_ realTime: Float) -> Float {
        let localReal = realTime.truncatingRemainder(dividingBy: cycleDuration)

        if localReal < introRealDuration {
            // イントロ部分（ミソラ）: 1.5倍遅い
            return introSkipMusical + localReal / introStretch
        } else if localReal < section0RealDuration {
            // Section 0 残り: 1.25倍遅い
            let introMusicalEnd = introSkipMusical + introMusicalDuration
            return introMusicalEnd + (localReal - introRealDuration) / section0Stretch
        } else {
            // Section 1以降: 通常テンポ
            let section0MusicalEnd = Float(section0Bars) * barDuration
            return section0MusicalEnd + (localReal - section0RealDuration)
        }
    }

    /// 楽譜時間から実時間へ変換（逆変換）
    public static func musicalToRealTime(_ musicalTime: Float) -> Float {
        let introMusicalEnd = introSkipMusical + introMusicalDuration
        let section0MusicalEnd = Float(section0Bars) * barDuration

        // イントロスキップ前の時間は存在しない
        let adjustedMusical: Float
        if musicalTime < introSkipMusical {
            adjustedMusical = musicalTime + musicalCycleDuration
        } else {
            adjustedMusical = musicalTime
        }

        if adjustedMusical < introMusicalEnd {
            // イントロ部分
            return (adjustedMusical - introSkipMusical) * introStretch
        } else if adjustedMusical < section0MusicalEnd {
            // Section 0 残り
            return introRealDuration + (adjustedMusical - introMusicalEnd) * section0Stretch
        } else {
            // Section 1以降
            return section0RealDuration + (adjustedMusical - section0MusicalEnd)
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
        return min(bar, totalBars)
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
            nextSectionStartTime = musicalCycleDuration
        }

        let sectionDuration = nextSectionStartTime - sectionStartTime
        let timeInSection = musicalTime - sectionStartTime

        return min(1.0, max(0.0, timeInSection / sectionDuration))
    }

    /// 全体の進行度を取得（0.0〜1.0）
    /// - Parameter time: 絶対時間（秒）
    /// - Returns: サイクル全体の進行度
    public static func overallProgress(at time: Float) -> Float {
        let localTime = time.truncatingRemainder(dividingBy: cycleDuration)
        return localTime / cycleDuration
    }
}
