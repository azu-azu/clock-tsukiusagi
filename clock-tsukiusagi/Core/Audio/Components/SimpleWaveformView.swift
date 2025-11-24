//
//  SimpleWaveformView.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-24.
//  Simple animated waveform bars to indicate audio playback
//

import SwiftUI

/// Simple animated waveform visualization
/// Shows smooth sine-wave-based animation when audio is playing
struct SimpleWaveformView: View {
    @EnvironmentObject var audioService: AudioService

    // MARK: - Configuration
    private let barCount = 28
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 3
    private let minHeight: CGFloat = 10
    private let maxHeight: CGFloat = 50
    private let animationSpeed: Double = 2.0  // Wave cycles per second

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor)
                        .frame(
                            width: barWidth,
                            height: barHeight(for: index, time: context.date)
                        )
                }
            }
            .frame(height: maxHeight)
            .opacity(barOpacity)
            .animation(.easeInOut(duration: 0.3), value: audioService.isPlaying)
        }
    }

    // MARK: - Computed Properties

    private var barColor: Color {
        DesignTokens.SettingsColors.accent
    }

    private var barOpacity: Double {
        audioService.isPlaying ? 1.0 : 0.3
    }

    // MARK: - Animation Calculation

    /// Calculate animated height for a bar based on time and index
    /// Uses multiple sine waves for organic, non-repetitive motion
    private func barHeight(for index: Int, time: Date) -> CGFloat {
        guard audioService.isPlaying else {
            // When stopped, show low static bars
            return minHeight
        }

        let t = time.timeIntervalSinceReferenceDate
        let normalizedIndex = Double(index) / Double(barCount)

        // Primary wave: smooth left-to-right motion
        let primaryPhase = t * animationSpeed * .pi * 2 + normalizedIndex * .pi * 2
        let primaryWave = sin(primaryPhase)

        // Secondary wave: adds complexity and variation
        let secondaryPhase = t * animationSpeed * 1.3 * .pi * 2 + normalizedIndex * .pi * 1.5
        let secondaryWave = sin(secondaryPhase) * 0.3

        // Tertiary wave: slow modulation for overall "breathing" effect
        let tertiaryPhase = t * animationSpeed * 0.5 * .pi * 2
        let tertiaryWave = sin(tertiaryPhase) * 0.2

        // Combine waves: primary dominates, secondary adds detail, tertiary adds slow modulation
        let combinedWave = (primaryWave + secondaryWave + tertiaryWave) / 1.5

        // Normalize to 0.0-1.0 range
        let normalized = (combinedWave + 1.0) / 2.0

        // Map to height range
        let height = minHeight + (maxHeight - minHeight) * CGFloat(normalized)

        return height
    }
}

#Preview {
    VStack(spacing: 40) {
        // Playing state
        SimpleWaveformView()
            .environmentObject({
                let service = AudioService.shared
                // Simulate playing state for preview
                return service
            }())
            .padding()
            .background(DesignTokens.SettingsColors.backgroundGradient)

        // Stopped state
        SimpleWaveformView()
            .environmentObject(AudioService.shared)
            .padding()
            .background(DesignTokens.SettingsColors.backgroundGradient)
    }
}
