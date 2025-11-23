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
            // Signal-based organ drone with large reverb
            let signal = CathedralStillnessSignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

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
            // Signal-based arpeggio harp with medium reverb
            let signal = MidnightDropletsSignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

            // Medium reverb for harp resonance
            let reverb = SchroederReverb(
                roomSize: 1.6,
                damping: 0.5,
                decay: 0.75,
                mix: 0.35,
                predelay: 0.025,
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
