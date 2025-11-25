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
    /// - Parameters:
    ///   - preset: The preset to build
    ///   - outputRoute: Current audio output route for frequency optimization
    /// - Returns: Array of AudioSource instances (may include multiple sources for layered presets)
    public static func build(_ preset: PureTonePreset, outputRoute: AudioOutputRoute = .unknown) -> [AudioSource] {
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

        case .treeChimeOnly:
            // AudioSource-based implementation (直接使用、リバーブなし)
            // TODO: Signal-basedに書き直してリバーブを追加する
            let chime = TreeChime(
                grainRate: 1.5,        // シャラララの発生頻度（1秒に1.5回）
                grainDuration: 1.2,    // 各粒の余韻（1.2秒）
                brightness: 8000.0     // 基音周波数
            )
            sources.append(chime)

        case .boomHitOnly:
            // Auto-triggering BoomHit test with route-optimized frequency
            // Output route determines optimal fundamental frequency:
            // - Speaker: 220Hz (iPhone speaker audible range)
            // - Headphones/Bluetooth: 80Hz (true low bass)
            // - Unknown: 150Hz (safe middle ground)
            let fundamental: Double
            switch outputRoute {
            case .speaker:
                fundamental = 220.0  // iPhone スピーカー最適（可聴域で「ズズーン」近似）
            case .headphones, .bluetooth:
                fundamental = 80.0   // 本物の低音「ドゥーン」
            case .unknown:
                fundamental = 150.0  // 安全な中間値
            }

            let boom = AutoTriggerBoomHit(
                triggerRate: 0.33,     // Test: every ~3 seconds
                minInterval: 3.0,      // Minimum 3s between booms
                duration: 3.0,         // 3s boom with falling pitch
                fundamental: fundamental,  // Route-optimized frequency
                pitchDropAmount: 0.25  // 25% pitch drop
            )
            sources.append(boom)

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

        case .gentleFlute:
            // Gentle flute melody with spacious, bright reverb
            let signal = FluteSignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

            // Spacious reverb for concert hall feel
            let reverb = SchroederReverb(
                roomSize: 2.0,      // Large space
                damping: 0.50,      // Brighter tone
                decay: 0.88,        // Long, airy tail
                mix: 0.50,          // Very spacious
                predelay: 0.030,    // 30ms initial reflection
                sampleRate: 48000.0
            )
            mixer.addEffect(reverb)

            // Soft limiter for safety
            mixer.addEffect(SoftLimiter(drive: 1.05, ceiling: 0.95))

            let outputNode = FinalMixerOutputNode(mixer: mixer)
            sources.append(outputNode)

        case .moonlightFlow:
            // Moonlight flow melody with spacious, dreamy reverb
            let signal = MoonlightFlowSignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

            // Deep, majestic reverb for rich moonlight atmosphere
            let reverb = SchroederReverb(
                roomSize: 2.4,      // Larger space (cathedral-like depth)
                damping: 0.35,      // Less damping for richer resonance
                decay: 0.92,        // Longer tail for weight
                mix: 0.60,          // More reverb for depth
                predelay: 0.035,    // Slightly longer for spatial depth
                sampleRate: 48000.0
            )
            mixer.addEffect(reverb)

            // Soft limiter for safety
            mixer.addEffect(SoftLimiter(drive: 1.05, ceiling: 0.95))

            let outputNode = FinalMixerOutputNode(mixer: mixer)
            sources.append(outputNode)

        case .moonlightFlowMidnight:
            // Midnight version with darker, closer atmosphere
            let signal = MoonlightFlowMidnightSignal.makeSignal()
            let mixer = FinalMixer()
            mixer.add(signal, gain: 1.0)

            // Deep, close reverb for rich midnight atmosphere
            let reverb = SchroederReverb(
                roomSize: 2.4,      // Large space (deep night stillness)
                damping: 0.32,      // Less damping for richer, darker resonance
                decay: 0.93,        // Very long tail for heavy presence
                mix: 0.62,          // More reverb for weight and depth
                predelay: 0.012,    // 12ms - dense fog, intimate feeling
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
