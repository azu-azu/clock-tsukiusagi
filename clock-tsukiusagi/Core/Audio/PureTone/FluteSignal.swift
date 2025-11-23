//
//  FluteSignal.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-23.
//  Gentle Flute Melody — calm, meditative flute with vibrato and breath
//

import Foundation

/// Gentle Flute Melody — soft, peaceful flute with natural expression
///
/// This preset creates a warm, calming flute sound:
/// Components:
/// - Pentatonic melody: E4 → G4 → A4 → G4 → E4 → D4 → C4
/// - Soft sine wave + subtle harmonics for flute timbre
/// - Gentle vibrato (4.5Hz LFO, ±0.8%) for natural expression
/// - Breath noise layer (high-frequency, 30ms attack only)
/// - Long sustain (1.8s) + natural release (200ms)
///
/// Melody notes (pentatonic C scale):
/// - C4: 261.63 Hz
/// - D4: 293.66 Hz
/// - E4: 329.63 Hz
/// - G4: 392.00 Hz
/// - A4: 440.00 Hz
///
/// Timing: Each note sustains for 2 seconds, creating a 14-second cycle
public struct FluteSignal {

    /// Create raw Signal (for FinalMixer usage)
    public static func makeSignal() -> Signal {
        let generator = FluteGenerator()
        return Signal { t in generator.sample(at: t) }
    }
}

private final class FluteGenerator {

    // Melody sequence (pentatonic)
    let melody: [Float] = [
        329.63,  // E4
        392.00,  // G4
        440.00,  // A4
        392.00,  // G4
        329.63,  // E4
        293.66,  // D4
        261.63   // C4
    ]

    // Timing parameters
    let noteDuration: Float = 2.0       // Each note lasts 2 seconds
    let cycleDuration: Float = 14.0     // Full melody: 7 notes × 2s = 14s

    // Envelope parameters
    let attack: Float = 0.050           // 50ms breath attack
    let sustain: Float = 1.8            // 1.8s sustain
    let release: Float = 0.200          // 200ms natural release

    // Vibrato parameters
    let vibratoFreq: Float = 4.5        // 4.5Hz LFO
    let vibratoDepth: Float = 0.008     // ±0.8% pitch modulation

    // Timbre parameters
    let harmonics: [Float] = [1.0, 2.0]
    let harmonicAmps: [Float] = [1.0, 0.12]  // Mostly fundamental (flute-like)

    // Breath noise parameters
    let breathDuration: Float = 0.030   // 30ms breath at attack
    let breathLevel: Float = 0.05       // -26dB breath noise

    func sample(at t: Float) -> Float {
        // Determine which note we're playing
        let cycleTime = t.truncatingRemainder(dividingBy: cycleDuration)
        let noteIndex = Int(cycleTime / noteDuration)
        guard noteIndex < melody.count else { return 0.0 }

        let noteFreq = melody[noteIndex]
        let timeSinceNoteStart = cycleTime - Float(noteIndex) * noteDuration

        // Calculate envelope (attack + sustain + release)
        let envelope: Float
        if timeSinceNoteStart < attack {
            // Attack phase: linear fade-in
            envelope = timeSinceNoteStart / attack
        } else if timeSinceNoteStart < sustain {
            // Sustain phase: full volume
            envelope = 1.0
        } else if timeSinceNoteStart < (sustain + release) {
            // Release phase: exponential fade-out
            let releaseTime = timeSinceNoteStart - sustain
            envelope = exp(-releaseTime / (release * 0.5))  // Gentle release
        } else {
            // Note finished
            return 0.0
        }

        // Apply vibrato (pitch modulation)
        let vibratoLFO = sin(2.0 * Float.pi * vibratoFreq * t)
        let pitchMod = 1.0 + (vibratoLFO * vibratoDepth)
        let modulatedFreq = noteFreq * pitchMod

        // Generate flute tone with harmonics
        var fluteValue: Float = 0.0
        for h in 0..<harmonics.count {
            let freq = modulatedFreq * harmonics[h]
            let phase = 2.0 * Float.pi * freq * t
            fluteValue += sin(phase) * harmonicAmps[h]
        }

        // Add breath noise (only during attack)
        var breathValue: Float = 0.0
        if timeSinceNoteStart < breathDuration {
            let breathEnvelope = timeSinceNoteStart / breathDuration
            // Simple high-frequency noise simulation (deterministic)
            let noisePhase = sin(2.0 * Float.pi * 8000.0 * t) * sin(2.0 * Float.pi * 9500.0 * t)
            breathValue = noisePhase * breathEnvelope * breathLevel
        }

        // Mix tone + breath and apply envelope
        return (fluteValue + breathValue) * envelope * 0.35  // Soft, gentle volume
    }

    public func reset() {
        // Stateless, no reset needed
    }
}
