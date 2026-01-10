//
//  CircularWaveformView.swift
//  TsukiSound
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
    private static let segmentCount = 32         // Number of bars around the circle (reduced for more spacing)
    private let barWidth: CGFloat = 2     // Width of each bar (thinner for smaller size)
    private let baseBarLength: CGFloat = 5.0 // Base length (shorter for emphasis on movement)
    private let maxAmplitude: CGFloat = 6.0   // Maximum variation from base (larger for more dramatic motion)
    private let animationSpeed: Double = 1.0  // Wave cycles per second (slower for calmer motion)
    private let rotationSpeed: Double = -0.013  // Rotation speed (negative = counter-clockwise)

    // Synchronization parameters
    private let syncFrequency: Double = 0.05  // Sync moment every 20 seconds
    private let syncStrength: Double = 0.28    // How much bars align (0.0-1.0)

    // Radius breathing parameters
    private let radiusBreathingSpeed: Double = 0.08  // Breathing cycle speed (12.5s per cycle, very slow)
    private let radiusBreathingAmount: CGFloat = 1.2  // Amplitude of radius variation (±1.2pt)

    // Shadow/Glow parameters
    private let shadowRadiusInner: CGFloat = 3   // Inner glow radius
    private let shadowRadiusMiddle: CGFloat = 6  // Middle glow radius
    private let shadowRadiusOuter: CGFloat = 10  // Outer glow radius

    // Independent phase offsets for each bar (generated once based on segmentCount)
    private let phaseOffsets: [Double] = {
        (0..<CircularWaveformView.segmentCount).map { _ in Double.random(in: 0...1000) }
    }()

    // Random amplitude multiplier for each bar (0.05 to 1.0) - heavily weighted toward subtle motion
    private let amplitudeMultipliers: [Double] = {
        (0..<CircularWaveformView.segmentCount).map { _ in
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
                let baseCenterRadius = size / 2 - baseBarLength // Base center circle radius
                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2

                // Calculate fade multiplier for smooth start/stop
                let fadeFactor = calculateFadeFactor(currentTime: context.date)

                // Calculate rotation angle (counter-clockwise when playing)
                let t = context.date.timeIntervalSinceReferenceDate
                let rotationAngle = audioService.isPlaying ? t * rotationSpeed * .pi * 2 : 0

                // Calculate synchronization factor (0.0 = random, 1.0 = all synchronized)
                let syncFactor = calculateSyncFactor(time: t)

                // Calculate breathing radius modulation (circle itself breathes)
                let radiusModulation =
                    audioService.isPlaying
                    ? sin(t * radiusBreathingSpeed * .pi * 2) * radiusBreathingAmount
                    : 0
                let centerRadius = baseCenterRadius + radiusModulation

                ZStack {
                    ForEach(0..<Self.segmentCount, id: \.self) { index in
                        let angleRad = angle(for: index) + rotationAngle  // Add rotation
                        let lengthAndGlow = barLengthAndGlow(
                            for: index,
                            time: context.date,
                            fadeFactor: fadeFactor,
                            syncFactor: syncFactor
                        )

                        // Calculate position on the circle
                        let x = centerX + cos(angleRad) * centerRadius
                        let y = centerY + sin(angleRad) * centerRadius

                        Capsule()
                            .fill(barColor)
                            .frame(width: lengthAndGlow.length, height: barWidth) // Draw horizontally first (width=length)
                            .shadow(color: shadowColorInner, radius: shadowRadiusInner * lengthAndGlow.glowMultiplier, x: 0, y: 0)
                            .shadow(color: shadowColorMiddle, radius: shadowRadiusMiddle * lengthAndGlow.glowMultiplier, x: 0, y: 0)
                            .shadow(color: shadowColorOuter, radius: shadowRadiusOuter * lengthAndGlow.glowMultiplier, x: 0, y: 0)
                            .rotationEffect(.radians(angleRad)) // Rotate to radial direction
                            .position(x: x, y: y) // Place bar center on the circle
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .opacity(barOpacity)
            .animation(.easeInOut(duration: 0.3), value: audioService.isPlaying)
        }
        .background(.clear)
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
        DesignTokens.CommonTextColors.quinary
    }

    private var shadowColorInner: Color {
        DesignTokens.CommonTextColors.primary.opacity(0.9)
    }

    private var shadowColorMiddle: Color {
        DesignTokens.CommonTextColors.tertiary.opacity(0.86)  // 0.7 * 0.86 ≈ 0.6
    }

    private var shadowColorOuter: Color {
        DesignTokens.CommonTextColors.quaternary.opacity(0.5)  // 0.6 * 0.5 = 0.3
    }

    private var barOpacity: Double {
        audioService.isPlaying ? 1.0 : 0.3
    }

    // MARK: - Layout Calculation

    /// Calculate angle for a bar at given index
    private func angle(for index: Int) -> Double {
        let progress = Double(index) / Double(Self.segmentCount)
        return progress * 2.0 * .pi
    }

    // MARK: - Animation Calculation

    /// Calculate synchronization factor - creates moments where bars align briefly
    /// Returns 0.0 (completely random) to 1.0 (all bars synchronized)
    private func calculateSyncFactor(time: Double) -> Double {
        // Create periodic sync moments using smoothed pulse
        let syncPhase = time * syncFrequency * .pi * 2
        let rawSync = sin(syncPhase)

        // Softer pulse - quadratic instead of cubic for natural transition
        // Prevents "wall effect" from overly sharp peaks
        let sharpSync = pow(max(rawSync, 0.0), 2.0)  // Quadratic for smoother peaks

        return sharpSync * syncStrength
    }

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

    /// Calculate animated length and glow multiplier for a bar
    /// Uses independent phase offsets, time-varying amplitudes, and synchronization
    private func barLengthAndGlow(
        for index: Int,
        time: Date,
        fadeFactor: Double,
        syncFactor: Double
    ) -> (length: CGFloat, glowMultiplier: CGFloat) {
        let t = time.timeIntervalSinceReferenceDate
        let phaseOffset = phaseOffsets[index]
        let baseAmplitudeMultiplier = amplitudeMultipliers[index]

        // Calculate individual wave
        let individualWave = sin((t * animationSpeed + phaseOffset) * .pi * 2)

        // Calculate synchronized wave (all bars share this)
        let syncWave = sin(t * animationSpeed * .pi * 2)

        // Blend individual and synchronized waves based on syncFactor
        let wave = individualWave * (1.0 - syncFactor) + syncWave * syncFactor

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
        // Ensure length never goes below a minimum value (1.0pt) to avoid negative or zero frames
        let length = baseBarLength + amplitude * CGFloat(wave)
        let minLength: CGFloat = 1.0
        let clampedLength = max(length, minLength)

        // Calculate glow multiplier based on bar extension
        // When bar is extended, glow expands ("ふわっと膨らむ")
        let extensionRatio = (clampedLength - baseBarLength) / maxAmplitude  // 0.0 to 1.0
        let normalizedExtension = max(extensionRatio, 0.0)  // Ensure non-negative
        let glowMultiplier = 1.0 + normalizedExtension * 0.5  // 1.0x to 1.5x glow

        return (length: clampedLength, glowMultiplier: glowMultiplier)
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
