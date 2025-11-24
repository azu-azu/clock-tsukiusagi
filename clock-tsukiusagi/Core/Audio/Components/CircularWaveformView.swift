//
//  CircularWaveformView.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-24.
//  Circular animated waveform visualization for audio playback
//

import SwiftUI

/// Circular animated waveform visualization
/// Shows smooth sine-wave-based animation radiating from center when audio is playing
struct CircularWaveformView: View {
    @EnvironmentObject var audioService: AudioService

    // MARK: - Animation State
    @State private var animationStartTime: Date?
    @State private var animationStopTime: Date?
    private let fadeInDuration: Double = 1.5  // Fade in duration in seconds
    private let fadeOutDuration: Double = 1.5 // Fade out duration in seconds

    // MARK: - Configuration
    private let segmentCount = 30         // Number of bars around the circle (reduced for more spacing)
    private let barWidth: CGFloat = 2     // Width of each bar (thinner for smaller size)
    private let baseBarLength: CGFloat = 5.0 // Base length (shorter for emphasis on movement)
    private let maxAmplitude: CGFloat = 4.0   // Maximum variation from base (larger for noticeable motion)
    private let animationSpeed: Double = 1.5  // Wave cycles per second (slower for calmer motion)
    private let rotationSpeed: Double = -0.05  // Rotation cycles per second (negative = counter-clockwise, 20s per rotation)

    // Independent phase offsets for each bar (generated once, never changes)
    private let phaseOffsets: [Double] = {
        (0..<30).map { _ in Double.random(in: 0...1000) }
    }()

    // Random amplitude multiplier for each bar (0.05 to 1.0) - heavily weighted toward subtle motion
    private let amplitudeMultipliers: [Double] = {
        (0..<30).map { _ in
            // Use power function to weight toward smaller values
            // Most bars will have multiplier < 0.3 (subtle motion)
            let random = Double.random(in: 0...1)
            return pow(random, 2.0) * 0.95 + 0.05  // Range: 0.05-1.0, weighted low
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let centerRadius = size / 2 - baseBarLength // Fixed center circle radius (anchor point)
                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2

                // Calculate fade multiplier for smooth start/stop
                let fadeFactor = calculateFadeFactor(currentTime: context.date)

                // Calculate rotation angle (counter-clockwise when playing)
                let t = context.date.timeIntervalSinceReferenceDate
                let rotationAngle = audioService.isPlaying ? t * rotationSpeed * .pi * 2 : 0

                ZStack {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        let angleRad = angle(for: index) + rotationAngle  // Add rotation
                        let length = barLength(for: index, time: context.date, fadeFactor: fadeFactor)

                        // Calculate position on the circle
                        let x = centerX + cos(angleRad) * centerRadius
                        let y = centerY + sin(angleRad) * centerRadius

                        Capsule()
                            .fill(barColor)
                            .frame(width: length, height: barWidth) // Draw horizontally first (width=length)
                            .rotationEffect(.radians(angleRad)) // Rotate to radial direction
                            .position(x: x, y: y) // Place bar center on the circle
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .opacity(barOpacity)
            .animation(.easeInOut(duration: 0.3), value: audioService.isPlaying)
        }
        .drawingGroup() // Metal acceleration for better performance
        .onChange(of: audioService.isPlaying) { oldValue, newValue in
            if newValue {
                // Started playing
                animationStartTime = Date()
                animationStopTime = nil
            } else {
                // Stopped playing
                animationStopTime = Date()
            }
        }
    }

    // MARK: - Computed Properties

    private var barColor: Color {
        DesignTokens.SettingsColors.accent
    }

    private var barOpacity: Double {
        audioService.isPlaying ? 1.0 : 0.3
    }

    // MARK: - Layout Calculation

    /// Calculate angle for a bar at given index
    private func angle(for index: Int) -> Double {
        let progress = Double(index) / Double(segmentCount)
        return progress * 2.0 * .pi
    }

    // MARK: - Animation Calculation

    /// Calculate fade factor for smooth start/stop transitions
    /// Returns 0.0 (no animation) to 1.0 (full animation)
    private func calculateFadeFactor(currentTime: Date) -> Double {
        if audioService.isPlaying {
            // Fade in
            guard let startTime = animationStartTime else { return 1.0 }
            let elapsed = currentTime.timeIntervalSince(startTime)
            if elapsed >= fadeInDuration {
                return 1.0
            }
            // Ease-in curve for smooth start
            let progress = elapsed / fadeInDuration
            return easeInOut(progress)
        } else {
            // Fade out
            guard let stopTime = animationStopTime else { return 0.0 }
            let elapsed = currentTime.timeIntervalSince(stopTime)
            if elapsed >= fadeOutDuration {
                return 0.0
            }
            // Ease-out curve for smooth stop
            let progress = elapsed / fadeOutDuration
            return 1.0 - easeInOut(progress)
        }
    }

    /// Ease-in-out curve for smooth transitions
    private func easeInOut(_ t: Double) -> Double {
        if t < 0.5 {
            return 2 * t * t
        } else {
            return 1 - pow(-2 * t + 2, 2) / 2
        }
    }

    /// Calculate animated length for a bar based on time and index
    /// Uses independent phase offsets and time-varying amplitudes for organic motion
    private func barLength(for index: Int, time: Date, fadeFactor: Double) -> CGFloat {
        let t = time.timeIntervalSinceReferenceDate
        let phaseOffset = phaseOffsets[index]
        let baseAmplitudeMultiplier = amplitudeMultipliers[index]

        // Independent wave for each bar - no angle dependency
        // Each bar breathes at its own rhythm
        let wave = sin((t * animationSpeed + phaseOffset) * .pi * 2)

        // Slow amplitude modulation - each bar's amplitude changes over time
        // Uses a different phase for amplitude modulation (very slow cycle)
        let amplitudeModulationSpeed = 0.1  // 10 second cycle for amplitude change
        let amplitudePhase = t * amplitudeModulationSpeed + phaseOffset * 0.01
        let amplitudeModulation = sin(amplitudePhase * .pi * 2)

        // Map modulation to 0.05-1.0 range (same as original distribution)
        // When modulation is -1: multiplier is near 0.05 (minimal motion)
        // When modulation is +1: multiplier is near 1.0 (maximum motion)
        let dynamicMultiplier = 0.05 + (amplitudeModulation + 1.0) / 2.0 * 0.95

        // Combine base multiplier with dynamic modulation
        // This creates variation while maintaining each bar's character
        let finalMultiplier = baseAmplitudeMultiplier * dynamicMultiplier

        // Apply time-varying amplitude with fade factor
        let amplitude = maxAmplitude * CGFloat(finalMultiplier) * CGFloat(fadeFactor)

        // Calculate length: base ± amplitude
        let length = baseBarLength + amplitude * CGFloat(wave)

        return length
    }
}

#Preview("Playing State") {
    ZStack {
        Color.black
            .ignoresSafeArea()

        CircularWaveformView()
            .environmentObject({
                let service = AudioService.shared
                // Simulate playing state for preview
                return service
            }())
            .frame(width: 280, height: 280)
    }
}

#Preview("Stopped State") {
    ZStack {
        DesignTokens.SettingsColors.backgroundGradient
            .ignoresSafeArea()

        CircularWaveformView()
            .environmentObject(AudioService.shared)
            .frame(width: 280, height: 280)
    }
}

#Preview("With Glow Effect") {
    ZStack {
        Color.black
            .ignoresSafeArea()

        CircularWaveformView()
            .environmentObject({
                let service = AudioService.shared
                return service
            }())
            .frame(width: 280, height: 280)
            .shadow(color: DesignTokens.SettingsColors.accent.opacity(0.5), radius: 10)
            .shadow(color: DesignTokens.SettingsColors.accent.opacity(0.3), radius: 20)
    }
}
