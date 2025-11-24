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
    private let segmentCount = 90         // Number of bars around the circle (more segments for smoother appearance)
    private let barWidth: CGFloat = 2     // Width of each bar (thinner for smaller size)
    private let minBarLength: CGFloat = 4  // Minimum bar length (when stopped)
    private let maxBarLength: CGFloat = 13 // Maximum bar length (peak height, half of original)
    private let animationSpeed: Double = 2.0  // Wave cycles per second
    private let waveFrequency: Double = 1.5   // Number of waves around the circle (lower for calmer motion)

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let centerRadius = size / 2 - maxBarLength / 2 // Fixed center circle radius (anchor point)
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
                            .frame(width: barWidth, height: length)
                            .position(x: x, y: y) // Place bar center on the circle
                            .rotationEffect(.radians(angleRad + .pi / 2)) // Rotate to point radially (perpendicular to tangent)
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
    /// Uses multiple sine waves for organic, non-repetitive motion
    private func barLength(for index: Int, time: Date) -> CGFloat {
        guard audioService.isPlaying else {
            // When stopped, show minimal static bars
            return minBarLength
        }

        let t = time.timeIntervalSinceReferenceDate
        let angle = angle(for: index)

        // Primary wave: smooth circular motion
        let primaryPhase = t * animationSpeed * .pi * 2 + angle * waveFrequency
        let primaryWave = sin(primaryPhase)

        // Secondary wave: adds subtle complexity and variation (reduced amplitude)
        let secondaryPhase = t * animationSpeed * 1.3 * .pi * 2 + angle * (waveFrequency * 1.2)
        let secondaryWave = sin(secondaryPhase) * 0.2

        // Tertiary wave: slow modulation for overall "breathing" effect
        let tertiaryPhase = t * animationSpeed * 0.5 * .pi * 2
        let tertiaryWave = sin(tertiaryPhase) * 0.15

        // Combine waves: primary dominates, secondary adds subtle detail, tertiary adds slow modulation
        let combinedWave = (primaryWave + secondaryWave + tertiaryWave) / 1.35

        // Normalize to 0.0-1.0 range
        let normalized = (combinedWave + 1.0) / 2.0

        // Map to length range
        let length = minBarLength + (maxBarLength - minBarLength) * CGFloat(normalized)

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
