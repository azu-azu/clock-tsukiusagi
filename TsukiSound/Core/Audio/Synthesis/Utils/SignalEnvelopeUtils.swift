//
//  SignalEnvelopeUtils.swift
//  TsukiSound
//
//  ノイズ対策済みの共通エンベロープ・クリッピングユーティリティ
//  全てのSignal実装で再利用可能
//

import Foundation

/// Signal生成時のノイズ対策ユーティリティ
public struct SignalEnvelopeUtils {

    // MARK: - Attack Time Guidelines

    /// 推奨アタック時間（周波数帯域別）
    public struct AttackTime {
        /// 高音（500Hz以上）: 30ms
        public static let high: Float = 0.03
        /// 中音（200-500Hz）: 60ms
        public static let mid: Float = 0.06
        /// 低音（200Hz以下）: 120ms
        public static let low: Float = 0.12

        /// 周波数から推奨アタック時間を取得
        public static func recommended(for frequency: Float) -> Float {
            if frequency >= 500 {
                return high
            } else if frequency >= 200 {
                return mid
            } else {
                return low
            }
        }
    }

    // MARK: - Smooth Envelope

    /// 滑らかなエンベロープ（クリックノイズ防止）
    ///
    /// - Parameters:
    ///   - t: 音の開始からの経過時間（秒）
    ///   - duration: 音の全体の長さ（秒）
    ///   - attack: アタック時間（秒）- 低音ほど長くする
    ///   - decay: ディケイ時定数（秒）
    ///   - releaseTime: リリース時間（秒）デフォルト0.15
    /// - Returns: エンベロープ値（0.0〜1.0）
    public static func smoothEnvelope(
        t: Float,
        duration: Float,
        attack: Float,
        decay: Float,
        releaseTime: Float = 0.15
    ) -> Float {
        // アタック（sin²カーブ = 非常に滑らか）
        if t < attack {
            let p = t / attack
            let s = sin(p * Float.pi * 0.5)
            return s * s
        }

        // リリース（終了前に滑らかにフェードアウト）
        let releaseStart = duration - releaseTime

        if t > releaseStart && duration > releaseTime {
            let decayEnv = exp(-(t - attack) / decay)
            let releaseProgress = (t - releaseStart) / releaseTime
            let releaseCurve = cos(releaseProgress * Float.pi * 0.5)
            return decayEnv * releaseCurve * releaseCurve
        }

        // 通常のディケイ（指数減衰）
        return exp(-(t - attack) / decay)
    }

    /// シンプルなエンベロープ（アタック + ディケイのみ）
    ///
    /// リリース処理が不要な場合に使用
    public static func simpleEnvelope(
        t: Float,
        attack: Float,
        decay: Float
    ) -> Float {
        if t < attack {
            let p = t / attack
            let s = sin(p * Float.pi * 0.5)
            return s * s
        }
        return exp(-(t - attack) / decay)
    }

    // MARK: - Soft Clipping

    /// ソフトクリッピング（急激な振幅変化を防止）
    ///
    /// 複数の音が重なった時のノイズを防ぐ
    ///
    /// - Parameters:
    ///   - x: 入力値
    ///   - threshold: クリッピング開始の閾値（デフォルト0.8）
    ///   - ratio: 閾値超過時の圧縮比率（デフォルト0.2）
    /// - Returns: クリッピング後の値
    public static func softClip(
        _ x: Float,
        threshold: Float = 0.8,
        ratio: Float = 0.2
    ) -> Float {
        if x > threshold {
            return threshold + (x - threshold) * ratio
        } else if x < -threshold {
            return -threshold + (x + threshold) * ratio
        }
        return x
    }

    // MARK: - Pure Sine Wave

    /// 純粋なサイン波を生成（倍音なし = ノイズ最小）
    ///
    /// - Parameters:
    ///   - frequency: 周波数（Hz）
    ///   - t: 時間（秒）
    /// - Returns: サイン波の値（-1.0〜1.0）
    public static func pureSine(frequency: Float, t: Float) -> Float {
        return sin(2 * Float.pi * frequency * t)
    }

    /// 倍音付きサイン波（音色を豊かにする場合）
    ///
    /// 倍音を加える場合は音量を十分下げること
    ///
    /// - Parameters:
    ///   - frequency: 基音の周波数（Hz）
    ///   - t: 時間（秒）
    ///   - harmonics: 倍音の倍率と音量のペア配列 [(倍率, 音量), ...]
    /// - Returns: 合成波の値
    public static func harmonicSine(
        frequency: Float,
        t: Float,
        harmonics: [(multiplier: Float, amplitude: Float)] = [(2, 0.05), (3, 0.02)]
    ) -> Float {
        var v = sin(2 * Float.pi * frequency * t)  // 基音

        for harmonic in harmonics {
            v += sin(2 * Float.pi * frequency * harmonic.multiplier * t) * harmonic.amplitude
        }

        return v
    }
}
