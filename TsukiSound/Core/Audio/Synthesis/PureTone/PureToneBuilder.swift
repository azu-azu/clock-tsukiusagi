//
//  PureToneBuilder.swift
//  TsukiSound
//
//  Builder for pure tone audio sources
//

import Foundation

/// Builder for constructing pure tone audio sources from presets
public struct PureToneBuilder {

    /// Build audio sources for a given pure tone preset
    /// - Parameters:
    ///   - preset: The preset to build
    ///   - outputRoute: Current audio output route for frequency optimization
    /// - Returns: Array of AudioSource instances (may include multiple sources for layered presets)
    public static func build(_ preset: PureTonePreset, outputRoute: AudioOutputRoute = .unknown) -> [AudioSource] {
        var sources: [AudioSource] = []

        switch preset {
        case .cathedralStillness:
            // Signal-based organ drone + Jupiter melody with large reverb
            let organSignal = CathedralStillnessSignal.makeSignal()
            let jupiterSignal = JupiterMelodySignal.makeSignal()

            let mixer = FinalMixer()
            mixer.add(organSignal, gain: 1.0)     // オルガンドローン（ベース）
            mixer.add(jupiterSignal, gain: 0.7)   // Jupiterメロディ（メインテーマ）

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

        case .moonlitGymnopedie:
            // Satie Gymnopédie No.1 melody (Public Domain)
            let signal = GymnopedieMainMelodySignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

            // Spacious, moonlit reverb
            let reverb = SchroederReverb(
                roomSize: 2.2,      // Large, open space
                damping: 0.40,      // Moderate damping for clarity
                decay: 0.85,        // Long tail for depth
                mix: 0.45,          // Rich reverb
                predelay: 0.030,    // Spacious predelay
                sampleRate: 48000.0
            )
            mixer.addEffect(reverb)

            // Soft limiter for safety
            mixer.addEffect(SoftLimiter(drive: 1.05, ceiling: 0.95))

            let outputNode = FinalMixerOutputNode(mixer: mixer)
            sources.append(outputNode)

        }

        return sources
    }
}
