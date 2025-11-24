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

    // MARK: - Configuration
    private let segmentCount = 45         // Number of bars around the circle (reduced for spacing)
    private let barWidth: CGFloat = 2     // Width of each bar (thinner for smaller size)
    private let baseBarLength: CGFloat = 8.5 // Base length (center point between min/max)
    private let maxAmplitude: CGFloat = 2.5   // Maximum variation from base (reduced for calmer motion)
    private let animationSpeed: Double = 1.5  // Wave cycles per second (slower for calmer motion)

    // Independent phase offsets for each bar (generated once, never changes)
    private let phaseOffsets: [Double] = {
        (0..<45).map { _ in Double.random(in: 0...1000) }
    }()

    // Random amplitude multiplier for each bar (0.1 to 1.0) - most bars move subtly
    private let amplitudeMultipliers: [Double] = {
        (0..<45).map { _ in Double.random(in: 0.1...1.0) }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let centerRadius = size / 2 - baseBarLength // Fixed center circle radius (anchor point)
                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2

                ZStack {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        let angleRad = angle(for: index)
                        let length = barLength(for: index, time: context.date)

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

    /// Calculate animated length for a bar based on time and index
    /// Uses independent phase offsets and random amplitudes for calm, organic motion
    private func barLength(for index: Int, time: Date) -> CGFloat {
        guard audioService.isPlaying else {
            // When stopped, all bars show base length (perfect circle)
            return baseBarLength
        }

        let t = time.timeIntervalSinceReferenceDate
        let phaseOffset = phaseOffsets[index]
        let amplitudeMultiplier = amplitudeMultipliers[index]

        // Independent wave for each bar - no angle dependency
        // Each bar breathes at its own rhythm with its own amplitude
        let wave = sin((t * animationSpeed + phaseOffset) * .pi * 2)

        // Apply random amplitude multiplier (most bars have subtle motion, few have larger motion)
        let amplitude = maxAmplitude * CGFloat(amplitudeMultiplier)

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
