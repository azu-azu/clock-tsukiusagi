//
//  SafeVolumeLimiter.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-10.
//  安全音量リミッター（AVAudioUnitDynamicsProcessor使用）
//

import AVFoundation
import Foundation

/// 安全音量制限プロトコル
public protocol SafeVolumeLimiting {
    var maxOutputDb: Float { get set }
    func configure(engine: AVAudioEngine, format: AVAudioFormat)
    func updateLimit(_ db: Float)
}

/// 安全音量リミッター
/// AVAudioUnitDynamicsProcessorを使用して出力音量を制限
public final class SafeVolumeLimiter: SafeVolumeLimiting {
    // MARK: - Properties

    private let dynamicsProcessor = AVAudioUnitDynamicsProcessor()
    public var maxOutputDb: Float {
        didSet {
            print("🔊 [SafeVolumeLimiter] Max output updated to \(maxOutputDb) dB")
            dynamicsProcessor.threshold = maxOutputDb
        }
    }

    private var isConfigured = false

    // MARK: - Initialization

    public init(maxOutputDb: Float = -6.0) {
        self.maxOutputDb = maxOutputDb
    }

    // MARK: - Public Methods

    public func configure(engine: AVAudioEngine, format: AVAudioFormat) {
        guard !isConfigured else {
            print("🔊 [SafeVolumeLimiter] Already configured, skipping")
            return
        }

        print("🔊 [SafeVolumeLimiter] Configuring dynamics processor")
        print("   Max output: \(maxOutputDb) dB")
        print("   Format: \(format.sampleRate) Hz, \(format.channelCount) channels")

        // ダイナミクスプロセッサーをアタッチ
        engine.attach(dynamicsProcessor)

        // 接続: MainMixerNode → DynamicsProcessor → OutputNode
        engine.connect(
            engine.mainMixerNode,
            to: dynamicsProcessor,
            format: format
        )
        engine.connect(
            dynamicsProcessor,
            to: engine.outputNode,
            format: format
        )

        // ソフトリミッターとして設定
        configureDynamicsProcessor()

        isConfigured = true
        print("🔊 [SafeVolumeLimiter] Configuration complete")
    }

    public func updateLimit(_ db: Float) {
        maxOutputDb = db
    }

    // MARK: - Private Methods

    private func configureDynamicsProcessor() {
        // リミッター設定（Azu設計）
        dynamicsProcessor.threshold = maxOutputDb          // -6dB ceiling
        dynamicsProcessor.headRoom = 0.1                   // 0.1dB headroom
        dynamicsProcessor.attackTime = 0.001               // 1ms attack (fast)
        dynamicsProcessor.releaseTime = 0.05               // 50ms release
        dynamicsProcessor.overallGain = 0                  // No makeup gain
        dynamicsProcessor.compressionAmount = 20.0         // Heavy limiting
        dynamicsProcessor.inputAmplitude = 0               // Input metering
        dynamicsProcessor.outputAmplitude = 0              // Output metering

        print("   Threshold: \(maxOutputDb) dB")
        print("   Attack: 1ms, Release: 50ms")
        print("   Compression: 20:1 (heavy limiting)")
    }
}
