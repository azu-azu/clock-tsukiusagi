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
            // Signal-based organ drone + harp arpeggios + Jupiter melody with large reverb
            let organSignal = CathedralStillnessSignal.makeSignal()
            let harpSignal = MidnightDropletsSignal.makeSignal()
            let jupiterSignal = JupiterMelodySignal.makeSignal()

            let mixer = FinalMixer()
            mixer.add(organSignal, gain: 1.0)     // オルガンドローン（ベース）
            mixer.add(harpSignal, gain: 0.6)      // ハープアルペジオ（控えめに、メロディを引き立てる）
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

        case .toyPiano:
            // Toy piano chord progression with deep, dreamy reverb
            let signal = PianoSignal.makeSignal()

            // Sub piano (octave-up shimmer layer)
            let subSignal = SubPianoSignal.makeSignal()

            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)        // Main piano
            mixer.add(subSignal, gain: 1.0)     // Sub piano (volume 0.20 internally)

            // Deep reverb for dreamy atmosphere
            let reverb = SchroederReverb(
                roomSize: 1.8,      // Medium-large space
                damping: 0.65,      // Warm tone
                decay: 0.85,        // Long tail for dreamy feel
                mix: 0.45,          // Rich reverb
                predelay: 0.020,    // 20ms initial reflection
                sampleRate: 48000.0
            )
            mixer.addEffect(reverb)

            // Soft limiter for safety
            mixer.addEffect(SoftLimiter(drive: 1.05, ceiling: 0.95))

            let outputNode = FinalMixerOutputNode(mixer: mixer)
            sources.append(outputNode)

            // Add TreeChime overlay (ランダム間隔でシャラララ)
            let treeChime = TreeChime(
                grainRate: 0.15,       // 平均6〜7秒に1回のシャラララ
                grainDuration: 1.2,    // 各粒の余韻（1.2秒）
                brightness: 9000.0     // ペンタトニックより少し高め
            )
            sources.append(treeChime)

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

        case .midnightGnossienne:
            // Satie Gnossienne No.1 melody (Public Domain)
            let signal = GnossienneIntroSignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

            // Dark, mysterious reverb
            let reverb = SchroederReverb(
                roomSize: 2.4,      // Large, dark space
                damping: 0.35,      // Less damping for haunting resonance
                decay: 0.90,        // Very long tail
                mix: 0.50,          // Rich, enveloping reverb
                predelay: 0.035,    // Deeper predelay
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
