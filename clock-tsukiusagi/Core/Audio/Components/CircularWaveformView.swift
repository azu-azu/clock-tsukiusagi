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
    private let segmentCount = 60         // Number of bars around the circle (reduced for smaller size)
    private let barWidth: CGFloat = 2     // Width of each bar (thinner for smaller size)
    private let minBarLength: CGFloat = 4  // Minimum bar length (when stopped)
    private let maxBarLength: CGFloat = 13 // Maximum bar length (peak height, half of original)
    private let animationSpeed: Double = 2.0  // Wave cycles per second
    private let waveFrequency: Double = 3.0   // Number of waves around the circle

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let baseRadius = size / 2 - maxBarLength

                ZStack {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        Capsule()
                            .fill(barColor)
                            .frame(
                                width: barWidth,
                                height: barLength(for: index, time: context.date, radius: baseRadius)
                            )
                            .offset(y: -baseRadius)
                            .rotationEffect(.radians(angle(for: index)))
                    }
                }
                .frame(width: size, height: size)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
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
    private func barLength(for index: Int, time: Date, radius: CGFloat) -> CGFloat {
        guard audioService.isPlaying else {
            // When stopped, show minimal static bars
            return minBarLength
        }

        let t = time.timeIntervalSinceReferenceDate
        let angle = angle(for: index)

        // Primary wave: smooth circular motion
        let primaryPhase = t * animationSpeed * .pi * 2 + angle * waveFrequency
        let primaryWave = sin(primaryPhase)

        // Secondary wave: adds complexity and variation
        let secondaryPhase = t * animationSpeed * 1.3 * .pi * 2 + angle * (waveFrequency * 1.5)
        let secondaryWave = sin(secondaryPhase) * 0.3

        // Tertiary wave: slow modulation for overall "breathing" effect
        let tertiaryPhase = t * animationSpeed * 0.5 * .pi * 2
        let tertiaryWave = sin(tertiaryPhase) * 0.2

        // Combine waves: primary dominates, secondary adds detail, tertiary adds slow modulation
        let combinedWave = (primaryWave + secondaryWave + tertiaryWave) / 1.5

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
