//
//  SafeVolumeLimiter.swift
//  clock-tsukiusagi
//
//  Created by Claude Code on 2025-11-10.
//  安全音量リミッター（iOS: AVAudioUnitDistortion使用）
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
/// iOS用実装: AVAudioUnitDistortion + ソフトクリッピングを使用
/// Note: AVAudioUnitDynamicsProcessorはmacOSのみで利用可能なため、
/// iOS用の代替として歪みエフェクトを使用してソフトリミットを実装
public final class SafeVolumeLimiter: SafeVolumeLimiting {
    // MARK: - Properties

    private let limiterNode = AVAudioUnitDistortion()
    public var maxOutputDb: Float {
        didSet {
            print("🔊 [SafeVolumeLimiter] Max output updated to \(maxOutputDb) dB")
            updateLimiterSettings()
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

        print("🔊 [SafeVolumeLimiter] Configuring soft limiter (iOS)")
        print("   Max output: \(maxOutputDb) dB")
        print("   Format: \(format.sampleRate) Hz, \(format.channelCount) channels")

        // リミッターノードをアタッチ
        engine.attach(limiterNode)

        // 接続: MainMixerNode → Limiter → OutputNode
        engine.connect(
            engine.mainMixerNode,
            to: limiterNode,
            format: format
        )
        engine.connect(
            limiterNode,
            to: engine.outputNode,
            format: format
        )

        // ソフトリミッターとして設定
        updateLimiterSettings()

        isConfigured = true
        print("🔊 [SafeVolumeLimiter] Configuration complete")
    }

    public func updateLimit(_ db: Float) {
        maxOutputDb = db
    }

    // MARK: - Private Methods

    private func updateLimiterSettings() {
        // iOS用ソフトクリッピング設定
        // AVAudioUnitDistortionを使用してソフトリミットを実現
        // 負のプリゲイン + ソフトクリッピングでダイナミクスプロセッサーに近い効果を得る

        limiterNode.loadFactoryPreset(.multiDecimated4)  // ソフトなプリセットを使用

        // プリゲイン: maxOutputDbに基づいて調整（-6dB → 約-6dB gain）
        limiterNode.preGain = maxOutputDb

        // ウェットドライミックス: 100%ウェット（完全に処理を適用）
        limiterNode.wetDryMix = 100

        print("   Pre-gain: \(maxOutputDb) dB")
        print("   Preset: MultiDecimated4 (soft clipping)")
        print("   Wet/Dry: 100% (full processing)")
    }
}
