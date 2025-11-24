//
//  AutoTriggerBoomHit.swift
//  clock-tsukiusagi
//
//  Auto-triggering wrapper for BoomHit (test purposes)
//  Automatically calls trigger() at random intervals
//

import AVFoundation
import Foundation

/// AutoTriggerBoomHit - Wrapper that auto-triggers BoomHit for testing
///
/// This wrapper automatically calls trigger() on a BoomHit instance
/// at random intervals, making it easy to test the boom sound without
/// manual interaction.
public final class AutoTriggerBoomHit: AudioSource {

    private let boomHit: BoomHit
    private var lastTriggerTime: Double = -10.0
    private var time: Double = 0.0
    private let triggerRate: Double
    private let minInterval: Double

    public var sourceNode: AVAudioNode {
        boomHit.sourceNode
    }

    /// Initialize auto-triggering BoomHit wrapper
    /// - Parameters:
    ///   - triggerRate: Average triggers per second (e.g., 0.33 = every ~3 seconds)
    ///   - minInterval: Minimum time between triggers (seconds)
    ///   - duration: Duration of each boom hit
    ///   - fundamental: Base frequency of the boom
    ///   - pitchDropAmount: Pitch drop amount
    public init(
        triggerRate: Double = 0.33,     // ~3秒に1回
        minInterval: Double = 3.0,      // 最低3秒間隔
        duration: Double = 3.0,
        fundamental: Double = 55.0,
        pitchDropAmount: Double = 0.15
    ) {
        self.triggerRate = triggerRate
        self.minInterval = minInterval
        self.boomHit = BoomHit(
            duration: duration,
            fundamental: fundamental,
            pitchDropAmount: pitchDropAmount
        )

        // Start auto-trigger timer
        startAutoTrigger()
    }

    private func startAutoTrigger() {
        // Run timer on main queue to call trigger() periodically
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.time += 0.1

            // Random trigger check
            let shouldTrigger = Double.random(in: 0...1) < (self.triggerRate * 0.1)

            if shouldTrigger && (self.time - self.lastTriggerTime) >= self.minInterval {
                print("💥 AutoTrigger: Boom at t=\(self.time)")
                self.boomHit.trigger()
                self.lastTriggerTime = self.time
            }
        }
    }

    public func suspend() {
        boomHit.suspend()
    }

    public func resume() {
        boomHit.resume()
    }

    public func start() throws {
        try boomHit.start()
    }

    public func stop() {
        boomHit.stop()
    }

    public func setVolume(_ volume: Float) {
        boomHit.setVolume(volume)
    }
}
