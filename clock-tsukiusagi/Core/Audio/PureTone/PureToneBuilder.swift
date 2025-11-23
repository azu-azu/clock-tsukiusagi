//
//  PureToneBuilder.swift
//  clock-tsukiusagi
//
//  Builder for pure tone audio sources
//

import Foundation

/// Builder for constructing pure tone audio sources from presets
public struct PureToneBuilder {

    /// Build audio sources for a given pure tone preset
    /// - Parameter preset: The preset to build
    /// - Returns: Array of AudioSource instances (may include multiple sources for layered presets)
    public static func build(_ preset: PureTonePreset) -> [AudioSource] {
        var sources: [AudioSource] = []

        switch preset {
        case .pentatonicChime:
            // Signal-based implementation with reverb effect
            let signal = PentatonicChimeSignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

            // Add reverb effect (same as NaturalSound was using)
            let reverb = SchroederReverb(
                roomSize: 1.4,
                damping: 0.45,
                decay: 0.7,
                mix: 0.25,
                predelay: 0.02,
                sampleRate: 48000.0
            )
            mixer.addEffect(reverb)

            let outputNode = FinalMixerOutputNode(mixer: mixer)
            sources.append(outputNode)

            // Add TreeChime overlay (ランダム間隔でシャラララ)
            let treeChime = TreeChime(
                grainRate: 0.15,       // 平均6〜7秒に1回のシャラララ
                grainDuration: 1.2,    // 各粒の余韻（1.2秒）
                brightness: 9000.0     // ペンタトニックより少し高め
            )
            sources.append(treeChime)

        case .cathedralStillness:
            // Signal-based organ drone + harp arpeggios with large reverb
            let organSignal = CathedralStillnessSignal.makeSignal()
            let harpSignal = MidnightDropletsSignal.makeSignal()

            let mixer = FinalMixer()
            mixer.add(organSignal, gain: 1.0)     // オルガンドローン
            mixer.add(harpSignal, gain: 0.8)      // ハープアルペジオ（少し控えめ）

            // Large reverb for cathedral atmosphere (3s decay)
            let reverb = SchroederReverb(
                roomSize: 2.2,
                damping: 0.35,
                decay: 0.88,
                mix: 0.55,
                predelay: 0.04,
                sampleRate: 48000.0
            )
            mixer.addEffect(reverb)

            let outputNode = FinalMixerOutputNode(mixer: mixer)
            sources.append(outputNode)

        case .midnightDroplets:
            // Signal-based arpeggio harp with rich, long reverb
            let signal = MidnightDropletsSignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

            // Rich reverb for harp resonance with long tail
            let reverb = SchroederReverb(
                roomSize: 2.0,      // より大きな空間（1.6 → 2.0）
                damping: 0.35,      // 減衰を抑えて響きを残す（0.5 → 0.35）
                decay: 0.85,        // より長い残響（0.75 → 0.85）
                mix: 0.50,          // リバーブ成分を増やす（0.35 → 0.50）
                predelay: 0.030,    // わずかに遅延を増やす
                sampleRate: 48000.0
            )
            mixer.addEffect(reverb)

            let outputNode = FinalMixerOutputNode(mixer: mixer)
            sources.append(outputNode)

        case .treeChimeOnly:
            // AudioSource-based implementation (直接使用、リバーブなし)
            // TODO: Signal-basedに書き直してリバーブを追加する
            let chime = TreeChime(
                grainRate: 1.5,        // シャラララの発生頻度（1秒に1.5回）
                grainDuration: 1.2,    // 各粒の余韻（1.2秒）
                brightness: 8000.0     // 基音周波数
            )
            sources.append(chime)
        }

        return sources
    }
}
