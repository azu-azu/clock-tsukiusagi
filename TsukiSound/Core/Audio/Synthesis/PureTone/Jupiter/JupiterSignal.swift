//
//  JupiterSignal.swift
//  TsukiSound/Core/Audio/Synthesis/PureTone/Jupiter
//
//  Jupiter Melody - Holst's "The Planets" Jupiter theme in C Major
//  Organ-style melody with ASR envelope for cathedral atmosphere
//
//  Refactored with Ren's suggestions:
//  - ASR envelope (Attack-Sustain-Release) instead of Decay
//  - Readable note definitions using Pitch and Duration enums
//  - Added 8th harmonic (Mixture stop) for brilliance
//

import Foundation

/// JupiterMelodySignal - Holst's Jupiter theme adapted for organ
///
/// Produces a majestic, solemn melody based on Holst's "Jupiter" (public domain).
/// Transposed from E Major to C Major to harmonize with CathedralStillness drone (C/G).
///
/// Characteristics:
/// - Syllabic phrasing for natural vocal-style articulation
/// - Climax with G5 peak and resolution
/// - Organ-style ASR envelope (Attack-Sustain-Release)
/// - Rich harmonics with 8th overtone (Mixture stop)
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

    // MARK: - Timing & Optimization

    /// Cumulative times for efficient note indexing
    /// Calculated once and cached
    lazy var cumulativeTimes: [Float] = {
        var times: [Float] = [0.0]
        for note in melody {
            times.append(times.last! + note.duration)
        }
        return times
    }()

    /// Total cycle duration
    lazy var cycleDuration: Float = cumulativeTimes.last!

    // MARK: - Sound Design (Organ Characteristics)

    /// Organ-style harmonics with warm foundation
    /// 6 harmonics is acceptable with single-layer voice
    let harmonics: [Float] = [1.0, 2.0, 3.0, 4.0, 6.0]

    /// Harmonic amplitudes: warm, full organ tone
    let harmonicAmps: [Float] = [1.0, 0.45, 0.25, 0.12, 0.03]

    // MARK: - Tremulant (Vibrato)

    /// Vibrato rate: speed of pitch oscillation
    /// 3-5 Hz is typical for organ tremulant
    let vibratoRate: Float = 4.0      // 4Hz

    /// Vibrato depth: amount of pitch variation
    /// Very subtle for stable, gentle warmth
    let vibratoDepth: Float = 0.001

    /// Legato Envelope Parameters (very smooth, connected notes)
    /// - Attack: Fast enough for 16th notes (0.3s) while still smooth
    /// - Release: Long tail extending well into next note
    let attackTime: Float = 0.15   // 150ms: smooth but fast enough for short notes
    let releaseTime: Float = 0.8   // 800ms: very long tail for seamless blend

    /// Legato overlap: how much the release extends into next note
    /// Must equal releaseTime to prevent abrupt cutoff of release envelope
    /// Prevents click noise at note boundaries (see architect/todo.md analysis)
    let legatoOverlap: Float = 0.80  // 800ms overlap = releaseTime for complete coverage

    /// Master gain for balance with other layers
    /// Increased from 0.22 to 0.35 after removing multi-voice layering
    let masterGain: Float = 0.35

    /// High frequency gain reduction threshold (Hz)
    /// Frequencies above this will be progressively reduced
    /// Gymnopédieと同じ設定: 600Hz以上で最大35%減衰
    let highFreqThreshold: Float = 600.0
    let highFreqMax: Float = JupiterPitch.C6.rawValue

    /// Transpose factor: -2 semitones for warmer, less piercing sound
    /// 2^(-2/12) ≈ 0.8909
    let transposeFactor: Float = pow(2.0, -2.0 / 12.0)

    // MARK: - Sample Generation

    func sample(at t: Float) -> Float {
        // 1. Note detection: use cycleTime (wrapped) for finding which note to play
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)

        // 2. Wave generation: use absolute t to maintain phase continuity
        //    (precision handled by Double conversion in generateSingleVoice)
        let tAbsolute = t

        var totalSignal: Float = 0.0

        // Find current note and potentially overlapping previous note
        if let index = findNoteIndex(at: cycleTime) {
            let note = melody[index]
            let noteStartTime = cumulativeTimes[index]
            let localTime = cycleTime - noteStartTime

            // Current note with legato envelope and high-freq gain reduction
            // Apply transpose factor to frequency (structure unchanged, pitch lowered)
            let transposedFreq = note.freq * transposeFactor
            let envelope = calculateLegatoEnvelope(time: localTime, duration: note.duration)
            let gainReduction = calculateHighFreqReduction(freq: transposedFreq)
            totalSignal += generateTone(freq: transposedFreq, t: tAbsolute) * envelope * gainReduction

            // Check if previous note is still releasing (legato overlap)
            if index > 0 && localTime < legatoOverlap {
                let prevNote = melody[index - 1]
                let prevDuration = prevNote.duration
                let timeIntoRelease = prevDuration + localTime  // time since prev note started

                let prevEnvelope = calculateLegatoEnvelope(time: timeIntoRelease, duration: prevDuration)
                if prevEnvelope > 0 {
                    let prevTransposedFreq = prevNote.freq * transposeFactor
                    let prevGainReduction = calculateHighFreqReduction(freq: prevTransposedFreq)
                    totalSignal += generateTone(freq: prevTransposedFreq, t: tAbsolute) * prevEnvelope * prevGainReduction
                }
            }
        }

        let output = totalSignal * masterGain
        return SignalEnvelopeUtils.softClip(output)
    }

    /// Generate organ tone - single voice for performance
    /// Note: Multi-voice layering (16' Sub, Quint, 4' Oct) removed due to CPU load
    /// causing audio glitches. See report/report-jupiter-melody-optimization.md for analysis.
    private func generateTone(freq: Float, t: Float) -> Float {
        // 8' Principal: Main melody voice only
        return generateSingleVoice(freq: freq, t: t)
    }

    /// Generate a single organ voice with harmonics and vibrato
    /// Uses Double precision internally to prevent floating-point errors over long playback
    private func generateSingleVoice(freq: Float, t: Float) -> Float {
        // Convert to Double for precision in long playback sessions
        let tDouble = Double(t)
        let twoPiDouble = Double.pi * 2.0
        let vibratoRateDouble = Double(vibratoRate)
        let vibratoDepthDouble = Double(vibratoDepth)

        // Vibrato: gentle phase offset (same amount for all harmonics)
        // This prevents high harmonics from getting "buzzy" FM-like artifacts
        let vibrato = sin(twoPiDouble * vibratoRateDouble * tDouble) * vibratoDepthDouble

        var signal: Double = 0.0

        // Use zip to safely iterate harmonics and amplitudes together
        for (harmonicRatio, harmonicAmp) in zip(harmonics, harmonicAmps) {
            let hFreqDouble = Double(freq * harmonicRatio)
            let harmonicAmpDouble = Double(harmonicAmp)

            // Calculate phase and wrap to prevent precision loss
            let rawPhase = hFreqDouble * tDouble
            let wrappedPhase = rawPhase - floor(rawPhase)  // Keep 0.0 to 1.0

            // Add vibrato as uniform phase offset (not frequency-dependent)
            let phase = twoPiDouble * (wrappedPhase + vibrato)

            signal += sin(phase) * harmonicAmpDouble
        }

        // Normalize by harmonic count and convert back to Float
        signal /= Double(harmonics.count)
        return Float(signal)
    }

    // MARK: - Helper Methods

    /// Find index of note playing at given time
    private func findNoteIndex(at time: Float) -> Int? {
        for i in 0..<melody.count {
            if time >= cumulativeTimes[i] && time < cumulativeTimes[i + 1] {
                return i
            }
        }
        return nil
    }

    /// Calculate high frequency gain reduction (600Hz - C6)
    /// Reduces "ringing" sound in high frequency notes by up to 35%
    private func calculateHighFreqReduction(freq: Float) -> Float {
        guard freq >= highFreqThreshold else { return 1.0 }

        let reductionRatio = min(1.0, (freq - highFreqThreshold) / (highFreqMax - highFreqThreshold))
        // Maximum 35% reduction at highest frequency (Gymnopédieと同じ)
        return 1.0 - reductionRatio * 0.35
    }

    /// Generates a simple ASR (Attack-Sustain-Release) envelope
    /// Release starts at note end and goes to zero smoothly
    ///
    /// Shape:
    /// ```
    /// 1.0     ╭───────────────╮
    ///        ╱                 ╲
    ///       ╱                   ╲
    /// 0.0 ─╯                     ╲─────
    ///     0   attack    duration   duration+release
    /// ```
    private func calculateLegatoEnvelope(time: Float, duration: Float) -> Float {
        let sustainEnd = duration
        let releaseEnd = duration + releaseTime

        // Attack Phase: smooth cosine rise
        if time < attackTime {
            let progress = max(time / attackTime, 0.0)
            return (1.0 - cos(progress * Float.pi)) * 0.5
        }
        // Sustain Phase: full volume until note ends
        else if time < sustainEnd {
            return 1.0
        }
        // Release Phase: smooth fade to zero after note ends
        else if time < releaseEnd {
            let progress = (time - sustainEnd) / releaseTime
            let clamped = min(max(progress, 0.0), 1.0)
            return (1.0 + cos(clamped * Float.pi)) * 0.5
        }
        // Fully silent
        else {
            return 0.0
        }
    }
}

// MARK: - Design Notes
//
// REFACTORING SUMMARY (2025-11-27):
//
// Based on Ren's code review suggestions:
//
// 1. ENVELOPE CHANGE: Decay → ASR (Attack-Sustain-Release)
//    - Before: exp(-decayTime / decay) - bell/piano-like decay
//    - After: Trapezoidal ASR - organ-like sustain
//    - Result: Sound sustains during note, then releases smoothly
//
// 2. READABLE NOTE DEFINITIONS:
//    - Before: Note(freq: 329.63, duration: 0.80)
//    - After: Note(.E4, .eighth)
//    - Result: Melody is now human-readable and music-theory aligned
//
// 3. HARMONIC ENRICHMENT:
//    - Before: [1.0, 2.0, 3.0, 4.0]
//    - After: [1.0, 2.0, 3.0, 4.0, 8.0] with amp 0.05
//    - Result: Added "Mixture stop" brilliance typical of cathedral organs
//
// 4. CLICK PREVENTION:
//    - Added 200ms release time at end of each note
//    - Prevents "pop" noise at note transitions
//
// 5. MELODY REWRITE (2025-11-28):
//    - Rewrote melody for syllabic phrasing (vocal-style articulation)
//    - More even eighth notes for clear syllable separation
//    - Added climax: G5 (the emotional peak)
//    - Resolution: landing on C5 with long sustain
//
// MELODY DESIGN:
//
// Source: Holst's "Thaxted" chorale from Jupiter (1918, public domain)
// Key: C Major (fits CathedralStillness C/G drone)
// Phrasing: Syllabic rhythm for natural vocal flow
//
// INTEGRATION WITH CATHEDRALSTILLNESS:
//
// Layer architecture:
// 1. Organ drone (C3 + G3, 0.02Hz LFO) - foundation
// 2. Harp arpeggios (MidnightDroplets) - sparse decoration
// 3. Jupiter chorale (this) - majestic centerpiece
//
// COPYRIGHT:
//
// Gustav Holst died in 1934. Under Japanese copyright law (70 years after death),
// "The Planets" entered public domain in 2004. Using the melody is completely legal.
