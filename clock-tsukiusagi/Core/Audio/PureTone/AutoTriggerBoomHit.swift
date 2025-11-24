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
    private var timer: Timer?  // Timer保持してstopで停止できるように

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
        fundamental: Double = 110.0,    // 55Hz → 110Hz（再生可能な周波数）
        pitchDropAmount: Double = 0.25  // BoomHitのデフォルトに合わせる
    ) {
        self.triggerRate = triggerRate
        self.minInterval = minInterval
        self.boomHit = BoomHit(
            duration: duration,
            fundamental: fundamental,
            pitchDropAmount: pitchDropAmount  // デフォルト 0.25 を使用
        )

        // Start auto-trigger timer
        startAutoTrigger()
    }

    private func startAutoTrigger() {
        // Run timer on main queue to call trigger() periodically
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
        timer?.invalidate()
        boomHit.suspend()
    }

    public func resume() {
        if timer == nil {
            startAutoTrigger()
        }
        boomHit.resume()
    }

    public func start() throws {
        try boomHit.start()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        time = 0.0
        lastTriggerTime = -10.0
        boomHit.stop()
    }

    public func setVolume(_ volume: Float) {
        boomHit.setVolume(volume)
    }
}
