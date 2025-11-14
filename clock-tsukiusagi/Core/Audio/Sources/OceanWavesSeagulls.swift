//
//  OceanWavesSeagulls.swift
//  clock-tsukiusagi
//
//  Synthesized ocean noise plus randomized seagull chirps.
//

import AVFoundation
import Foundation

public final class OceanWavesSeagulls: AudioSource {
    public var sourceNode: AVAudioNode { outputMixer }

    private let outputMixer = AVAudioMixerNode()
    private let birdMixer = AVAudioMixerNode()
    private let seagullPlayer = AVAudioPlayerNode()
    private let varispeed = AVAudioUnitVarispeed()
    private let waveSource: OceanWaves

    private let schedulingQueue = DispatchQueue(label: "com.clocktsukiusagi.audio.oceanWavesSeagulls")
    private var timer: DispatchSourceTimer?
    private var audioFile: AVAudioFile?
    private weak var engine: AVAudioEngine?

    private var isSuspended = false
    private var activeChirps = 0

    private let birdAmplitude: Double
    private let intervalRange: ClosedRange<Double>
    private let durationRange: ClosedRange<Double>
    private let frequencyRange: ClosedRange<Double>
    private let maxConcurrentChirps: Int

    public init(
        noiseAmplitude: Float,
        lfoFrequency: Double,
        lfoMinimum: Double,
        lfoMaximum: Double,
        birdAmplitude: Double,
        birdMinInterval: Double,
        birdMaxInterval: Double,
        birdMinDuration: Double,
        birdMaxDuration: Double,
        birdFrequencyRange: ClosedRange<Double>,
        maxConcurrentChirps: Int
    ) {
        waveSource = OceanWaves(
            noiseAmplitude: noiseAmplitude,
            lfoFrequency: lfoFrequency,
            lfoDepth: lfoMaximum - lfoMinimum,
            lfoMinimum: lfoMinimum,
            lfoMaximum: lfoMaximum
        )

        self.birdAmplitude = birdAmplitude
        self.intervalRange = birdMinInterval...birdMaxInterval
        self.durationRange = birdMinDuration...birdMaxDuration
        self.frequencyRange = birdFrequencyRange
        self.maxConcurrentChirps = max(1, maxConcurrentChirps)

        birdMixer.outputVolume = Float(Self.clamp(birdAmplitude, lower: 0.0, upper: 1.0))
    }

    // MARK: - AudioSource

    public func start() throws {
        try loadAudioFileIfNeeded()
        try waveSource.start()
        seagullPlayer.play()
        isSuspended = false
        scheduleTimer()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
        activeChirps = 0
        isSuspended = false
        waveSource.stop()
        seagullPlayer.stop()
    }

    public func suspend() {
        isSuspended = true
        timer?.cancel()
        timer = nil
        waveSource.suspend()
        seagullPlayer.pause()
    }

    public func resume() {
        guard isSuspended else { return }
        isSuspended = false
        waveSource.resume()
        seagullPlayer.play()
        scheduleTimer()
    }

    public func setVolume(_ volume: Float) {
        outputMixer.outputVolume = volume
    }

    public func attachAndConnect(to engine: AVAudioEngine, format: AVAudioFormat) throws {
        self.engine = engine

        engine.attach(outputMixer)
        engine.attach(birdMixer)
        engine.attach(seagullPlayer)
        engine.attach(varispeed)

        try waveSource.attachAndConnect(to: engine, format: format)
        engine.disconnectNodeOutput(waveSource.sourceNode)
        engine.connect(waveSource.sourceNode, to: outputMixer, format: format)

        engine.connect(seagullPlayer, to: varispeed, format: format)
        engine.connect(varispeed, to: birdMixer, format: format)
        engine.connect(birdMixer, to: outputMixer, format: format)
    }

    // MARK: - Scheduling

    private func scheduleTimer() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: schedulingQueue)
        timer.schedule(deadline: .now() + randomInterval())
        timer.setEventHandler { [weak self] in
            self?.handleTimerFired()
        }
        self.timer = timer
        timer.resume()
    }

    private func handleTimerFired() {
        timer?.cancel()
        timer = nil

        guard !isSuspended else { return }
        triggerChirp()
        scheduleTimer()
    }

    private func triggerChirp() {
        guard activeChirps < maxConcurrentChirps else { return }
        guard let file = audioFile else { return }

        activeChirps += 1

        let duration = Double.random(in: durationRange)
        let sampleRate = file.processingFormat.sampleRate
        let desiredFrames = AVAudioFrameCount(max(1, duration * sampleRate))
        let availableFrames = AVAudioFrameCount(file.length)
        let frameCount = min(desiredFrames, availableFrames)
        let maxStart = availableFrames > frameCount ? availableFrames - frameCount : 0
        let startFrame = AVAudioFramePosition(maxStart == 0 ? 0 : Int.random(in: 0...Int(maxStart)))

        let baseFrequency = (frequencyRange.lowerBound + frequencyRange.upperBound) / 2.0
        let targetFrequency = Double.random(in: frequencyRange)
        let rate = Float(Self.clamp(targetFrequency / baseFrequency, lower: 0.5, upper: 2.0))
        varispeed.rate = rate

        seagullPlayer.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil
        ) { [weak self] in
            self?.schedulingQueue.async {
                guard let self else { return }
                self.activeChirps = max(0, self.activeChirps - 1)
            }
        }
    }

    // MARK: - Helpers

    private func loadAudioFileIfNeeded() throws {
        guard audioFile == nil else { return }

        guard let url = resolveAudioFileURL() else {
            throw NSError(domain: "OceanWavesSeagulls", code: 1, userInfo: [NSLocalizedDescriptionKey: "seagull_group.caf not found in bundle"])
        }

        audioFile = try AVAudioFile(forReading: url)
    }

    private func resolveAudioFileURL() -> URL? {
        let bundles: [Bundle] = [
            .main,
            Bundle(for: BundleToken.self)
        ]

        for bundle in bundles {
            if let url = bundle.url(forResource: "seagull_group", withExtension: "caf") {
                return url
            }
            if let url = bundle.url(forResource: "seagull_group", withExtension: "wav") {
                return url
            }
        }

        return nil
    }

    private func randomInterval() -> TimeInterval {
        Double.random(in: intervalRange)
    }

    private static func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
        max(lower, min(value, upper))
    }

    private final class BundleToken {}
}
