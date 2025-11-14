//
//  OceanWavesWithSeagull.swift
//  clock-tsukiusagi
//
//  Combines OceanWaves (procedural) + Seagull CAF playback
//

import AVFoundation
import Foundation

final class OceanWavesWithSeagull {
    private let engine = AVAudioEngine()
    private let waves = OceanWaves() // ← 既存の波音ノード
    private let seagullPlayer = AVAudioPlayerNode()
    private var timer: DispatchSourceTimer?

    private let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!

    init() {
        setup()
    }

    private func setup() {
        engine.attach(waves.sourceNode)
        engine.attach(seagullPlayer)

        engine.connect(waves.sourceNode, to: engine.mainMixerNode, format: format)
        engine.connect(seagullPlayer, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            print("🌊 Ocean + Seagull ambient engine started")
        } catch {
            print("⚠️ Engine failed:", error)
        }
    }

    func start() {
        scheduleSeagulls()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        engine.stop()
    }

    private func scheduleSeagulls() {
        guard let url = Bundle.main.url(forResource: "seagull", withExtension: "caf") else {
            print("⚠️ seagull.caf not found")
            return
        }

        guard let file = try? AVAudioFile(forReading: url) else {
            print("⚠️ Could not load seagull.caf")
            return
        }

        seagullPlayer.play()

        timer = DispatchSource.makeTimerSource()
        timer?.schedule(deadline: .now(), repeating: .seconds(1))
        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            if Double.random(in: 0...1) < 0.04 { // roughly once every 20–25s
                self.seagullPlayer.scheduleFile(file, at: nil)
                print("🐦 seagull chirp triggered")
            }
        }
        timer?.resume()
    }
}
