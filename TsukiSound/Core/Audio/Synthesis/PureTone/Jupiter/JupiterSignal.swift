//
//  JupiterSignal.swift
//  TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter
//
//  Jupiter Melody - Holst's "The Planets" Jupiter theme in C Major
//  Organ-style melody with ASR envelope for cathedral atmosphere
//
//  Refactored to Gymnopédie-style (startBar/startBeat) for consistency
//
//  ## セクション対応
//  JupiterTimingを参照し、楽曲の進行に合わせて音色が変化
//  - Section 0 (Bar 1-4): Gymnopédie風ベース音色（深く響く低音）
//  - Section 1 (Bar 5-8): ベースからオルガンへクロスフェード
//  - Section 2以降: オルガン音色
//

import Foundation

/// JupiterMelodySignal - Holst's Jupiter theme adapted for organ
///
/// Produces a majestic, solemn melody based on Holst's "Jupiter" (public domain).
/// Transposed from F Major to C Major.
///
/// Characteristics:
/// - Gymnopédie-style note positioning (startBar/startBeat)
/// - Section 0: Gymnopédie-style bass tone (deep, resonant)
/// - Section 1+: Organ-style ASR envelope (Attack-Sustain-Release)
/// - Rich harmonics with 6th overtone (organ sections)
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

    /// Musical cycle duration (楽譜上の全長、イントロスキップなし)
    /// ノート位置計算に使用（楽譜ベース）
    lazy var fullMusicalCycleDuration: Float = Float(totalBars) * barDuration

    /// Real cycle duration (実際の再生時間、テンポ変化あり)
    var cycleDuration: Float { JupiterTiming.cycleDuration }

    // MARK: - Sound Design (Organ Characteristics)

    /// Organ-style harmonics with warm foundation
    let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0, 6.0]

    /// Harmonic amplitudes: warm, full organ tone
    let harmonicAmps: [Float] = [1.0, 0.45, 0.25, 0.12, 0.03]

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
    // 控えめなデチューンで微かな揺らぎを追加
    // 長いアタック・リリースで音が柔らかくつながる（うねりを軽減）

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

    func sample(at t: Float) -> Float {
        // 実時間を楽譜時間に変換（Section 0のテンポ伸縮 + イントロスキップを反映）
        let musicalTime = JupiterTiming.realToMusicalTime(t)
        let local = musicalTime.truncatingRemainder(dividingBy: fullMusicalCycleDuration)

        // セクションとクロスフェード用の進行度を取得
        let section = JupiterTiming.currentSection(at: t)
        let sectionProgress = JupiterTiming.sectionProgress(at: t)

        var output: Float = 0

        for note in melody {
            let noteStart = Float(note.startBar - 1) * barDuration + note.startBeat * beat
            let noteDur = note.durBeats * beat

            // Calculate effective duration (shortened by breath amount)
            // Key insight: both active window AND envelope must use the same effectiveDur
            let breathAmount = note.breath.rawValue
            let effectiveDur = breathAmount > 0 ? max(noteDur - breathAmount, attackTime) : noteDur

            // Note is active during its effective duration + release tail
            // Section 0/1 uses longer release for legato connection
            let activeReleaseTime = (section <= 1) ? gymnoReleaseTime : releaseTime
            if local >= noteStart && local < noteStart + effectiveDur + activeReleaseTime {
                let dt = local - noteStart

                // === Section-based sound generation ===
                if section == 0 {
                    // Section 0: Gymnopédie風メロディ音色（クリーンで響く）
                    let gymnoEnv = calculateGymnopedieEnvelope(time: dt, duration: effectiveDur)
                    let gymnoFreq = note.freq * transposeFactor  // 通常のトランスポーズ（-2半音）
                    let v = generateGymnopedieVoice(freq: gymnoFreq, t: t)
                    output += v * gymnoEnv * gymnoGain
                } else if section == 1 {
                    // Section 1: クロスフェード（Gymnopédie → Organ）
                    let gymnoFade = 1.0 - sectionProgress
                    let organFade = sectionProgress

                    // Gymnopédie voice (fading out)
                    let gymnoEnv = calculateGymnopedieEnvelope(time: dt, duration: effectiveDur)
                    let gymnoFreq = note.freq * transposeFactor  // 通常のトランスポーズ
                    let gymnoV = generateGymnopedieVoice(freq: gymnoFreq, t: t)

                    // Organ voice (fading in)
                    let organEnv = calculateASREnvelope(time: dt, duration: effectiveDur)
                    let organFreq = note.freq * transposeFactor
                    let gainReduction = calculateHighFreqReduction(freq: organFreq)
                    let organV = generateSingleVoice(freq: organFreq, t: t)

                    output += gymnoV * gymnoEnv * gymnoGain * gymnoFade
                    output += organV * organEnv * gainReduction * masterGain * organFade
                } else {
                    // Section 2以降: 通常のオルガン音色
                    let env = calculateASREnvelope(time: dt, duration: effectiveDur)
                    let transposedFreq = note.freq * transposeFactor
                    let gainReduction = calculateHighFreqReduction(freq: transposedFreq)
                    let v = generateSingleVoice(freq: transposedFreq, t: t)
                    output += v * env * gainReduction * masterGain
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
    /// - Returns: Envelope value (0.0 to 1.0)
    private func calculateASREnvelope(time: Float, duration: Float) -> Float {
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
        let releaseProgress = (time - duration) / releaseTime
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
