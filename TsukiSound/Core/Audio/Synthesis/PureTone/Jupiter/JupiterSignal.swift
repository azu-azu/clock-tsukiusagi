//
//  JupiterSignal.swift
//  TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter
//
//  Jupiter Melody - Holst's "The Planets" Jupiter theme in C Major
//  Organ-style melody with ASR envelope for cathedral atmosphere
//
//  Refactored to Gymnopédie-style (startBar/startBeat) for consistency
//
//  ## 音色変化
//  楽譜位置に基づいて音色が変化
//  - Bar 1 (beat 0-1): Gymnopédie風メロディ音色（純粋サイン波 + 微細デチューン）
//  - Bar 2 beat 1.0〜: オルガン音色（倍音 + ビブラート）へクロスフェード
//  - Bar 21 beat 2.0〜: クラリネット音色（奇数倍音）
//

import Foundation

/// JupiterMelodySignal - Holst's Jupiter theme adapted for organ
///
/// Produces a majestic, solemn melody based on Holst's "Jupiter" (public domain).
/// Transposed from F Major to C Major.
///
/// Characteristics:
/// - Gymnopédie-style note positioning (startBar/startBeat)
/// - Bar 1: Gymnopédie-style melody (pure sine + subtle detune, long attack/release)
/// - Bar 2+: Crossfade to organ, then full organ sound
/// - Bar 21 beat 2.0+: Clarinet timbre (odd harmonics) for climax
///
/// Legal: Holst's "The Planets" (1918) is public domain (composer died 1934, >70 years).
public struct JupiterMelodySignal {

    /// Create Jupiter melody signal
    /// - Returns: Signal generating the Jupiter melody
    public static func makeSignal() -> Signal {
        let generator = JupiterMelodyGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

// MARK: - Private Implementation

private final class JupiterMelodyGenerator {

    // MARK: - Melody Data (external)

    let melody = JupiterMelodyData.melody
    let totalBars = JupiterMelodyData.totalBars

    // MARK: - Timing Constants

    /// Beat duration from melody data (60 BPM = 1.0s per beat)
    let beat: Float = jupiterBeatDuration

    /// Bar duration (3/4 time = 3 beats per bar)
    lazy var barDuration: Float = beat * 3

    /// Musical cycle duration (楽譜上の全長 = 25小節 × 3拍)
    /// ノート位置計算に使用（楽譜ベース）
    lazy var fullMusicalCycleDuration: Float = Float(totalBars) * barDuration

    // MARK: - Sound Design (Organ Characteristics)

    /// Organ-style harmonics with warm foundation
    let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0, 6.0]

    /// Harmonic amplitudes: warm, full organ tone
    let harmonicAmps: [Float] = [1.0, 0.45, 0.25, 0.12, 0.03]

    // MARK: - Clarinet Sound Parameters (Section 5)
    //
    // クラリネットの特徴: 奇数倍音のみが強い（閉管楽器の特性）
    // 偶数倍音が抑制されることで独特の「空洞感」のある音色

    /// Clarinet harmonics: odd harmonics only (characteristic of closed-pipe instruments)
    let clarinetHarmonics: [Float] = [1.0, 3.0, 5.0, 7.0, 9.0]

    /// Clarinet harmonic amplitudes: 1/n rolloff for natural clarinet tone
    let clarinetHarmonicAmps: [Float] = [1.0, 0.33, 0.2, 0.14, 0.11]

    // MARK: - Tremulant (Vibrato)

    /// Vibrato rate: 4Hz (typical for organ tremulant)
    let vibratoRate: Float = 4.0

    /// Vibrato depth: very subtle for stable, gentle warmth
    let vibratoDepth: Float = 0.001

    // MARK: - Envelope Parameters (ASR - Attack-Sustain-Release)

    /// Attack time: fast enough for 16th notes while still smooth
    let attackTime: Float = 0.15   // 150ms

    /// Release time: melody-style (per _guide-audio-smoothness.md)
    let releaseTime: Float = 0.18  // 180ms release (within 0.1-0.2s recommendation)

    // Note: Breath duration is now defined in JupiterBreath enum
    // - .short = 80ms (フレーズ内の軽い息継ぎ)
    // - .long  = 150ms (フレーズ間のしっかりした息継ぎ)

    /// Master gain for balance with other layers
    /// Reduced to prevent clipping when notes overlap
    /// At most 2 notes overlap, so 0.22 * 2 = 0.44 < 0.8 (softClip threshold)
    let masterGain: Float = 0.22

    /// High frequency gain reduction threshold (Hz)
    /// Frequencies above this will be progressively reduced
    let highFreqThreshold: Float = 600.0
    let highFreqMax: Float = JupiterPitch.C6.rawValue

    /// Transpose factor: -2 semitones for warmer sound
    /// 2^(-2/12) ≈ 0.8909
    let transposeFactor: Float = pow(2.0, -2.0 / 12.0)

    // MARK: - Gymnopédie Melody Sound Parameters (Section 0)
    //
    // 純粋サイン波 + 微細デチューン（0.1Hz）
    // 長いアタック（350ms）・リリース（500ms）で音が柔らかくつながる

    /// Gymnopédie-style attack: longer for smooth note transitions
    let gymnoAttackTime: Float = 0.35   // 350ms (longer to reduce beat at transitions)

    /// Gymnopédie-style decay: long, elegant decay
    let gymnoDecayTime: Float = 4.5     // 4.5s decay (like Gymnopédie melody)

    /// Gymnopédie release: longer than organ for smooth legato connection
    let gymnoReleaseTime: Float = 0.5   // 500ms release (organ is 180ms)

    /// Subtle detune for gentle warmth (Gymnopédie uses 0.2Hz, this is half)
    let gymnoDetuneHz: Float = 0.1

    /// Gymnopédie melody gain
    let gymnoGain: Float = 0.28

    // MARK: - Sample Generation

    // MARK: - Timbre Transition Constants

    /// クロスフェード開始位置（楽譜時間）: Bar 2, Beat 1.0
    let crossfadeStartBar: Int = 2
    let crossfadeStartBeat: Float = 1.0

    /// クロスフェード期間（拍数）: 2拍かけて徐々に変化
    let crossfadeDurationBeats: Float = 2.0

    // MARK: - Section 1 Gymnopédie Echo (無効化)

    /// Section 1でGymnopédie音色に戻る範囲（現在無効化：全てOrgan）
    /// 範囲を0にしてGymnopédie Echoを無効化
    let gymnoEchoStartBar: Int = 0
    let gymnoEchoStartBeat: Float = 0.0
    let gymnoEchoEndBar: Int = 0
    let gymnoEchoEndBeat: Float = 0.0

    // MARK: - Clarinet Start (Section 5)

    /// クラリネット音色の開始位置
    /// Bar 21 beat 2.0 から（🌠 sec5 マーカーの後）
    let clarinetStartBar: Int = 21
    let clarinetStartBeat: Float = 2.0

    func sample(at t: Float) -> Float {
        // 実時間を楽譜時間に変換（イントロスキップを反映）
        let musicalTime = JupiterTiming.realToMusicalTime(t)
        let local = musicalTime.truncatingRemainder(dividingBy: fullMusicalCycleDuration)

        // セクション情報（クライマックス判定用）
        let section = JupiterTiming.currentSection(at: t)
        let sectionProgress = JupiterTiming.sectionProgress(at: t)

        // クロスフェード開始時刻（楽譜時間）
        let crossfadeStartTime = Float(crossfadeStartBar - 1) * barDuration + crossfadeStartBeat * beat
        let crossfadeEndTime = crossfadeStartTime + crossfadeDurationBeats * beat

        // Gymnopédie Echo範囲（現在無効化）
        let gymnoEchoStart = Float(gymnoEchoStartBar - 1) * barDuration + gymnoEchoStartBeat * beat
        let gymnoEchoEnd = Float(gymnoEchoEndBar - 1) * barDuration + gymnoEchoEndBeat * beat

        // クラリネット開始位置（楽譜時間）: Bar 21 beat 2.0
        let clarinetStart = Float(clarinetStartBar - 1) * barDuration + clarinetStartBeat * beat

        // 現在の音色ブレンド比率を計算（楽譜位置ベース）
        let organBlend: Float
        if local < crossfadeStartTime {
            // Bar 1: 純粋Gymnopédie
            organBlend = 0.0
        } else if local < crossfadeEndTime {
            // クロスフェード中
            organBlend = (local - crossfadeStartTime) / (crossfadeDurationBeats * beat)
        } else {
            // Bar 2 beat 3.0以降: 純粋オルガン
            organBlend = 1.0
        }

        var output: Float = 0

        for note in melody {
            let noteStart = Float(note.startBar - 1) * barDuration + note.startBeat * beat
            let noteDur = note.durBeats * beat

            // Calculate effective duration (shortened by breath amount)
            let breathAmount = note.breath.rawValue
            let effectiveDur = breathAmount > 0 ? max(noteDur - breathAmount, attackTime) : noteDur

            // Note is active during its effective duration + release tail
            // Gymnopédie Echo判定（activeReleaseTime計算用）
            let isGymnoEchoNote = noteStart >= gymnoEchoStart && noteStart < gymnoEchoEnd
            // Gymno Echo直前のノート判定（Organだが長いリリースで余韻を残す）
            let noteEnd = noteStart + noteDur
            let isPreGymnoEchoNote = noteEnd > gymnoEchoStart && noteStart < gymnoEchoStart
            // Gymnopédieが混じっている間、Gymno Echoノート、またはその直前のノートは長いリリース
            let activeReleaseTime = (organBlend < 1.0 || isGymnoEchoNote || isPreGymnoEchoNote) ? gymnoReleaseTime : releaseTime
            if local >= noteStart && local < noteStart + effectiveDur + activeReleaseTime {
                let dt = local - noteStart
                let transposedFreq = note.freq * transposeFactor

                // === 楽譜位置ベースの音色ブレンド ===

                // Gymnopédie Echo判定（現在無効化）
                let isGymnoEcho = noteStart >= gymnoEchoStart && noteStart < gymnoEchoEnd

                if organBlend == 0.0 || isGymnoEcho {
                    // 純粋Gymnopédie（Bar 1）
                    let gymnoEnv = calculateGymnopedieEnvelope(time: dt, duration: effectiveDur)
                    let v = generateGymnopedieVoice(freq: transposedFreq, t: t)
                    output += v * gymnoEnv * gymnoGain
                } else if organBlend < 1.0 {
                    // クロスフェード中
                    let gymnoFade = 1.0 - organBlend
                    let organFade = organBlend

                    // Gymnopédie voice
                    let gymnoEnv = calculateGymnopedieEnvelope(time: dt, duration: effectiveDur)
                    let gymnoV = generateGymnopedieVoice(freq: transposedFreq, t: t)

                    // Organ voice
                    let organEnv = calculateASREnvelope(time: dt, duration: effectiveDur, release: activeReleaseTime)
                    let gainReduction = calculateHighFreqReduction(freq: transposedFreq)
                    let organV = generateSingleVoice(freq: transposedFreq, t: t)

                    output += gymnoV * gymnoEnv * gymnoGain * gymnoFade
                    output += organV * organEnv * gainReduction * masterGain * organFade
                } else if noteStart < clarinetStart {
                    // 通常のオルガン音色（Bar 21 beat 2.0 まで）
                    let env = calculateASREnvelope(time: dt, duration: effectiveDur, release: activeReleaseTime)
                    let gainReduction = calculateHighFreqReduction(freq: transposedFreq)
                    let v = generateSingleVoice(freq: transposedFreq, t: t)
                    output += v * env * gainReduction * masterGain
                } else {
                    // クラリネット音色（Bar 21 beat 2.0 から）
                    let env = calculateASREnvelope(time: dt, duration: effectiveDur, release: activeReleaseTime)
                    let gainReduction = calculateHighFreqReduction(freq: transposedFreq)
                    let v = generateClarinetVoice(freq: transposedFreq, t: t)

                    // 前半80%はクライマックス（1.1倍）、後半20%でフェードアウト
                    let climaxGain: Float
                    if sectionProgress < 0.8 {
                        climaxGain = 1.1
                    } else {
                        let fadeProgress = (sectionProgress - 0.8) / 0.2
                        let c = cos(fadeProgress * Float.pi * 0.5)
                        climaxGain = 1.1 * c * c
                    }
                    output += v * env * gainReduction * masterGain * climaxGain
                }
            }
        }

        return SignalEnvelopeUtils.softClip(output)
    }

    // MARK: - ASR Envelope

    /// Calculate ASR (Attack-Sustain-Release) envelope for organ-style sound
    /// Uses sin² for attack and cos² for release (per _guide-audio-smoothness.md)
    /// - Parameters:
    ///   - time: Time since note start
    ///   - duration: Note duration in seconds
    ///   - release: Release time in seconds (defaults to releaseTime)
    /// - Returns: Envelope value (0.0 to 1.0)
    private func calculateASREnvelope(time: Float, duration: Float, release: Float? = nil) -> Float {
        let actualRelease = release ?? releaseTime

        // Attack phase: sin² curve
        if time < attackTime {
            let progress = time / attackTime
            let s = sin(progress * Float.pi * 0.5)
            return s * s
        }

        // Sustain phase: full volume until note ends
        if time < duration {
            return 1.0
        }

        // Release phase: cos² curve
        let releaseProgress = (time - duration) / actualRelease
        if releaseProgress < 1.0 {
            let c = cos(releaseProgress * Float.pi * 0.5)
            return c * c
        }

        return 0.0
    }

    // MARK: - Tone Generation

    /// Generate a single organ voice with harmonics and vibrato
    /// Uses Double precision internally to prevent floating-point errors
    private func generateSingleVoice(freq: Float, t: Float) -> Float {
        let tDouble = Double(t)
        let twoPiDouble = Double.pi * 2.0
        let vibratoRateDouble = Double(vibratoRate)
        let vibratoDepthDouble = Double(vibratoDepth)

        // Vibrato: gentle phase offset (same for all harmonics)
        let vibrato = sin(twoPiDouble * vibratoRateDouble * tDouble) * vibratoDepthDouble

        var signal: Double = 0.0

        for (harmonicRatio, harmonicAmp) in zip(harmonics, harmonicAmps) {
            let hFreqDouble = Double(freq * harmonicRatio)
            let harmonicAmpDouble = Double(harmonicAmp)

            // Calculate phase and wrap to prevent precision loss
            let rawPhase = hFreqDouble * tDouble
            let wrappedPhase = rawPhase - floor(rawPhase)

            // Add vibrato as uniform phase offset
            let phase = twoPiDouble * (wrappedPhase + vibrato)

            signal += sin(phase) * harmonicAmpDouble
        }

        signal /= Double(harmonics.count)
        return Float(signal)
    }

    /// Generate clarinet voice with odd harmonics only
    /// Characteristic hollow sound due to suppressed even harmonics
    private func generateClarinetVoice(freq: Float, t: Float) -> Float {
        let tDouble = Double(t)
        let twoPiDouble = Double.pi * 2.0
        let vibratoRateDouble = Double(vibratoRate)
        let vibratoDepthDouble = Double(vibratoDepth)

        // Vibrato: gentle phase offset (same as organ)
        let vibrato = sin(twoPiDouble * vibratoRateDouble * tDouble) * vibratoDepthDouble

        var signal: Double = 0.0

        for (harmonicRatio, harmonicAmp) in zip(clarinetHarmonics, clarinetHarmonicAmps) {
            let hFreqDouble = Double(freq * harmonicRatio)
            let harmonicAmpDouble = Double(harmonicAmp)

            // Calculate phase and wrap to prevent precision loss
            let rawPhase = hFreqDouble * tDouble
            let wrappedPhase = rawPhase - floor(rawPhase)

            // Add vibrato as uniform phase offset
            let phase = twoPiDouble * (wrappedPhase + vibrato)

            signal += sin(phase) * harmonicAmpDouble
        }

        signal /= Double(clarinetHarmonics.count)
        return Float(signal)
    }

    // MARK: - Gymnopédie Envelope & Voice (Section 0)

    /// Calculate Gymnopédie-style ADR envelope (Attack-Decay-Release)
    /// Smooth attack, natural decay, and long release for legato connection
    private func calculateGymnopedieEnvelope(time: Float, duration: Float) -> Float {
        // Attack phase: sin² curve for smooth entrance
        if time < gymnoAttackTime {
            let progress = time / gymnoAttackTime
            let s = sin(progress * Float.pi * 0.5)
            return s * s
        }

        // Sustain/Decay phase: exponential decay during note duration
        if time < duration {
            let decayProgress = (time - gymnoAttackTime)
            return exp(-decayProgress / gymnoDecayTime)
        }

        // Release phase: long cos² curve for smooth legato connection
        let releaseProgress = (time - duration) / gymnoReleaseTime
        if releaseProgress < 1.0 {
            // Get the envelope value at the end of the note
            let envAtEnd = exp(-(duration - gymnoAttackTime) / gymnoDecayTime)
            let c = cos(releaseProgress * Float.pi * 0.5)
            return envAtEnd * c * c
        }

        return 0.0
    }

    /// Generate Gymnopédie-style voice with subtle detune
    /// Gentle warmth with minimal vibrato for a cappella feel
    private func generateGymnopedieVoice(freq: Float, t: Float) -> Float {
        // 控えめなデチューン・レイヤー（3つのサイン波）
        let v1 = SignalEnvelopeUtils.pureSine(frequency: freq, t: t)                  // Center
        let v2 = SignalEnvelopeUtils.pureSine(frequency: freq + gymnoDetuneHz, t: t)  // +Detune
        let v3 = SignalEnvelopeUtils.pureSine(frequency: freq - gymnoDetuneHz, t: t)  // -Detune
        return (v1 + v2 + v3) / 3.0
    }

    // MARK: - Helper Methods

    /// Calculate high frequency gain reduction (600Hz - C6)
    /// Reduces "ringing" sound in high frequency notes by up to 35%
    private func calculateHighFreqReduction(freq: Float) -> Float {
        guard freq >= highFreqThreshold else { return 1.0 }

        let reductionRatio = min(1.0, (freq - highFreqThreshold) / (highFreqMax - highFreqThreshold))
        return 1.0 - reductionRatio * 0.35
    }
}

// MARK: - Design Notes
//
// REFACTORING (2025-11-30):
//
// 1. Converted to Gymnopédie-style (startBar/startBeat)
//    - Before: Sequential note array with cumulative timing
//    - After: Absolute positioning like Gymnopédie
//    - Result: Easier to match with sheet music
//
// 2. Melody rewritten from pianojuku.info score
//    - Original: F Major
//    - Transposed: C Major (for CathedralStillness compatibility)
//    - BPM: 60 (slower for majestic feel)
//
// 3. ASR Envelope (Attack-Sustain-Release)
//    - Organ-style: maintains full volume during note duration
//    - Smooth cosine curves for attack and release
//    - Different from Gymnopédie's AD (Attack-Decay) envelope
//
// COPYRIGHT:
//
// Gustav Holst died in 1934. Under Japanese copyright law (70 years after death),
// "The Planets" entered public domain in 2004. Using the melody is completely legal.
